import 'dart:ui';

import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'sms_bubble.dart';
import 'sms_format.dart';

/// 휴대폰 문자 화면 시트를 엽니다 (기획서 5.2).
/// [initialSenderPhone]을 주면 해당 발신 번호의 대화를 바로 보여 줍니다.
Future<void> openSmsSheet(
  BuildContext context,
  String memberId, {
  String? initialSenderPhone,
  ValueChanged<String>? onTapPhone,
  VoidCallback? onCallGuardian,
}) => showFbSheet<void>(
  context,
  builder: (_) => SmsSheet(
    memberId: memberId,
    initialSenderPhone: initialSenderPhone,
    onTapPhone: onTapPhone,
    onCallGuardian: onCallGuardian,
  ),
);

/// iOS 메시지 앱 모양의 대화 목록 · 대화 화면 · 링크 차단 안내 화면.
class SmsSheet extends StatefulWidget {
  final String memberId;
  final String? initialSenderPhone;
  final int selectionTick;
  final bool asScreen;
  final ValueChanged<String>? onTapPhone;
  final VoidCallback? onCallGuardian;

  const SmsSheet({
    super.key,
    required this.memberId,
    this.initialSenderPhone,
    this.selectionTick = 0,
    this.asScreen = false,
    this.onTapPhone,
    this.onCallGuardian,
  });

  @override
  State<SmsSheet> createState() => _SmsSheetState();
}

class _SmsSheetState extends State<SmsSheet> {
  String? _selectedPhone;
  ({SmsMessage message, String url})? _blocked;

  @override
  void initState() {
    super.initState();
    _selectedPhone = widget.initialSenderPhone;
  }

  @override
  void didUpdateWidget(SmsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.memberId != oldWidget.memberId ||
        widget.initialSenderPhone != oldWidget.initialSenderPhone ||
        widget.selectionTick != oldWidget.selectionTick) {
      _selectedPhone = widget.initialSenderPhone;
      _blocked = null;
    }
  }

  void _openConversation(String senderPhone) {
    setState(() {
      _selectedPhone = senderPhone;
      _blocked = null;
    });
  }

  void _closeConversation() {
    setState(() {
      _selectedPhone = null;
      _blocked = null;
    });
  }

  void _openBlockedLink(SmsMessage message, String url) {
    setState(() => _blocked = (message: message, url: url));
    try {
      context.read<ShellCubit>().say(
        '이 링크를 열지 않았어요. ${message.explanation}',
        toast: false,
        vibrate: const [],
        speak: true,
      );
    } catch (_) {}
  }

  void _closeBlockedLink() {
    setState(() => _blocked = null);
  }

  @override
  Widget build(BuildContext context) {
    final highContrast = context.fb.cardBorder != null;
    final palette = SmsPalette.of(highContrast: highContrast);

    return BlocBuilder<FamilyCubit, FamilyState>(
      builder: (context, state) {
        if (!state.isReady) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }
        final member = state.data.memberOrNull(widget.memberId);
        if (member == null) {
          return Center(
            child: Text(
              '메시지 없음',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: palette.ink2),
            ),
          );
        }

        final now = context.read<FamilyCubit>().now();
        final conversations = sortSmsConversationsNewestFirst(member.smsConversations);
        final active = _selectedPhone == null
            ? null
            : conversations.where((c) => c.senderPhone == _selectedPhone).firstOrNull;
        final blocked = _blocked;
        final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

        final Widget child;
        if (blocked != null) {
          child = KeyedSubtree(
            key: ValueKey('blocked-${blocked.url}'),
            child: BlockedLinkView(
              url: blocked.url,
              message: blocked.message,
              onBack: _closeBlockedLink,
              onCallGuardian: widget.onCallGuardian,
              showClose: !widget.asScreen,
            ),
          );
        } else if (active != null) {
          child = KeyedSubtree(
            key: ValueKey('thread-${active.senderPhone}'),
            child: _ConversationThreadView(
              conversation: active,
              now: now,
              palette: palette,
              onBack: _closeConversation,
              onOpenBlockedLink: _openBlockedLink,
              onTapPhone: widget.onTapPhone,
              onCallGuardian: widget.onCallGuardian,
            ),
          );
        } else {
          child = KeyedSubtree(
            key: const ValueKey('conversation-list'),
            child: _ConversationListView(
              conversations: conversations,
              now: now,
              palette: palette,
              onSelectConversation: (conv) => _openConversation(conv.senderPhone),
            ),
          );
        }

        return PopScope(
          canPop: !widget.asScreen || (blocked == null && active == null),
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (blocked != null) {
              _closeBlockedLink();
            } else if (active != null) {
              _closeConversation();
            }
          },
          child: AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
            child: child,
          ),
        );
      },
    );
  }
}

class _ConversationListView extends StatelessWidget {
  final List<SmsConversation> conversations;
  final DateTime now;
  final SmsPalette palette;
  final ValueChanged<SmsConversation> onSelectConversation;

  const _ConversationListView({
    required this.conversations,
    required this.now,
    required this.palette,
    required this.onSelectConversation,
  });

  @override
  Widget build(BuildContext context) {
    final bottomClearance = MediaQuery.paddingOf(context).bottom + 16;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Semantics(
            header: true,
            child: Text(
              '메시지',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: palette.ink,
              ),
            ),
          ),
        ),
        Divider(height: 1, color: palette.divider),
      ],
    );

    return ColoredBox(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                if (conversations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        '메시지 없음',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: palette.ink2),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < conversations.length; i++) ...[
                    _ConversationRow(
                      key: ValueKey('conv-${conversations[i].senderPhone}'),
                      conversation: conversations[i],
                      now: now,
                      palette: palette,
                      onTap: () => onSelectConversation(conversations[i]),
                    ),
                    if (i + 1 < conversations.length)
                      Divider(height: 1, indent: 78, color: palette.divider),
                  ],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: conversations.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: bottomClearance),
                          child: Text(
                            '메시지 없음',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: palette.ink2,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(bottom: bottomClearance),
                        itemCount: conversations.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, indent: 78, color: palette.divider),
                        itemBuilder: (context, index) {
                          final conv = conversations[index];
                          return _ConversationRow(
                            key: ValueKey('conv-${conv.senderPhone}'),
                            conversation: conv,
                            now: now,
                            palette: palette,
                            onTap: () => onSelectConversation(conv),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final SmsConversation conversation;
  final DateTime now;
  final SmsPalette palette;
  final VoidCallback onTap;

  const _ConversationRow({
    super.key,
    required this.conversation,
    required this.now,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDanger = conversation.hasDanger;
    final hasCaution =
        !hasDanger &&
        (conversation.lastMessage.isCaution || conversation.messages.any((m) => m.isCaution));
    final whenText = formatSmsListWhen(conversation.lastMessage.at, now);
    final riskLabel = hasDanger ? ', 위험' : (hasCaution ? ', 주의' : '');

    return Semantics(
      button: true,
      label: '${conversation.displaySender}$riskLabel, $whenText, ${conversation.lastMessage.body}',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: const Color(0x0D000000),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SmsAvatar(name: conversation.senderName, size: 44, palette: palette),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  conversation.displaySender,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: palette.ink,
                                  ),
                                ),
                                if (hasDanger || hasCaution)
                                  _RiskBadge(danger: hasDanger, palette: palette),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    whenText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w400,
                                      color: palette.ink2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                ExcludeSemantics(
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: palette.ink2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        conversation.lastMessage.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          color: palette.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final bool danger;
  final SmsPalette palette;

  const _RiskBadge({required this.danger, required this.palette});

  @override
  Widget build(BuildContext context) {
    final fg = danger ? palette.redText : palette.amber;
    final bg = danger ? palette.redSoft : palette.amberSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: palette.highContrast ? Border.all(color: fg, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 13, color: fg),
          const SizedBox(width: 3),
          Text(
            danger ? '위험' : '주의',
            style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

class _SmsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final SmsPalette palette;

  const _SmsAvatar({required this.name, required this.size, required this.palette});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.avatarBg,
          shape: BoxShape.circle,
          border: palette.highContrast
              ? Border.all(color: const Color(0xFF1B1F24), width: 1.5)
              : null,
        ),
        child: trimmed.isNotEmpty
            ? Text(
                trimmed.characters.first,
                style: TextStyle(
                  fontSize: size * 0.39,
                  fontWeight: FontWeight.w600,
                  color: palette.avatarFg,
                ),
              )
            : Icon(Icons.person_rounded, size: size * 0.55, color: palette.avatarFg),
      ),
    );
  }
}

class _ConversationThreadView extends StatelessWidget {
  final SmsConversation conversation;
  final DateTime now;
  final SmsPalette palette;
  final VoidCallback onBack;
  final void Function(SmsMessage message, String url) onOpenBlockedLink;
  final ValueChanged<String>? onTapPhone;
  final VoidCallback? onCallGuardian;

  const _ConversationThreadView({
    required this.conversation,
    required this.now,
    required this.palette,
    required this.onBack,
    required this.onOpenBlockedLink,
    this.onTapPhone,
    this.onCallGuardian,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = sortSmsMessagesChronological(conversation.messages);
    final messages = sorted.isNotEmpty
        ? sorted
        : (conversation.lastMessage.body.isNotEmpty ? [conversation.lastMessage] : const <SmsMessage>[]);
    final bottomClearance = MediaQuery.paddingOf(context).bottom + 24;

    final topBar = ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: palette.navBg,
            border: Border(
              bottom: BorderSide(
                color: palette.navBorder,
                width: palette.highContrast ? 1.5 : 0.8,
              ),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _NavBackButton(
                    key: const ValueKey('conversation-back-button'),
                    color: palette.blue,
                    onTap: onBack,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SmsAvatar(
                          name: conversation.senderName,
                          size: 40,
                          palette: palette,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          conversation.displaySender,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                        if (conversation.senderName.trim().isNotEmpty &&
                            conversation.senderPhone.trim().isNotEmpty)
                          Text(
                            conversation.senderPhone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: palette.ink2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (onTapPhone != null && conversation.senderPhone.trim().isNotEmpty)
                    Tooltip(
                      message: '전화',
                      child: Semantics(
                        button: true,
                        label: '전화',
                        onTap: () => onTapPhone!(conversation.senderPhone),
                        excludeSemantics: true,
                        child: InkWell(
                          key: const ValueKey('conversation-call-button'),
                          splashFactory: NoSplash.splashFactory,
                          splashColor: Colors.transparent,
                          highlightColor: const Color(0x14000000),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => onTapPhone!(conversation.senderPhone),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 57, minHeight: 57),
                            child: Center(
                              child: Icon(Icons.phone_outlined, size: 24, color: palette.blue),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 57, height: 57),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Widget buildMessageItem(int i) {
      final msg = messages[i];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (shouldShowThreadTimestamp(messages, i))
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 4 : 14, bottom: 10),
              child: Text(
                formatSmsThreadWhen(msg.at, now),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.ink2,
                ),
              ),
            ),
          SmsBubble(
            key: ValueKey('sms-${msg.id}'),
            message: msg,
            now: now,
            onTapLink: (url) => onOpenBlockedLink(msg, url),
            onTapPhone: onTapPhone,
            onCallGuardian: onCallGuardian,
          ),
          if (i + 1 < messages.length) const SizedBox(height: 8),
        ],
      );
    }

    return ColoredBox(
      color: palette.threadBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                topBar,
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < messages.length; i++) buildMessageItem(i),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topBar,
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(18, 12, 18, bottomClearance),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => buildMessageItem(index),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavBackButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _NavBackButton({super.key, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '뒤로',
      child: Semantics(
        button: true,
        label: '뒤로',
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: const Color(0x14000000),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 57, minHeight: 57),
            child: Center(
              child: Icon(Icons.chevron_left_rounded, size: 32, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// 위험 문자의 링크를 눌렀을 때 뜨는 차단 화면 (기획서 5.2, 7.3).
/// 어떤 경우에도 외부 브라우저로 열지 않고 "이 링크를 열지 않았어요"와 이유를 보여 줍니다.
class BlockedLinkView extends StatefulWidget {
  final String url;
  final SmsMessage message;
  final VoidCallback onBack;
  final VoidCallback? onCallGuardian;
  final bool showClose;

  const BlockedLinkView({
    super.key,
    required this.url,
    required this.message,
    required this.onBack,
    this.onCallGuardian,
    this.showClose = true,
  });

  @override
  State<BlockedLinkView> createState() => _BlockedLinkViewState();
}

class _BlockedLinkViewState extends State<BlockedLinkView> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highContrast = context.fb.cardBorder != null;
    final palette = SmsPalette.of(highContrast: highContrast);
    final reasonTitle = widget.message.explanation.isNotEmpty
        ? widget.message.explanation
        : '사기 사이트나 악성 앱 설치로 이어질 수 있는 위험한 링크예요.';
    final reasons = widget.message.reasons.isNotEmpty
        ? widget.message.reasons
        : const ['문자 속 인터넷 주소는 공식 기관 주소가 아닐 수 있어요'];
    final bottomClearance = MediaQuery.paddingOf(context).bottom + 28;

    final topBar = Container(
      decoration: BoxDecoration(
        color: palette.navBg,
        border: Border(
          bottom: BorderSide(
            color: palette.navBorder,
            width: palette.highContrast ? 1.5 : 0.8,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 57),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              _NavBackButton(color: palette.blue, onTap: widget.onBack),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    '링크 차단 안내',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: palette.ink),
                  ),
                ),
              ),
              if (widget.showClose)
                Tooltip(
                  message: '닫기',
                  child: Semantics(
                    button: true,
                    label: '닫기',
                    onTap: () => Navigator.of(context).maybePop(),
                    excludeSemantics: true,
                    child: InkWell(
                      splashFactory: NoSplash.splashFactory,
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 57, minHeight: 57),
                        child: Center(
                          child: Icon(Icons.close_rounded, size: 22, color: palette.ink2),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 57, height: 57),
            ],
          ),
        ),
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          focusNode: _focus,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: palette.red, shape: BoxShape.circle),
                    child: const Icon(Icons.shield_outlined, size: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '이 링크를 열지 않았어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: palette.ink),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 304),
                  child: Text(
                    '위험한 인터넷 주소로 연결되지 않도록 외부로 열지 않고 안전하게 막았어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, height: 1.5, color: palette.ink2),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.divider,
              width: palette.highContrast ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('차단한 주소', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.ink2)),
              const SizedBox(height: 4),
              Text(
                widget.url,
                style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w700, color: palette.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.highContrast ? palette.red : palette.red.withValues(alpha: 0.42),
              width: palette.highContrast ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Semantics(
                    label: '위험 경고',
                    child: Icon(Icons.warning_amber_rounded, size: 19, color: palette.red),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reasonTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                        color: palette.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final reason in reasons)
                BulletText(
                  reason,
                  style: TextStyle(fontSize: 13.1, height: 1.6, color: palette.ink2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FraudHelpButton(onCallGuardian: widget.onCallGuardian),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: widget.onBack,
          style: FilledButton.styleFrom(
            backgroundColor: palette.blue,
            foregroundColor: Colors.white,
            splashFactory: NoSplash.splashFactory,
            minimumSize: const Size(57, 57),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text(
            '문자로 돌아가기',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    return ColoredBox(
      color: palette.threadBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                topBar,
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: body,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topBar,
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, bottomClearance),
                  child: body,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
