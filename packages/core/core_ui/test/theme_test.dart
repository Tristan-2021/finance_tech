import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final themes = {'claro': AppTheme.light(), 'oscuro': AppTheme.dark()};

  group('AppTheme', () {
    test('se construye en claro y oscuro con Material 3', () {
      expect(AppTheme.light().useMaterial3, isTrue);
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().useMaterial3, isTrue);
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    test('usa los tokens de marca y de fondo', () {
      final light = AppTheme.light();
      expect(light.colorScheme.primary, const Color(0xFF0B57D0));
      expect(light.scaffoldBackgroundColor, const Color(0xFFF7F8FA));
      expect(light.colorScheme.surface, const Color(0xFFFFFFFF));
      final dark = AppTheme.dark();
      expect(dark.colorScheme.primary, const Color(0xFF8AB4F8));
      expect(dark.scaffoldBackgroundColor, const Color(0xFF0F1318));
      expect(dark.colorScheme.surface, const Color(0xFF171C22));
    });

    test('escala tipográfica: saldo 36, título 22, cuerpo 16, detalle 13', () {
      final t = AppTheme.light().textTheme;
      expect(t.displaySmall?.fontSize, 36);
      expect(t.displaySmall?.fontWeight, FontWeight.w600);
      expect(t.titleLarge?.fontSize, 22);
      expect(t.bodyMedium?.fontSize, 16);
      expect(t.bodySmall?.fontSize, 13);
    });

    test('las tarjetas son redondeadas con 16 y los botones mínimo 48 dp', () {
      final theme = AppTheme.light();
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(AppRadius.card));
      final size = theme.filledButtonTheme.style?.minimumSize?.resolve({});
      expect(size?.height, greaterThanOrEqualTo(48));
    });
  });

  group('AppSemanticColors', () {
    test('está disponible en ambos temas', () {
      for (final theme in themes.values) {
        expect(theme.extension<AppSemanticColors>(), isNotNull);
      }
    });

    test('valores de ingreso y egreso', () {
      final light = AppTheme.light().extension<AppSemanticColors>()!;
      expect(light.credit, const Color(0xFF1B7F4B));
      expect(light.debit, const Color(0xFFB3261E));
      final dark = AppTheme.dark().extension<AppSemanticColors>()!;
      expect(dark.credit, const Color(0xFF6FD39A));
      expect(dark.debit, const Color(0xFFF2A19B));
    });

    test('copyWith y lerp', () {
      final base = AppTheme.light().extension<AppSemanticColors>()!;
      final changed = base.copyWith(credit: Colors.black);
      expect(changed.credit, Colors.black);
      expect(changed.debit, base.debit);
      expect(base.lerp(changed, 0), base);
      expect(base.lerp(null, 0.5), base);
    });

    test('contraste AA (4.5:1) sobre fondo y superficie', () {
      for (final entry in themes.entries) {
        final theme = entry.value;
        final sem = theme.extension<AppSemanticColors>()!;
        final bases = [
          theme.scaffoldBackgroundColor,
          theme.colorScheme.surface,
        ];
        for (final base in bases) {
          for (final color in [sem.credit, sem.debit, sem.warning]) {
            expect(
              contrast(color, base),
              greaterThanOrEqualTo(4.5),
              reason: 'tema ${entry.key}: $color sobre $base',
            );
          }
        }
      }
    });

    test('contraste AA del texto sobre primario y de error', () {
      for (final theme in themes.values) {
        final s = theme.colorScheme;
        expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
        expect(contrast(s.onError, s.error), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('AppSpacing y AppRadius', () {
    test('escala de espaciado 4, 8, 12, 16, 24, 32', () {
      expect(
        [
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ],
        [4, 8, 12, 16, 24, 32],
      );
    });

    test('radios: 12 campos y botones, 16 tarjetas', () {
      expect(AppRadius.field, 12);
      expect(AppRadius.button, 12);
      expect(AppRadius.card, 16);
    });
  });

  group('contraste del texto (textContrastGuideline)', () {
    for (final entry in themes.entries) {
      testWidgets('texto principal y secundario, tema ${entry.key}', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final text = Theme.of(context).textTheme;
                  return Column(
                    children: [
                      const Text('Texto principal sobre el fondo'),
                      Text('Detalle sobre el fondo', style: text.bodySmall),
                      Card(
                        child: Column(
                          children: [
                            const Text('Texto principal en tarjeta'),
                            Text('Detalle en tarjeta', style: text.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });
}
