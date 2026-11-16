import 'dart:async';

import 'package:core_family/core_family.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_prefs.dart';
import 'prefs_store.dart';

/// 화면 탭. [alerts](가족 알림)는 보호자에게만 있습니다.
enum AppTab {
  home,
  history,
  alerts,
  safety,
  settings;

  /// 이 사용자에게 없는 탭이면 가장 가까운 탭으로 바꿉니다 (가족 알림 → 내역).
  AppTab availableFor(Persona p) => this == alerts && p != Persona.guardian ? history : this;
}

/// 토스트·진동·음성 안내 요청. 실제 출력은 앱 셸이 설정(AppPrefs)에 맞춰 합니다.
class FeedbackRequest {
  final String message;
  final bool toast;

  /// 진동 패턴 (ms, 진동/쉼 반복). 비어 있으면 진동하지 않습니다.
  final List<int> vibrate;
  final bool speak;
  final bool alertSound;

  const FeedbackRequest(
    this.message, {
    this.toast = true,
    this.vibrate = const [40],
    this.speak = true,
    this.alertSound = false,
  });
}

class ShellState {
  final Persona persona;
  final AppTab tab;
  final String txFilter; // all / in / out
  final String alertFilter; // all / pending
  final AppPrefs prefs;

  /// SOS 동결 완료 화면을 띄운 사용자.
  final String? sosMemberId;

  /// 늘어날 때마다 화면 흔들림 애니메이션을 한 번 재생합니다 (시연용).
  final int shakeTick;

  /// 늘어날 때마다 열려 있는 시트를 닫습니다.
  final int closeSheetsTick;

  const ShellState({
    this.persona = Persona.senior,
    this.tab = AppTab.home,
    this.txFilter = 'all',
    this.alertFilter = 'all',
    this.prefs = const AppPrefs(),
    this.sosMemberId,
    this.shakeTick = 0,
    this.closeSheetsTick = 0,
  });

  bool get isGuardian => persona == Persona.guardian;
  String? get memberId => persona.memberId;

  ShellState copyWith({
    Persona? persona,
    AppTab? tab,
    String? txFilter,
    String? alertFilter,
    AppPrefs? prefs,
    String? sosMemberId,
    bool clearSos = false,
    int? shakeTick,
    int? closeSheetsTick,
  }) => ShellState(
    persona: persona ?? this.persona,
    tab: tab ?? this.tab,
    txFilter: txFilter ?? this.txFilter,
    alertFilter: alertFilter ?? this.alertFilter,
    prefs: prefs ?? this.prefs,
    sosMemberId: clearSos ? null : (sosMemberId ?? this.sosMemberId),
    shakeTick: shakeTick ?? this.shakeTick,
    closeSheetsTick: closeSheetsTick ?? this.closeSheetsTick,
  );
}

const personaPrefKey = 'persona';

/// 통화 중 위험 경고 진동 패턴 (총 0.5초, 3초 미만으로 한 번만 울립니다: 기획서 5.3, 7.3).
const List<int> callWarningVibration = [200, 100, 200];

class ShellCubit extends Cubit<ShellState> {
  final _feedback = StreamController<FeedbackRequest>.broadcast();
  final Set<String> _announcedCallWarnings = <String>{};
  final LocalPrefsStore _store;

  ShellCubit([super.initial = const ShellState(), LocalPrefsStore? store])
    : _store = store ?? MemoryPrefsStore();

  Stream<FeedbackRequest> get feedback => _feedback.stream;

  /// 기기에 저장된 화면 설정(쉬운 화면, 큰 글씨, 고대비 등)과 역할을 불러옵니다.
  Future<void> loadPrefs() async {
    Map<String, Object?> saved;
    try {
      saved = await _store.load();
    } catch (_) {
      saved = const {};
    }
    if (isClosed) return;
    final nextPrefs = AppPrefs.fromMap(saved);
    final nextPersona = Persona.parse(saved[personaPrefKey]);
    if (nextPersona == state.persona && nextPrefs == state.prefs) return;
    emit(
      state.copyWith(
        persona: nextPersona,
        tab: state.tab.availableFor(nextPersona),
        prefs: nextPrefs,
      ),
    );
  }

  void switchTab(AppTab tab) => emit(state.copyWith(tab: tab));

  /// 사용자를 바꿉니다 (시연용 역할 전환). 열린 시트와 SOS 화면은 닫습니다.
  void goto(Persona persona, [AppTab? tab]) {
    emit(
      ShellState(
        persona: persona,
        tab: (tab ?? state.tab).availableFor(persona),
        prefs: state.prefs,
        shakeTick: state.shakeTick,
        closeSheetsTick: state.closeSheetsTick + 1,
      ),
    );
    unawaited(_store.saveString(personaPrefKey, persona.name));
  }

  void setTxFilter(String filter) => emit(state.copyWith(txFilter: filter));
  void setAlertFilter(String filter) => emit(state.copyWith(alertFilter: filter));

  void setPref(PrefKey key, bool value) {
    emit(state.copyWith(prefs: state.prefs.set(key, value)));
    unawaited(_store.saveBool(key.name, value));
  }

  void togglePref(PrefKey key) => setPref(key, !state.prefs[key]);

  /// 쉬운 화면을 켜거나 끕니다. 토글할 때 첫 실행 질문도 완료한 것으로 기록합니다.
  void setEasyMode(bool value) {
    final next = state.prefs.set(PrefKey.easyMode, value).set(PrefKey.easyModePrompted, true);
    emit(state.copyWith(prefs: next));
    unawaited(_store.saveBool(PrefKey.easyMode.name, value));
    unawaited(_store.saveBool(PrefKey.easyModePrompted.name, true));
  }

  /// 어르신 첫 실행 질문("쉬운 화면으로 볼까요?")에 대한 선택을 저장합니다.
  void answerEasyModePrompt(bool enableEasyMode) => setEasyMode(enableEasyMode);

  void showSos(String memberId) => emit(state.copyWith(sosMemberId: memberId, closeSheetsTick: state.closeSheetsTick + 1));
  void closeSos() => emit(state.copyWith(clearSos: true));

  void closeSheets() => emit(state.copyWith(closeSheetsTick: state.closeSheetsTick + 1));

  void playShake() => emit(state.copyWith(shakeTick: state.shakeTick + 1));

  void say(
    String message, {
    bool toast = true,
    List<int> vibrate = const [40],
    bool speak = true,
    bool alertSound = false,
  }) {
    if (!_feedback.isClosed) {
      _feedback.add(
        FeedbackRequest(
          message,
          toast: toast,
          vibrate: vibrate,
          speak: speak,
          alertSound: alertSound,
        ),
      );
    }
  }

  /// 통화 중 위험 경고 피드백(진동·경고음·음성 안내)을 통화 ID별로 앱 전체에서 한 번만 실행합니다 (기획서 5.3).
  bool announceCallWarningOnce(
    String callId,
    String message, {
    bool toast = false,
    List<int> vibrate = callWarningVibration,
    bool speak = true,
    bool alertSound = true,
  }) {
    final key = callId.trim().isEmpty ? '_active_' : callId.trim();
    if (!_announcedCallWarnings.add(key)) return false;
    say(message, toast: toast, vibrate: vibrate, speak: speak, alertSound: alertSound);
    return true;
  }

  /// 처음 상태(어르신 홈, 기본 설정)로 돌아갑니다.
  void reset() {
    _announcedCallWarnings.clear();
    unawaited(_store.clear());
    emit(ShellState(shakeTick: state.shakeTick, closeSheetsTick: state.closeSheetsTick + 1));
  }

  @override
  Future<void> close() async {
    await _feedback.close();
    return super.close();
  }
}
