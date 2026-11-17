import 'dart:math' as math;

import 'package:feature_call/feature_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _linearize(int channel) {
  final c = channel / 255.0;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color color) {
  final r = _linearize((color.r * 255).round());
  final g = _linearize((color.g * 255).round());
  final b = _linearize((color.b * 255).round());
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final bright = math.max(la, lb);
  final dark = math.min(la, lb);
  return (bright + 0.05) / (dark + 0.05);
}

void main() {
  test('phone app color palette satisfies 3:1 minimum contrast ratio', () {
    for (final entry in [('light', CallUiColors.light), ('highContrast', CallUiColors.highContrast)]) {
      final (name, c) = entry;
      final subOnCallBg = Color.alphaBlend(c.callSubText, c.callBg);
      final actionLabelOnCallBg = Color.alphaBlend(c.callActionLabel, c.callBg);
      final tabSurface = Color.alphaBlend(c.tabBarBg, c.homeBg);

      final pairs = <(String, Color, Color)>[
        ('white on callGreen', Colors.white, c.callGreen),
        ('callGreen on homeBg', c.callGreen, c.homeBg),
        ('callGreen on callBg', c.callGreen, c.callBg),
        ('white on callEndRed', Colors.white, c.callEndRed),
        ('white on callDeclineRed', Colors.white, c.callDeclineRed),
        ('callSubText composited on callBg', subOnCallBg, c.callBg),
        ('callActionLabel composited on callBg', actionLabelOnCallBg, c.callBg),
        ('tabIdleGray on homeBg', c.tabIdleGray, c.homeBg),
        ('tabIdleGray on tabSurface', c.tabIdleGray, tabSurface),
        ('tabActiveBlue on homeBg', c.tabActiveBlue, c.homeBg),
        ('tabActiveBlue on tabSurface', c.tabActiveBlue, tabSurface),
        ('homeErrorRed on homeBg', c.homeErrorRed, c.homeBg),
        ('homeSubInk on homeBg', c.homeSubInk, c.homeBg),
        ('callEndedText on callBg', c.callEndedText, c.callBg),
      ];

      for (final (label, fg, bg) in pairs) {
        final ratio = _contrastRatio(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: '$name CallUiColors "$label" contrast was ${ratio.toStringAsFixed(2)}:1 (< 3.0:1)',
        );
      }
    }
  });
}
