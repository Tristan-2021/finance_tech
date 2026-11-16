import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app.dart';
import 'app_links.dart';
import 'shell/feedback_service.dart';
import 'shell/startup_views.dart';
import 'shell/toast.dart';

/// 문자·전화 앱이 공통으로 쓰는 상태·생명주기·딥링크 컨텍스트.
abstract interface class CompanionScope {
  FamilyCubit get family;
  ShellCubit get shell;
  bool get isForeground;
}

/// 문자·전화 앱 공용 헤더. 핑거벨 앱의 상단 막대와 같은 여백·색 토큰을 씁니다.
class CompanionHeader extends StatelessWidget {
  final String title;
  final String? roleLabel;

  const CompanionHeader({super.key, required this.title, this.roleLabel});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Container(
      color: c.glass,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 8),
      child: Row(
        children: [
          Expanded(child: Brand(label: title)),
          if (roleLabel != null && roleLabel!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: c.cardBorder ?? c.line),
              ),
              child: Text(
                roleLabel!,
                style: FbText.note(c).copyWith(color: c.ink2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 서버와 실시간 연결이 잠시 끊겼을 때 본문 위에 띄우는 배너.
class CompanionOfflineBanner extends StatelessWidget {
  const CompanionOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final reachable = context.select((FamilyCubit f) => f.state.reachable);
    if (reachable) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: FbBanner(
        title: '서버와 연결이 끊겼어요',
        sub: '다시 연결하는 중이에요 · 마지막으로 받은 상태를 보여 주고 있어요',
        titleColor: c.redStrong,
        leading: Icon(FbIcons.cloudOff, size: 18, color: c.redStrong),
        actionLabel: '다시 시도',
        onAction: context.read<FamilyCubit>().refresh,
      ),
    );
  }
}

/// 문자·전화 앱 공용 셸.
/// 서버 상태(`FamilyCubit`), 공유 역할·설정(`ProviderPrefsStore`), 피드백 출력(`FeedbackOutput`),
/// 시작/resume 동기화와 딥링크(`AppLinks`)를 한곳에서 다룹니다.
class CompanionApp extends StatefulWidget {
  final String title;
  final String host;
  final FamilyCubit? family;
  final ShellCubit? shell;
  final LocalPrefsStore? store;
  final FeedbackOutput? feedback;
  final String? serverAddress;
  final GlobalKey<NavigatorState>? navigatorKey;
  final Uri? initialLink;
  final Widget Function(BuildContext context, CompanionScope scope) builder;
  final FutureOr<void> Function(Uri uri, CompanionScope scope)? onLink;
  final FutureOr<void> Function(FamilyEvent event, CompanionScope scope)? onEvent;
  final FutureOr<void> Function(CompanionScope scope)? onStateSynced;

  const CompanionApp({
    super.key,
    required this.title,
    required this.host,
    required this.builder,
    this.family,
    this.shell,
    this.store,
    this.feedback,
    this.serverAddress,
    this.navigatorKey,
    this.initialLink,
    this.onLink,
    this.onEvent,
    this.onStateSynced,
  });

  @override
  State<CompanionApp> createState() => _CompanionAppState();
}

class _CompanionAppState extends State<CompanionApp>
    with WidgetsBindingObserver
    implements CompanionScope {
  late final FamilyCubit _family =
      widget.family ?? FamilyCubit(ApiFamilyRepository(FingerBellApi(ApiConfig.fromEnvironment())));
  late final bool _ownsFamily = widget.family == null;
  late final ShellCubit _shell =
      widget.shell ?? ShellCubit(const ShellState(), widget.store ?? ProviderPrefsStore());
  late final bool _ownsShell = widget.shell == null;
  late final FeedbackOutput _feedback = widget.feedback ?? const SilentFeedback();
  late final String _serverAddress =
      widget.serverAddress ?? ApiConfig.fromEnvironment().toString();

  final _toast = GlobalKey<ToastHostState>();
  AppLifecycleState? _lifecycleState;
  StreamSubscription<FeedbackRequest>? _feedbackSub;
  StreamSubscription<FamilyEvent>? _eventSub;

  Uri? _pendingLink;
  bool _initialReady = false;
  Future<void>? _syncing;
  bool _syncAgain = false;
  bool _syncRefresh = false;

  @override
  FamilyCubit get family => _family;

  @override
  ShellCubit get shell => _shell;

  @override
  bool get isForeground => (_lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    _feedbackSub = _shell.feedback.listen(_onFeedback);
    _eventSub = _family.events.listen(_onFamilyEvent);
    AppLinks.channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') {
        _receiveLink(Uri.tryParse(call.arguments as String? ?? ''));
      }
    });
    if (_ownsFamily) {
      unawaited(_family.start());
    }
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    if (widget.shell == null) {
      await _shell.loadPrefs();
    }
    if (!mounted) return;
    _initialReady = true;
    final direct = widget.initialLink;
    if (direct != null) {
      if (direct.scheme == 'fingerbell' && direct.host == widget.host) {
        _pendingLink = direct;
      }
      _scheduleFlush();
      return;
    }
    _scheduleFlush();
    final initial = await AppLinks.initialLink();
    if (!mounted || initial == null) return;
    if (initial.scheme == 'fingerbell' && initial.host == widget.host) {
      _pendingLink ??= initial;
      _scheduleFlush();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      unawaited(_sync(refreshServer: true));
    }
  }

  void _receiveLink(Uri? uri) {
    if (!mounted || uri?.scheme != 'fingerbell' || uri?.host != widget.host) {
      return;
    }
    _pendingLink = uri;
    if (!_initialReady) return;
    unawaited(_sync(refreshServer: _family.state.snapshot != null));
  }

  Future<void> _sync({required bool refreshServer}) {
    _syncRefresh = _syncRefresh || refreshServer;
    if (_syncing != null) {
      _syncAgain = true;
      return _syncing!;
    }
    return _syncing = _runSync().whenComplete(() => _syncing = null);
  }

  Future<void> _runSync() async {
    do {
      _syncAgain = false;
      final shouldRefresh = _syncRefresh;
      _syncRefresh = false;
      await _shell.loadPrefs();
      if (shouldRefresh && _family.state.status != FamilyStatus.loading && !_family.isClosed) {
        await _family.refresh();
      }
    } while (_syncAgain && mounted);
    if (mounted) _scheduleFlush();
  }

  void _scheduleFlush() {
    if (!mounted || !_initialReady || !_family.state.isReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_initialReady || !_family.state.isReady) return;
      final link = _pendingLink;
      _pendingLink = null;
      if (link != null) {
        unawaited(Future.sync(() => widget.onLink?.call(link, this)));
      }
      unawaited(Future.sync(() => widget.onStateSynced?.call(this)));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _onFamilyEvent(FamilyEvent event) {
    if (!mounted) return;
    unawaited(Future.sync(() => widget.onEvent?.call(event, this)));
  }

  void _onFeedback(FeedbackRequest f) {
    if (!mounted || !isForeground) return;
    final prefs = _shell.state.prefs;
    if (f.toast) _toast.currentState?.show(f.message);
    if (prefs.sound && f.alertSound) _feedback.playAlertTone();
    if (f.vibrate.isNotEmpty && prefs.haptics) {
      _feedback.vibrate(f.vibrate, playSound: false, playHaptics: true);
    }
    if (prefs.voice && f.speak) _feedback.speak(f.message);
  }

  @override
  void dispose() {
    _feedbackSub?.cancel();
    _eventSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppLinks.channel.setMethodCallHandler(null);
    if (_ownsShell) unawaited(_shell.close());
    if (_ownsFamily) unawaited(_family.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _family),
        BlocProvider.value(value: _shell),
      ],
      child: RepositoryProvider<FeedbackOutput>.value(
        value: _feedback,
        child: BlocListener<FamilyCubit, FamilyState>(
          listenWhen: (a, b) =>
              a.status != b.status ||
              (a.snapshot == null) != (b.snapshot == null) ||
              a.snapshot?.activeCall?.id != b.snapshot?.activeCall?.id ||
              a.snapshot?.activeCall?.status != b.snapshot?.activeCall?.status,
          listener: (_, state) {
            if (state.isReady) _scheduleFlush();
          },
          child: BlocBuilder<ShellCubit, ShellState>(
            bloc: _shell,
            buildWhen: (a, b) => a.prefs != b.prefs || a.persona != b.persona,
            builder: (context, s) => MaterialApp(
              title: widget.title,
              debugShowCheckedModeBanner: false,
              navigatorKey: widget.navigatorKey,
              theme: FbTheme.build(highContrast: s.prefs.highContrast),
              locale: const Locale('ko', 'KR'),
              supportedLocales: const [Locale('ko', 'KR')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) => FingerBellApp.applyTextScale(
                context,
                s,
                Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    children: [
                      ?child,
                      Positioned.fill(child: ToastHost(key: _toast, top: 64)),
                    ],
                  ),
                ),
              ),
              home: BlocBuilder<FamilyCubit, FamilyState>(
                buildWhen: (a, b) =>
                    a.status != b.status || (a.snapshot == null) != (b.snapshot == null),
                builder: (context, state) {
                  if (state.snapshot == null) {
                    return state.status == FamilyStatus.error
                        ? ConnectionErrorView(
                            message: state.failure?.message ?? '',
                            serverAddress: _serverAddress,
                            onRetry: _family.load,
                          )
                        : const LoadingView();
                  }
                  return widget.builder(context, this);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
