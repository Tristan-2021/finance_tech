import 'package:flutter/material.dart';

import '../sheet.dart';
import '../theme/fb_colors.dart';
import '../theme/fb_icons.dart';
import '../theme/fb_text.dart';

/// 주의 모드 중 감시 대상 금융 행동을 시도할 때 띄우는 공통 확인 질문 화면 (기획서 5.6).
///
/// - 한 화면에 질문 하나만 보여 줍니다.
/// - 큰 버튼 객관식만 제공하며, 어느 선택지도 미리 선택하거나 강조하지 않습니다.
/// - 시간 제한을 두지 않습니다.
/// - 화면이 열리면 TalkBack 초점을 질문 제목으로 옮기고, 읽는 순서대로 이동합니다.
class ConfirmationQuestionView extends StatefulWidget {
  final String question;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final VoidCallback? onAskGuardian;
  final bool busy;

  const ConfirmationQuestionView({
    super.key,
    required this.question,
    required this.options,
    required this.onSelected,
    this.onBack,
    this.onClose,
    this.onAskGuardian,
    this.busy = false,
  });

  @override
  State<ConfirmationQuestionView> createState() => _ConfirmationQuestionViewState();
}

class _ConfirmationQuestionViewState extends State<ConfirmationQuestionView> {
  final _questionFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _questionFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _questionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHead(title: '잠깐만 확인해요', onBack: widget.onBack, onClose: widget.onClose),
          Row(
            children: [
              ExcludeSemantics(child: Icon(FbIcons.shield, size: 16, color: c.redStrong)),
              const SizedBox(width: 6),
              Text(
                '주의 모드 확인 질문',
                style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w700, color: c.redStrong),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Focus(
            focusNode: _questionFocus,
            child: Semantics(
              liveRegion: true,
              header: true,
              child: Text(
                widget.question,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.45, color: c.ink),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '시간 제한이 없어요. 천천히 읽고 가장 가까운 답을 눌러 주세요.',
            style: FbText.hint(c),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < widget.options.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _OptionButton(
              optionKey: ValueKey('caution-option-$i'),
              label: widget.options[i],
              busy: widget.busy,
              onTap: widget.busy ? null : () => widget.onSelected(widget.options[i]),
            ),
          ],
          if (widget.onAskGuardian != null) ...[
            const SizedBox(height: 16),
            Semantics(
              button: true,
              child: OutlinedButton.icon(
                onPressed: widget.busy ? null : widget.onAskGuardian,
                icon: ExcludeSemantics(child: Icon(FbIcons.phone, size: 18, color: c.blue)),
                label: Text('보호자에게 물어보기', style: TextStyle(color: c.blue, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(57, 57),
                  side: BorderSide(color: c.cardBorder ?? c.faint),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final Key optionKey;
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  const _OptionButton({required this.optionKey, required this.label, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      key: optionKey,
      button: true,
      selected: false,
      child: Material(
        color: c.soft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 57, minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.cardBorder ?? c.line, width: c.cardBorder != null ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w700, height: 1.45, color: c.ink),
                  ),
                ),
                const SizedBox(width: 8),
                if (busy)
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.ink2))
                else
                  ExcludeSemantics(child: Icon(FbIcons.chevron, size: 20, color: c.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
