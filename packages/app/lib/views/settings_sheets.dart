import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 설정 › 사용 방법: 아이콘과 쉬운 글로 된 안내 3장 시트를 엽니다 (기획서 7.1 Ⅲ-①).
/// 자동으로 넘어가지 않으며 사용자가 직접 [이전] / [다음]을 눌러 넘깁니다.
Future<void> openHowToUseSheet(BuildContext context) =>
    showFbSheet<void>(context, builder: (_) => const HowToUseSheet());

/// 설정 › 불편한 점 보내기 시트를 엽니다 (기획서 7.1 Ⅲ-③).
Future<void> openFeedbackSheet(BuildContext context, {required String memberId}) =>
    showFbSheet<void>(context, builder: (_) => FeedbackSheet(memberId: memberId));

class HowToUseSheet extends StatefulWidget {
  const HowToUseSheet({super.key});

  @override
  State<HowToUseSheet> createState() => _HowToUseSheetState();
}

class _HowToUseSheetState extends State<HowToUseSheet> {
  static const _cards = [
    (
      icon: FbIcons.sms,
      badge: FbIcons.alert,
      title: '위험 문자 경고',
      summary: '사기 의심 문자가 오면 경고와 쉬운 설명을 보여 줘요.',
      steps: [
        '기관을 사칭하거나 돈을 요구하는 문자에는 빨간 위험 표시와 쉬운 설명이 붙어요.',
        '문자 속 인터넷 주소를 실수로 눌러도 외부로 열리지 않고 핑거벨이 안전하게 막아 줘요.',
        '위험 문자가 감지되면 24시간 동안 주의 모드가 켜져서 큰 거래 전 한 번 더 확인해요.',
      ],
    ),
    (
      icon: FbIcons.clock,
      badge: FbIcons.shield,
      title: '보류가 걸렸을 때',
      summary: '위험한 송금·해지·대출은 30분 동안 잠시 멈춰요.',
      steps: [
        '보이스피싱이 의심되는 거래는 돈이 바로 나가지 않고 30분 동안 보류돼요.',
        '보호자께 바로 알림이 가고, 보호자가 확인한 뒤 보류를 해제하거나 연장할 수 있어요.',
        '마음이 바뀌면 보류 중 언제든 [취소]를 눌러 거래를 멈출 수 있어요.',
      ],
    ),
    (
      icon: FbIcons.lock,
      badge: FbIcons.shake,
      title: 'SOS 계좌 동결',
      summary: '급할 때 모든 계좌 출금을 한 번에 막아요.',
      steps: [
        '홈의 SOS 계좌 동결 버튼을 누르거나 길게 누르고, 또는 휴대폰을 3초 동안 세게 흔들어 보세요.',
        '확인하면 모든 계좌의 출금이 24시간 멈추고 보호자께 바로 알림이 가요.',
        '입금은 그대로 받을 수 있고, 해제는 보호자에게 요청할 수 있어요.',
      ],
    ),
  ];

  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speakCurrentCard();
    });
  }

  void _speakCurrentCard() {
    final card = _cards[_index];
    final text = '${_index + 1}번째 안내, ${card.title}. ${card.summary} ${card.steps.join(' ')}';
    try {
      context.read<ShellCubit>().say(
        text,
        toast: false,
        vibrate: const [],
        speak: true,
      );
    } catch (_) {}
  }

  void _goTo(int next) {
    setState(() => _index = next);
    _speakCurrentCard();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final card = _cards[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHead(title: '사용 방법'),
        Row(
          children: [
            Text('${_index + 1} / ${_cards.length}', style: TextStyle(fontSize: 13.8, fontWeight: FontWeight.w800, color: c.blueStrong)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('직접 눌러서 다음 안내를 보세요', style: FbText.small(c)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.soft,
            borderRadius: BorderRadius.circular(18),
            border: c.cardBorder != null ? Border.all(color: c.cardBorder!) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: c.blueSoft, shape: BoxShape.circle),
                      child: Icon(card.icon, size: 26, color: c.blueStrong),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.ink)),
                        const SizedBox(height: 2),
                        Text(card.summary, style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w600, color: c.ink2)),
                      ],
                    ),
                  ),
                  ExcludeSemantics(child: Icon(card.badge, size: 22, color: c.blueStrong)),
                ],
              ),
              const SizedBox(height: 14),
              for (final step in card.steps) ...[
                BulletText(step, style: TextStyle(fontSize: 14.2, height: 1.55, color: c.ink)),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        FbButtonRow(
          children: [
            FbButton.gray(
              '이전',
              onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
            ),
            if (_index < _cards.length - 1)
              FbButton(
                '다음',
                onPressed: () => _goTo(_index + 1),
              )
            else
              FbButton(
                '닫기',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
          ],
        ),
      ],
    );
  }
}

class FeedbackSheet extends StatefulWidget {
  final String memberId;

  const FeedbackSheet({super.key, required this.memberId});

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  static const _categories = [
    '글자가 작아요',
    '화면이 복잡해요',
    '소리가 작아요',
    '기타',
  ];

  String? _selectedCategory;
  final _messageCtrl = TextEditingController();
  final _categoryFocus = FocusNode();
  final _messageFocus = FocusNode();
  String? _error;
  bool _busy = false;
  bool _saved = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _categoryFocus.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final category = _selectedCategory;
    if (category == null || category.trim().isEmpty) {
      setState(() => _error = '불편한 점 종류를 먼저 선택해 주세요.');
      _categoryFocus.requestFocus();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final shell = context.read<ShellCubit>();
    try {
      await context.read<FamilyCubit>().submitFeedback(
        widget.memberId,
        category: category,
        message: _messageCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saved = true;
      });
      shell.say('의견을 보냈어요. 고맙습니다!');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      _messageFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    if (_saved) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHead(title: '불편한 점 보내기'),
          const CenterBlock(
            icon: ResultIcon(FbIcons.check),
            title: '의견을 보냈어요',
            body: '남겨 주신 의견은 앱을 더 쉽게 고치는 데 쓸게요. 고맙습니다.',
          ),
          const SizedBox(height: 18),
          FbButton('확인', onPressed: () => Navigator.of(context).maybePop()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHead(title: '불편한 점 보내기'),
        Text(
          '전화 연결 없이 버튼 하나를 고르고 한 줄 의견을 서버에 남길 수 있어요.',
          style: FbText.hint(c),
        ),
        const SizedBox(height: 14),
        Focus(
          focusNode: _categoryFocus,
          child: Text('불편한 점 종류', style: FbText.label(c)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in _categories)
              Semantics(
                button: true,
                selected: _selectedCategory == cat,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _busy
                      ? null
                      : () => setState(() {
                          _selectedCategory = cat;
                          _error = null;
                        }),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 57, minHeight: 57),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedCategory == cat ? c.blueSoft : c.soft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedCategory == cat ? c.blueStrong : (c.cardBorder ?? c.line),
                        width: _selectedCategory == cat ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _selectedCategory == cat ? c.blueStrong : c.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('feedback-message-input'),
          controller: _messageCtrl,
          focusNode: _messageFocus,
          maxLength: 300,
          maxLines: 1,
          decoration: InputDecoration(
            labelText: '불편한 점 (한 줄)',
            hintText: '예: 글자가 조금 더 크면 좋겠어요',
            counterText: '',
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        FbButton('의견 보내기', busy: _busy, onPressed: _busy ? null : _submit),
      ],
    );
  }
}
