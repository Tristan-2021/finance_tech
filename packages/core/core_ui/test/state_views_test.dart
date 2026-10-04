import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child, {ThemeData? theme, double textScale = 1}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  final themes = {'claro': AppTheme.light(), 'oscuro': AppTheme.dark()};

  group('messageForFailure', () {
    test('network', () {
      expect(
        messageForFailure(const Failure('x', 'network')),
        'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
      );
    });
    test('auth', () {
      expect(
        messageForFailure(const Failure('x', 'auth')),
        'Correo o contraseña incorrectos.',
      );
    });
    test('rls_denied', () {
      expect(
        messageForFailure(const Failure('x', 'rls_denied')),
        'No tienes permiso para ver esta información.',
      );
    });
    test('insufficient_funds', () {
      expect(
        messageForFailure(const Failure('x', 'insufficient_funds')),
        'Saldo insuficiente.',
      );
    });
    test('cualquier otro código, o ninguno, da el mensaje genérico', () {
      const generic = 'Algo salió mal. Inténtalo de nuevo.';
      expect(messageForFailure(const Failure('x', 'unknown')), generic);
      expect(messageForFailure(const Failure('x', 'invalid_input')), generic);
      expect(messageForFailure(const Failure('x', 'no_account')), generic);
      expect(messageForFailure(const Failure('x', 'codigo_nuevo')), generic);
      expect(messageForFailure(const Failure('x')), generic);
    });
    test('no filtra el mensaje técnico del Failure', () {
      final text = messageForFailure(const Failure('SocketException: 10.0.0.1', 'network'));
      expect(text, isNot(contains('SocketException')));
    });
  });

  group('LoadingView', () {
    testWidgets('muestra el indicador y lo anuncia', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(const LoadingView()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Cargando'), findsWidgets);
      handle.dispose();
    });
  });

  group('EmptyView', () {
    testWidgets('muestra el mensaje', (tester) async {
      await tester.pumpWidget(
        wrap(const EmptyView(message: 'Aún no tienes movimientos')),
      );
      expect(find.text('Aún no tienes movimientos'), findsOneWidget);
    });
  });

  group('ErrorView', () {
    testWidgets('muestra el mensaje y reintenta', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        wrap(ErrorView(message: 'Saldo insuficiente.', onRetry: () => retries++)),
      );
      expect(find.text('Saldo insuficiente.'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(retries, 1);
    });
  });

  group('OfflineBanner', () {
    testWidgets('muestra el aviso y reintenta', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        wrap(OfflineBanner(onRetry: () => retries++)),
      );
      expect(find.textContaining('Sin conexión'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(retries, 1);
    });
  });

  group('accesibilidad', () {
    for (final theme in themes.entries) {
      testWidgets('áreas táctiles y etiquetas, tema ${theme.key}', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          wrap(
            theme: theme.value,
            Column(
              children: [
                OfflineBanner(onRetry: () {}),
                Expanded(
                  child: ErrorView(message: 'Algo salió mal.', onRetry: () {}),
                ),
              ],
            ),
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('contraste del texto, tema ${theme.key}', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          wrap(
            theme: theme.value,
            Column(
              children: [
                OfflineBanner(onRetry: () {}),
                const Expanded(child: EmptyView(message: 'Sin movimientos')),
                Expanded(
                  child: ErrorView(message: 'Algo salió mal.', onRetry: () {}),
                ),
              ],
            ),
          ),
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('texto al 200 % sin desbordes', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(
          textScale: 2.0,
          SingleChildScrollView(
            child: Column(
              children: [
                OfflineBanner(onRetry: () {}),
                const SizedBox(
                  height: 300,
                  child: EmptyView(message: 'Aún no tienes movimientos'),
                ),
                SizedBox(
                  height: 400,
                  child: ErrorView(
                    message: 'No tienes permiso para ver esta información.',
                    onRetry: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('con muy poco alto hacen scroll en lugar de desbordar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(
          textScale: 2.0,
          Column(
            children: [
              const SizedBox(
                height: 120,
                child: EmptyView(message: 'Aún no tienes movimientos'),
              ),
              SizedBox(
                height: 120,
                child: ErrorView(
                  message: 'No tienes permiso para ver esta información.',
                  onRetry: () {},
                ),
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsNWidgets(2));
    });
  });
}
