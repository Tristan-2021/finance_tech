import 'package:flutter/material.dart';

/// iOS 기본 앱(전화·문자)을 흉내 낸 화면들이 공통으로 쓰는 색과 테마.
final class IosPalette {
  final bool highContrast;
  final Color ink;
  final Color ink2;
  final Color blue;
  final Color red;
  final Color divider;
  final Color avatarBg;
  final Color avatarFg;

  const IosPalette._({
    required this.highContrast,
    required this.ink,
    required this.ink2,
    required this.blue,
    required this.red,
    required this.divider,
    required this.avatarBg,
    required this.avatarFg,
  });

  factory IosPalette.of({required bool highContrast}) => IosPalette._(
    highContrast: highContrast,
    ink: Colors.black,
    ink2: highContrast ? const Color(0xFF1C1C1E) : const Color(0xFF6E6E73),
    blue: highContrast ? const Color(0xFF0051D5) : const Color(0xFF007AFF),
    red: highContrast ? const Color(0xFFB31412) : const Color(0xFFD71913),
    divider: highContrast ? const Color(0xFF8A929C) : const Color(0xFFE5E5EA),
    avatarBg: highContrast ? const Color(0xFFDADCE0) : const Color(0xFFE5E5EA),
    avatarFg: highContrast ? Colors.black : const Color(0xFF3C3C43),
  );
}

/// Material 물결 효과를 끄고 iOS 스타일의 옅은 눌림 효과만 남긴 테마.
ThemeData iosNoSplashTheme(BuildContext context) => Theme.of(context).copyWith(
  splashFactory: NoSplash.splashFactory,
  splashColor: Colors.transparent,
  highlightColor: const Color(0x14000000),
);

/// 전화·문자 앱 상단에 띄우는 iOS 스타일 오프라인 안내 막대.
class IosOfflineNoticeBar extends StatelessWidget {
  final bool highContrast;
  final VoidCallback onRetry;

  const IosOfflineNoticeBar({super.key, required this.highContrast, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final red = IosPalette.of(highContrast: highContrast).red;
    final bg = highContrast ? const Color(0xFFFFE3E7) : const Color(0xFFFDECEC);
    return Semantics(
      liveRegion: true,
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(Icons.cloud_off_outlined, size: 18, color: red)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '서버와 연결이 끊겼어요',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: red),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: red,
                splashFactory: NoSplash.splashFactory,
                minimumSize: const Size(57, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
