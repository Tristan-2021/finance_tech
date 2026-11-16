import 'dart:math' as math;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

/// 라벨이 [label]인 Semantics 위젯. Tooltip 요소의 노드는 버튼 노드가 아니라서 이렇게 찾는다.
Finder semanticsButton(String label) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label, description: 'Semantics("$label")');

void main() {
  test('light and high-contrast color tokens meet 3:1 minimum contrast ratio', () {
    for (final entry in [('light', FbColors.light), ('highContrast', FbColors.highContrast)]) {
      final (name, c) = entry;
      final pairs = <(String, Color, Color)>[
        ('ink on card', c.ink, c.card),
        ('ink2 on card', c.ink2, c.card),
        ('muted on card', c.muted, c.card),
        ('faint on card', c.faint, c.card),
        ('navIdle on card', c.navIdle, c.card),
        ('ink on bg', c.ink, c.bg),
        ('ink2 on bg', c.ink2, c.bg),
        ('muted on bg', c.muted, c.bg),
        ('faint on bg', c.faint, c.bg),
        ('ink on soft', c.ink, c.soft),
        ('ink2 on soft', c.ink2, c.soft),
        ('muted on soft', c.muted, c.soft),
        ('faint on soft', c.faint, c.soft),
        ('blueStrong on blueSoft', c.blueStrong, c.blueSoft),
        ('blueStrong on card', c.blueStrong, c.card),
        ('redStrong on redSoft', c.redStrong, c.redSoft),
        ('redStrong on card', c.redStrong, c.card),
        ('white on blue', Colors.white, c.blue),
        ('white on blueStrong', Colors.white, c.blueStrong),
        ('white on red', Colors.white, c.red),
        ('white on redStrong', Colors.white, c.redStrong),
      ];
      for (final (label, fg, bg) in pairs) {
        final ratio = _contrastRatio(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: '$name theme "$label" contrast was ${ratio.toStringAsFixed(2)}:1 (< 3.0:1)',
        );
      }
    }
  });

  testWidgets('shared interactive controls satisfy 57x57dp minimum touch area', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FbTheme.build(),
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FbButton('확인', onPressed: () {}),
              FbTextButton('더보기', onPressed: () {}),
              FbToggle(value: false, label: '스위치', onChanged: (_) {}),
              FbFilterChips(items: const [('all', '전체'), ('in', '입금')], active: 'all', onSelected: (_) {}),
              FbOptionRow(title: '옵션', selected: false, onTap: () {}),
              const FraudHelpButton(),
            ],
          ),
        ),
      ),
    );

    for (final finder in [
      find.byType(FbButton),
      find.byType(FbTextButton),
      find.byType(FbToggle),
      find.ancestor(of: find.text('전체'), matching: find.byType(GestureDetector)).first,
      find.ancestor(of: find.text('입금'), matching: find.byType(GestureDetector)).first,
      find.byType(FbOptionRow),
      find.byType(FraudHelpButton),
    ]) {
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(57), reason: 'width < 57 for $finder');
      expect(size.height, greaterThanOrEqualTo(57), reason: 'height < 57 for $finder');
    }
  });

  testWidgets('custom interactive controls expose SemanticsAction.tap in semantics tree', (tester) async {
    final semantics = tester.ensureSemantics();

    var toggled = false;
    var backCount = 0;
    var closeCount = 0;
    var bannerCloseCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: FbTheme.build(),
        home: Scaffold(
          body: Column(
            children: [
              SheetHead(title: '제목', onBack: () => backCount++, onClose: () => closeCount++),
              FbBanner(title: '알림', onClose: () => bannerCloseCount++),
              FbToggle(value: false, label: '경고음', onChanged: (v) => toggled = v),
            ],
          ),
        ),
      ),
    );

    for (final finder in [
      find.byType(FbToggle),
      semanticsButton('뒤로'),
      semanticsButton('닫기'),
      semanticsButton('알림 닫기'),
    ]) {
      final data = tester.getSemantics(finder).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue, reason: 'missing SemanticsAction.tap for $finder');
    }

    tester.binding.performSemanticsAction(SemanticsActionEvent(type: SemanticsAction.tap, nodeId: tester.getSemantics(find.byType(FbToggle)).id, viewId: tester.view.viewId));
    tester.binding.performSemanticsAction(SemanticsActionEvent(type: SemanticsAction.tap, nodeId: tester.getSemantics(semanticsButton('뒤로')).id, viewId: tester.view.viewId));
    tester.binding.performSemanticsAction(SemanticsActionEvent(type: SemanticsAction.tap, nodeId: tester.getSemantics(semanticsButton('닫기')).id, viewId: tester.view.viewId));
    tester.binding.performSemanticsAction(SemanticsActionEvent(type: SemanticsAction.tap, nodeId: tester.getSemantics(semanticsButton('알림 닫기')).id, viewId: tester.view.viewId));
    await tester.pump();

    expect(toggled, isTrue);
    expect(backCount, 1);
    expect(closeCount, 1);
    expect(bannerCloseCount, 1);
    semantics.dispose();
  });
}
