import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 휴대폰 문자 화면 시트를 엽니다 (기획서 5.2).
/// [initialSenderPhone]을 주면 해당 발신 번호의 대화를 먼저 보여 줍니다.
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

class SmsSheet extends StatefulWidget {
  final String memberId;
  final String? initialSenderPhone;
  final ValueChanged<String>? onTapPhone;
  final VoidCallback? onCallGuardian;

  const SmsSheet({
    super.key,
    required this.memberId,
    this.initialSenderPhone,
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
    if (widget.initialSenderPhone != null && widget.initialSenderPhone != oldWidget.initialSenderPhone) {
      _selectedPhone = widget.initialSenderPhone;
      _blocked = null;
    }
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
    return BlocBuilder<FamilyCubit, FamilyState>(
      builder: (context, state) {
        if (!state.isReady) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }
        final member = state.data.memberOrNull(widget.memberId);
        if (member == null) return const EmptyText('사용자를 찾을 수 없어요');
        final now = context.read<FamilyCubit>().now();
        final blocked = _blocked;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: blocked != null
              ? KeyedSubtree(
                  key: ValueKey('blocked-${blocked.url}'),
                  child: BlockedLinkView(
                    url: blocked.url,
                    message: blocked.message,
                    onBack: _closeBlockedLink,
                    onCallGuardian: widget.onCallGuardian,
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('conversations'),
                  child: _conversationAndMessages(context, member, now),
                ),
        );
      },
    );
  }

  Widget _conversationAndMessages(BuildContext context, Member member, DateTime now) {
    final c = context.fb;
    final conversations = member.smsConversations;
    if (conversations.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHead(title: '문자'),
          EmptyText('아직 받은 문자가 없어요'),
        ],
      );
    }

    final active = conversations.where((x) => x.senderPhone == _selectedPhone).firstOrNull ?? conversations.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHead(title: '문자'),
        Text('대화 목록', style: FbText.label(c)),
        const SizedBox(height: 8),
        for (final conv in conversations)
          _ConversationTile(
            key: ValueKey('conv-${conv.senderPhone}'),
            conversation: conv,
            selected: conv.senderPhone == active.senderPhone,
            now: now,
            onTap: () => setState(() => _selectedPhone = conv.senderPhone),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(FbIcons.sms, size: 18, color: c.ink2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  active.senderName.isNotEmpty
                      ? '${active.senderName} (${active.senderPhone})'
                      : active.senderPhone,
                  style: TextStyle(fontSize: 14.2, fontWeight: FontWeight.w700, color: c.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final msg in active.messages) ...[
          SmsBubble(
            key: ValueKey('sms-${msg.id}'),
            message: msg,
            now: now,
            onTapLink: (url) => _openBlockedLink(msg, url),
            onTapPhone: widget.onTapPhone,
            onCallGuardian: widget.onCallGuardian,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final SmsConversation conversation;
  final bool selected;
  final DateTime now;
  final VoidCallback onTap;

  const _ConversationTile({
    super.key,
    required this.conversation,
    required this.selected,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final danger = conversation.hasDanger;
    final borderColor = danger
        ? c.redStrong
        : selected
        ? c.blue
        : c.line;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: danger
            ? c.redSoft
            : selected
            ? c.blueSoft
            : c.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: selected || danger ? 1.5 : 1),
            ),
            child: Row(
              children: [
                if (danger)
                  Semantics(
                    label: '위험 대화',
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
                      child: Icon(FbIcons.alert, size: 19, color: c.redStrong),
                    ),
                  )
                else
                  TxLogo.initial(conversation.displaySender, blue: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.displaySender,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.6,
                                fontWeight: FontWeight.w700,
                                color: danger ? c.redStrong : c.ink,
                              ),
                            ),
                          ),
                          Text(formatWhen(conversation.lastMessage.at, now), style: FbText.small(c)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        conversation.lastMessage.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FbText.rowSub(c),
                      ),
                    ],
                  ),
                ),
                if (danger) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: c.redStrong, borderRadius: BorderRadius.circular(99)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FbIcons.alert, size: 13, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          '위험',
                          style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 문자 말풍선 한 개 (기획서 5.2, 7.3).
/// 위험 문자는 색 + 글자 + 아이콘으로 경고와 쉬운 설명을 붙이고, 정상 문자는 경고 없이 보여 줍니다.
class SmsBubble extends StatelessWidget {
  final SmsMessage message;
  final DateTime now;
  final ValueChanged<String> onTapLink;
  final ValueChanged<String>? onTapPhone;
  final VoidCallback? onCallGuardian;

  const SmsBubble({
    super.key,
    required this.message,
    required this.now,
    required this.onTapLink,
    this.onTapPhone,
    this.onCallGuardian,
  });

  static String _stripLinks(String body, List<String> links) {
    var result = body;
    for (final link in links) {
      result = result.replaceAll(link, '').replaceAll('  ', ' ');
    }
    return result.trim();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final danger = message.isDanger;
    final caution = message.isCaution;
    final cleanBody = _stripLinks(message.body, message.links);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger ? c.redSoft : c.soft,
        borderRadius: BorderRadius.circular(18),
        border: danger ? Border.all(color: c.redStrong, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (danger || caution) ...[
            Row(
              children: [
                Semantics(
                  label: danger ? '위험 경고' : '주의',
                  child: Icon(FbIcons.alert, size: 19, color: c.redStrong),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    danger ? '위험 문자 경고' : '주의가 필요한 문자예요',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.redStrong),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (cleanBody.isNotEmpty)
            Text(
              cleanBody,
              style: TextStyle(fontSize: 14.6, height: 1.55, color: c.ink),
            ),
          if (message.links.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final link in message.links)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _SmsLinkButton(
                  url: link,
                  danger: danger,
                  onTap: () => onTapLink(link),
                ),
              ),
          ],
          if (message.phones.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final phone in message.phones)
                  _SmsPhoneDisplay(
                    phone: phone,
                    onTapPhone: onTapPhone,
                  ),
              ],
            ),
          ],
          if ((danger || caution) && message.explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.explanation,
                    style: TextStyle(
                      fontSize: 13.6,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      color: danger ? c.redStrong : c.ink,
                    ),
                  ),
                  if (message.reasons.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final reason in message.reasons)
                      BulletText(reason, style: TextStyle(fontSize: 12.8, height: 1.55, color: c.ink2)),
                  ],
                ],
              ),
            ),
          ],
          if (danger || caution) ...[
            const SizedBox(height: 10),
            FraudHelpButton(onCallGuardian: onCallGuardian),
          ],
          const SizedBox(height: 6),
          Text(
            '${message.displaySender} · ${formatWhen(message.at, now)}',
            style: FbText.small(c),
          ),
        ],
      ),
    );
  }
}

class _SmsLinkButton extends StatelessWidget {
  final String url;
  final bool danger;
  final VoidCallback onTap;

  const _SmsLinkButton({
    required this.url,
    required this.danger,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      button: true,
      label: '문자 속 인터넷 주소 $url',
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: danger ? c.redStrong : c.blue, width: 1.2),
            ),
            child: Row(
              children: [
                Icon(FbIcons.linkOff, size: 17, color: danger ? c.redStrong : c.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    url,
                    style: TextStyle(
                      fontSize: 13.4,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      color: danger ? c.redStrong : c.blue,
                    ),
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

/// 문자 속 전화번호 표시 (기획서 5.2).
/// [onTapPhone] 콜백이 주어지면 통화 화면 발신 버튼으로 표시하고,
/// 주어지지 않으면(`onTapPhone == null`) 누를 수 없는 일반 글자로 보여 줍니다.
class _SmsPhoneDisplay extends StatelessWidget {
  final String phone;
  final ValueChanged<String>? onTapPhone;

  const _SmsPhoneDisplay({
    required this.phone,
    this.onTapPhone,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final callback = onTapPhone;
    if (callback == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          '전화번호 $phone',
          style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w600, color: c.ink2),
        ),
      );
    }
    return Semantics(
      button: true,
      label: '$phone 번호로 통화',
      child: Material(
        color: c.blueSoft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => callback(phone),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FbIcons.phone, size: 15, color: c.blueStrong),
                const SizedBox(width: 5),
                Text(
                  phone,
                  style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w700, color: c.blueStrong),
                ),
              ],
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

  const BlockedLinkView({
    super.key,
    required this.url,
    required this.message,
    required this.onBack,
    this.onCallGuardian,
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
    final c = context.fb;
    final reasonTitle = widget.message.explanation.isNotEmpty
        ? widget.message.explanation
        : '사기 사이트나 악성 앱 설치로 이어질 수 있는 위험한 링크예요.';
    final reasons = widget.message.reasons.isNotEmpty
        ? widget.message.reasons
        : const ['문자 속 인터넷 주소는 공식 기관 주소가 아닐 수 있어요'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '링크 차단 안내', onBack: widget.onBack),
        Focus(
          focusNode: _focus,
          child: const CenterBlock(
            icon: ResultIcon(FbIcons.shield, tone: ResultTone.red),
            title: '이 링크를 열지 않았어요',
            body: '핑거벨이 어르신을 보호하기 위해 문자 속 인터넷 주소를 외부로 열지 않고 안전하게 막았어요.',
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('차단한 주소', style: FbText.small(c)),
              const SizedBox(height: 4),
              Text(
                widget.url,
                style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w700, color: c.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RiskBox(
          title: reasonTitle,
          danger: true,
          items: reasons,
        ),
        const SizedBox(height: 16),
        FraudHelpButton(onCallGuardian: widget.onCallGuardian),
        const SizedBox(height: 10),
        FbButton('문자로 돌아가기', onPressed: widget.onBack),
      ],
    );
  }
}
