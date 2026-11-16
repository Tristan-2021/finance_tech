import 'package:flutter/material.dart';

import 'theme/fb_colors.dart';
import 'theme/fb_icons.dart';
import 'theme/fb_text.dart';

/// 바텀 시트로 엽니다.
Future<T?> showFbSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    routeSettings: const RouteSettings(),
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: const Color(0x6B152338),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    clipBehavior: Clip.antiAlias,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFE2E6EB), borderRadius: BorderRadius.circular(9)),
              ),
            ),
            builder(ctx),
          ],
        ),
      ),
    ),
  );
}

/// 시트 머리: [뒤로] 제목 [닫기]
class SheetHead extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  const SheetHead({super.key, this.title = '', this.onBack, this.onClose});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final closeAction = onClose ?? () => Navigator.of(context).maybePop();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 57),
        child: Row(
          children: [
            if (onBack != null)
              Tooltip(
                message: '뒤로',
                child: Semantics(
                  button: true,
                  label: '뒤로',
                  onTap: onBack,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 57, minHeight: 57),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FbIcons.back, color: c.ink2, size: 22),
                            Text('뒤로', style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w700, color: c.ink2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (onBack != null) const SizedBox(width: 4),
            Expanded(
              child: Semantics(header: true, child: Text(title, style: FbText.sheetTitle(c))),
            ),
            Tooltip(
              message: '닫기',
              child: Semantics(
                button: true,
                label: '닫기',
                onTap: closeAction,
                excludeSemantics: true,
                child: InkWell(
                  onTap: closeAction,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 57, minHeight: 57),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FbIcons.close, color: c.ink2, size: 18),
                          const SizedBox(width: 4),
                          Text('닫기', style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w700, color: c.ink2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
