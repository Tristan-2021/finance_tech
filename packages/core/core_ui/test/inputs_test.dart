import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child, {double textScale = 1, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    ),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('llama a onPressed al tocar', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(AppButton(label: 'Continuar', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Continuar'));
      expect(taps, 1);
    });

    testWidgets('con isLoading queda deshabilitado y muestra indicador', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          AppButton(label: 'Continuar', isLoading: true, onPressed: () => taps++),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continuar'), findsNothing);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('con isLoading anuncia la etiqueta y que está cargando', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(AppButton(label: 'Continuar', isLoading: true, onPressed: () {})),
      );
      expect(find.bySemanticsLabel('Continuar, cargando'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('onPressed null lo deshabilita', (tester) async {
      await tester.pumpWidget(
        wrap(const AppButton(label: 'Continuar', onPressed: null)),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
    });

    testWidgets('variantes usan el botón de Material correspondiente', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              AppButton(label: 'A', onPressed: () {}),
              AppButton(
                label: 'B',
                onPressed: () {},
                variant: AppButtonVariant.secondary,
              ),
              AppButton(
                label: 'C',
                onPressed: () {},
                variant: AppButtonVariant.text,
              ),
            ],
          ),
        ),
      );
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    for (final theme in {
      'claro': AppTheme.light(),
      'oscuro': AppTheme.dark(),
    }.entries) {
      testWidgets('áreas táctiles y etiquetas, tema ${theme.key}', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          wrap(
            theme: theme.value,
            Column(
              children: [
                AppButton(label: 'Primario', onPressed: () {}),
                AppButton(
                  label: 'Secundario',
                  onPressed: () {},
                  variant: AppButtonVariant.secondary,
                ),
                AppButton(
                  label: 'Texto',
                  onPressed: () {},
                  variant: AppButtonVariant.text,
                ),
              ],
            ),
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  group('AppTextField', () {
    testWidgets('muestra la etiqueta visible', (tester) async {
      await tester.pumpWidget(wrap(const AppTextField(label: 'Correo')));
      expect(find.text('Correo'), findsOneWidget);
    });

    testWidgets('muestra y anuncia el error', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(const AppTextField(label: 'Correo', errorText: 'Correo inválido')),
      );
      expect(find.text('Correo inválido'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Correo inválido')),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('sin errorText no muestra error', (tester) async {
      await tester.pumpWidget(wrap(const AppTextField(label: 'Correo')));
      expect(find.text('Correo inválido'), findsNothing);
    });

    testWidgets('alterna mostrar/ocultar la contraseña', (tester) async {
      await tester.pumpWidget(
        wrap(const AppTextField(label: 'Contraseña', obscure: true)),
      );
      bool obscured() =>
          tester.widget<EditableText>(find.byType(EditableText)).obscureText;

      expect(obscured(), isTrue);
      expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);

      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(obscured(), isFalse);
      expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);

      await tester.tap(find.byTooltip('Ocultar contraseña'));
      await tester.pump();
      expect(obscured(), isTrue);
    });

    testWidgets('sin obscure no hay botón mostrar/ocultar', (tester) async {
      await tester.pumpWidget(wrap(const AppTextField(label: 'Correo')));
      expect(find.byType(IconButton), findsNothing);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isFalse,
      );
    });

    testWidgets('onChanged y onSubmitted reciben el texto', (tester) async {
      final changes = <String>[];
      final submits = <String>[];
      await tester.pumpWidget(
        wrap(
          AppTextField(
            label: 'Correo',
            textInputAction: TextInputAction.done,
            onChanged: changes.add,
            onSubmitted: submits.add,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'a@b.com');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(changes, ['a@b.com']);
      expect(submits, ['a@b.com']);
    });

    testWidgets('usa el controller recibido', (tester) async {
      final controller = TextEditingController(text: 'hola');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrap(AppTextField(label: 'Texto', controller: controller)),
      );
      expect(find.text('hola'), findsOneWidget);
    });

    testWidgets('pasa teclado, autofill y acción al TextField', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AppTextField(
            label: 'Correo',
            keyboardType: TextInputType.emailAddress,
            autofillHints: [AutofillHints.email],
            textInputAction: TextInputAction.next,
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.emailAddress);
      expect(field.autofillHints, [AutofillHints.email]);
      expect(field.textInputAction, TextInputAction.next);
    });

    testWidgets('enabled false deshabilita campo y botón de contraseña', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const AppTextField(label: 'Contraseña', obscure: true, enabled: false),
        ),
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull);
    });

    testWidgets('áreas táctiles y etiquetas', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(const AppTextField(label: 'Contraseña', obscure: true)),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('AppStepIndicator', () {
    testWidgets('anuncia "Paso 2 de 3"', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(const AppStepIndicator(current: 2, total: 3)),
      );
      expect(find.bySemanticsLabel('Paso 2 de 3'), findsOneWidget);
      expect(find.text('Paso 2 de 3'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('rellena los segmentos hasta el paso actual', (tester) async {
      await tester.pumpWidget(
        wrap(const AppStepIndicator(current: 2, total: 4)),
      );
      final primary = AppTheme.light().colorScheme.primary;
      final inactive = AppTheme.light().colorScheme.outlineVariant;
      Color colorOf(int i) {
        final box = tester.widget<DecoratedBox>(
          find.byKey(ValueKey('step-segment-$i')),
        );
        return (box.decoration as BoxDecoration).color!;
      }

      expect(colorOf(1), primary);
      expect(colorOf(2), primary);
      expect(colorOf(3), inactive);
      expect(colorOf(4), inactive);
    });

    testWidgets('dibuja tantos segmentos como pasos', (tester) async {
      await tester.pumpWidget(
        wrap(const AppStepIndicator(current: 1, total: 5)),
      );
      for (var i = 1; i <= 5; i++) {
        expect(find.byKey(ValueKey('step-segment-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('step-segment-6')), findsNothing);
    });
  });

  group('texto al 200 % sin desbordes', () {
    testWidgets('botones, campos e indicador de pasos', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(
          textScale: 2.0,
          Column(
            children: [
              const AppStepIndicator(current: 2, total: 3),
              const SizedBox(height: AppSpacing.lg),
              const AppTextField(
                label: 'Correo electrónico',
                errorText: 'Escribe un correo válido',
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppTextField(label: 'Contraseña', obscure: true),
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Crear mi cuenta ahora', onPressed: () {}),
              AppButton(
                label: 'Ya tengo una cuenta',
                onPressed: () {},
                variant: AppButtonVariant.secondary,
              ),
              AppButton(label: 'Continuar', isLoading: true, onPressed: () {}),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
