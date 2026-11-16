import 'package:flutter/material.dart';

import '../sheet.dart';
import '../theme/fb_colors.dart';
import '../theme/fb_icons.dart';
import '../theme/fb_text.dart';
import 'buttons.dart';

/// 홈과 모든 경고 화면에 같은 이름·모양으로 놓는 [사기 신고·도움] 버튼 (기획서 7.1 Ⅲ-②).
class FraudHelpButton extends StatelessWidget {
  final VoidCallback? onCallGuardian;
  final String? guardianName;

  const FraudHelpButton({super.key, this.onCallGuardian, this.guardianName});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      button: true,
      child: OutlinedButton.icon(
        key: const ValueKey('fraud-help-button'),
        onPressed: () => showFraudHelpSheet(
          context,
          onCallGuardian: onCallGuardian,
          guardianName: guardianName,
        ),
        icon: ExcludeSemantics(child: Icon(FbIcons.shield, size: 19, color: c.redStrong)),
        label: Text(
          '사기 신고·도움',
          style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w800, color: c.redStrong),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: c.card,
          minimumSize: const Size(57, 57),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          side: BorderSide(color: c.redStrong, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

/// 사기 신고·도움 안내 시트를 엽니다.
/// 경찰 112, 금융감독원 1332 안내와 [보호자에게 전화]를 보여 주며 실제 전화는 걸지 않습니다.
Future<void> showFraudHelpSheet(
  BuildContext context, {
  VoidCallback? onCallGuardian,
  String? guardianName,
}) => showFbSheet<void>(
  context,
  builder: (ctx) => _FraudHelpSheetContent(
    onCallGuardian: onCallGuardian,
    guardianName: guardianName,
  ),
);

class _FraudHelpSheetContent extends StatefulWidget {
  final VoidCallback? onCallGuardian;
  final String? guardianName;

  const _FraudHelpSheetContent({this.onCallGuardian, this.guardianName});

  @override
  State<_FraudHelpSheetContent> createState() => _FraudHelpSheetContentState();
}

class _FraudHelpSheetContentState extends State<_FraudHelpSheetContent> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHead(title: '사기 신고·도움'),
        Focus(
          focusNode: _focus,
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.redSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.redStrong, width: 1.2),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(child: Icon(FbIcons.alert, size: 20, color: c.redStrong)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '시연용이라 실제 전화는 걸지 않습니다',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.redStrong),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _HelpNumberBox(
          icon: FbIcons.shield,
          title: '경찰 신고 112',
          subtitle: '보이스피싱·협박·긴급 피해가 의심될 때 112로 신고하세요.',
          number: '112',
        ),
        const SizedBox(height: 10),
        _HelpNumberBox(
          icon: FbIcons.phone,
          title: '금융감독원 1332',
          subtitle: '금융사기 상담, 피해 구제, 지급정지 안내를 받을 수 있어요.',
          number: '1332',
        ),
        const SizedBox(height: 16),
        if (widget.onCallGuardian != null) ...[
          FbButton(
            widget.guardianName != null && widget.guardianName!.isNotEmpty
                ? '보호자에게 전화 (${widget.guardianName})'
                : '보호자에게 전화',
            icon: FbIcons.phone,
            onPressed: () {
              Navigator.of(context).pop();
              widget.onCallGuardian!();
            },
          ),
          const SizedBox(height: 8),
        ],
        FbButton.gray('닫기', onPressed: () => Navigator.of(context).maybePop()),
      ],
    );
  }
}

class _HelpNumberBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String number;

  const _HelpNumberBox({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(14),
        border: c.cardBorder != null ? Border.all(color: c.cardBorder!) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.blueSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: c.blueStrong),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w800, color: c.ink)),
                    ),
                    Text(number, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.blueStrong)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: FbText.small(c).copyWith(color: c.ink2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
