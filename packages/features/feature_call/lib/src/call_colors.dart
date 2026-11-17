import 'package:flutter/material.dart';

/// iOS 전화 앱 모조 화면(`CallApp` · `CallSheet`)이 함께 쓰는 색 팔레트.
class CallUiColors {
  final Color homeBg;
  final Color homeInk;
  final Color homeSubInk;
  final Color dialKeyBg;
  final Color homeDivider;
  final Color homeBorderHighContrast;
  final Color contactAvatarBg;
  final Color contactAvatarFg;
  final Color tabBarBg;
  final Color tabBarBorder;
  final Color tabActiveBlue;
  final Color tabIdleGray;
  final Color homeErrorRed;
  final Color homeErrorBg;

  final Color callGreen;
  final Color callBg;
  final Color callSubText;
  final Color callNameText;
  final Color callActionLabel;
  final Color callEndRed;
  final Color callDeclineRed;
  final Color callEndedText;
  final Color callActionSurface;
  final Color callActionSurfaceTop;
  final Color callActionSurfaceBottom;
  final Color callActionBorder;

  const CallUiColors({
    required this.homeBg,
    required this.homeInk,
    required this.homeSubInk,
    required this.dialKeyBg,
    required this.homeDivider,
    required this.homeBorderHighContrast,
    required this.contactAvatarBg,
    required this.contactAvatarFg,
    required this.tabBarBg,
    required this.tabBarBorder,
    required this.tabActiveBlue,
    required this.tabIdleGray,
    required this.homeErrorRed,
    required this.homeErrorBg,
    required this.callGreen,
    required this.callBg,
    required this.callSubText,
    required this.callNameText,
    required this.callActionLabel,
    required this.callEndRed,
    required this.callDeclineRed,
    required this.callEndedText,
    required this.callActionSurface,
    required this.callActionSurfaceTop,
    required this.callActionSurfaceBottom,
    required this.callActionBorder,
  });

  /// 7.3 명도 대비(3:1 이상)를 맞추기 위해 일반·고대비 모두 iOS 고대비 초록(#248A3D)을 씁니다.
  static const Color sharedCallGreen = Color(0xFF248A3D);

  static const light = CallUiColors(
    homeBg: Colors.white,
    homeInk: Colors.black,
    homeSubInk: Color(0xFF6E6E73),
    dialKeyBg: Color(0xFFE5E5EA),
    homeDivider: Color(0xFFE5E5EA),
    homeBorderHighContrast: Color(0xFF1B1F24),
    contactAvatarBg: Color(0xFFE5E5EA),
    contactAvatarFg: Color(0xFF3C3C43),
    tabBarBg: Color(0xE6FFFFFF),
    tabBarBorder: Color(0x333C3C43),
    tabActiveBlue: Color(0xFF007AFF),
    tabIdleGray: Color(0xFF6E6E73),
    homeErrorRed: Color(0xFFD71913),
    homeErrorBg: Color(0xFFFDECEC),
    callGreen: sharedCallGreen,
    callBg: Color(0xFF171717),
    callSubText: Color(0x80FFFFFF),
    callNameText: Color(0xE6FFFFFF),
    callActionLabel: Color(0x99FFFFFF),
    callEndRed: Color(0xFFD71913),
    callDeclineRed: Color(0xFFD71913),
    callEndedText: Color(0xFFFF6961),
    callActionSurface: Color(0xFF2C2C2E),
    callActionSurfaceTop: Color(0xFF3A3A3C),
    callActionSurfaceBottom: Color(0xFF28282A),
    callActionBorder: Color(0x24FFFFFF),
  );

  static const highContrast = CallUiColors(
    homeBg: Colors.white,
    homeInk: Colors.black,
    homeSubInk: Color(0xFF1C1C1E),
    dialKeyBg: Color(0xFFDADCE0),
    homeDivider: Color(0xFF8A929C),
    homeBorderHighContrast: Color(0xFF1B1F24),
    contactAvatarBg: Color(0xFFDADCE0),
    contactAvatarFg: Colors.black,
    tabBarBg: Color(0xFAFFFFFF),
    tabBarBorder: Color(0xFF1B1F24),
    tabActiveBlue: Color(0xFF0051D5),
    tabIdleGray: Color(0xFF1C1C1E),
    homeErrorRed: Color(0xFFB31412),
    homeErrorBg: Color(0xFFFFE3E7),
    callGreen: sharedCallGreen,
    callBg: Colors.black,
    callSubText: Color(0xD9FFFFFF),
    callNameText: Colors.white,
    callActionLabel: Color(0xD9FFFFFF),
    callEndRed: Color(0xFFE53935),
    callDeclineRed: Color(0xFFE53935),
    callEndedText: Color(0xFFFF8A80),
    callActionSurface: Color(0xFF2C2C2E),
    callActionSurfaceTop: Color(0xFF3A3A3C),
    callActionSurfaceBottom: Color(0xFF28282A),
    callActionBorder: Color(0xB8FFFFFF),
  );

  static CallUiColors of({bool highContrast = false}) =>
      highContrast ? CallUiColors.highContrast : CallUiColors.light;
}
