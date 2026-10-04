import 'dart:async';

import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_onboarding/src/presentation/login/login_cubit.dart';
import 'package:feature_onboarding/src/presentation/login/login_state.dart';
import 'package:feature_onboarding/src/presentation/login/login_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class FakeAuthRepository implements AuthRepository {
  Failure? failure;
  Completer<void>? gate;
  int signInCalls = 0;
  ({String email, String password})? signInReceived;

  @override
  Future<Failure?> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    signInReceived = (email: email, password: password);
    if (gate != null) await gate!.future;
    return failure;
  }

  @override
  Future<Failure?> signUp(SignUpParams params) async => null;

  @override
  Future<Failure?> signOut() async => null;

  @override
  AuthUser? getCurrentUser() => null;

  @override
  Future<({String? segment, Failure? failure})> getProfileSegment() async =>
      (segment: null, failure: null);

  @override
  Future<({UserProfile? profile, Failure? failure})> getUserProfile() async =>
      (profile: null, failure: null);
}

Widget wrap(Widget child, {ThemeData? theme, double textScale = 1}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: child,
  );
}

Finder get emailField => find.byType(TextField).at(0);
Finder get passwordField => find.byType(TextField).at(1);

void main() {
  late FakeAuthRepository repo;
  late LoginCubit cubit;
  setUp(() {
    repo = FakeAuthRepository();
    cubit = LoginCubit(SignIn(repo));
  });
  tearDown(() => cubit.close());

  group('LoginCubit', () {
    test('estado inicial', () {
      expect(cubit.state, isA<LoginInitial>());
    });

    test('campos vacíos -> LoginInvalid sin llamar al backend', () async {
      await cubit.submit(email: '', password: '');
      final state = cubit.state as LoginInvalid;
      expect(state.emailError, 'Escribe tu correo');
      expect(state.passwordError, 'Escribe tu contraseña');
      expect(repo.signInCalls, 0);
    });

    test('solo contraseña vacía', () async {
      await cubit.submit(email: 'a@b.com', password: '');
      final state = cubit.state as LoginInvalid;
      expect(state.emailError, isNull);
      expect(state.passwordError, 'Escribe tu contraseña');
    });

    test('formato de correo inválido', () async {
      for (final bad in ['abc', 'a@b', 'a b@c.com', '@b.com', 'a@.com']) {
        await cubit.submit(email: bad, password: 'secret123');
        final state = cubit.state as LoginInvalid;
        expect(state.emailError, 'Escribe un correo válido', reason: bad);
      }
      expect(repo.signInCalls, 0);
    });

    test('éxito: Loading y luego Success, con el correo sin espacios', () async {
      final emitted = expectLater(
        cubit.stream,
        emitsInOrder([isA<LoginLoading>(), isA<LoginSuccess>()]),
      );
      await cubit.submit(email: '  a@b.com ', password: 'secret123');
      await emitted;
      expect(repo.signInReceived, (email: 'a@b.com', password: 'secret123'));
    });

    test('cada código de Failure produce su mensaje', () async {
      const expected = {
        'network': 'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
        'auth': 'Correo o contraseña incorrectos.',
        'rls_denied': 'No tienes permiso para ver esta información.',
        'insufficient_funds': 'Saldo insuficiente.',
        'unknown': 'Algo salió mal. Inténtalo de nuevo.',
      };
      for (final entry in expected.entries) {
        repo.failure = Failure('técnico', entry.key);
        await cubit.submit(email: 'a@b.com', password: 'secret123');
        final state = cubit.state as LoginError;
        expect(state.message, entry.value, reason: entry.key);
      }
    });

    test('ignora un segundo envío mientras carga', () async {
      repo.gate = Completer<void>();
      final first = cubit.submit(email: 'a@b.com', password: 'secret123');
      await Future<void>.delayed(Duration.zero);
      await cubit.submit(email: 'a@b.com', password: 'secret123');
      expect(repo.signInCalls, 1);
      repo.gate!.complete();
      await first;
      expect(cubit.state, isA<LoginSuccess>());
    });

    test('no emite si se cierra mientras carga', () async {
      repo.gate = Completer<void>();
      final pending = cubit.submit(email: 'a@b.com', password: 'secret123');
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      repo.gate!.complete();
      await pending;
      expect(cubit.isClosed, isTrue);
    });
  });

  group('LoginView', () {
    late int authenticated;
    late int registerTaps;

    Widget view({ThemeData? theme, double textScale = 1}) {
      return wrap(
        theme: theme,
        textScale: textScale,
        LoginView(
          cubit: cubit,
          onAuthenticated: () => authenticated++,
          onGoToRegister: () => registerTaps++,
        ),
      );
    }

    setUp(() {
      authenticated = 0;
      registerTaps = 0;
    });

    testWidgets('muestra campos, acción y enlace', (tester) async {
      await tester.pumpWidget(view());
      expect(find.text('Inicia sesión'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.byType(TextButton), findsWidgets);
    });

    testWidgets('la contraseña va oculta y los campos llevan autofill', (
      tester,
    ) async {
      await tester.pumpWidget(view());
      final email = tester.widget<TextField>(emailField);
      final password = tester.widget<TextField>(passwordField);
      expect(email.keyboardType, TextInputType.emailAddress);
      expect(email.autofillHints, [AutofillHints.email]);
      expect(password.obscureText, isTrue);
      expect(password.autofillHints, [AutofillHints.password]);
    });

    testWidgets('campos vacíos muestran los errores y no llaman al backend', (
      tester,
    ) async {
      await tester.pumpWidget(view());
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      expect(find.text('Escribe tu correo'), findsOneWidget);
      expect(find.text('Escribe tu contraseña'), findsOneWidget);
      expect(repo.signInCalls, 0);
      expect(authenticated, 0);
    });

    testWidgets('correo con formato inválido muestra el error', (tester) async {
      await tester.pumpWidget(view());
      await tester.enterText(emailField, 'abc');
      await tester.enterText(passwordField, 'secret123');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      expect(find.text('Escribe un correo válido'), findsOneWidget);
      expect(repo.signInCalls, 0);
    });

    testWidgets('éxito llama a onAuthenticated', (tester) async {
      await tester.pumpWidget(view());
      await tester.enterText(emailField, 'a@b.com');
      await tester.enterText(passwordField, 'secret123');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      await tester.pump();
      expect(authenticated, 1);
      expect(repo.signInReceived, (email: 'a@b.com', password: 'secret123'));
    });

    testWidgets('enviar con el teclado (done) también inicia sesión', (
      tester,
    ) async {
      await tester.pumpWidget(view());
      await tester.enterText(emailField, 'a@b.com');
      await tester.enterText(passwordField, 'secret123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      expect(authenticated, 1);
    });

    for (final code in ['network', 'auth', 'rls_denied', 'insufficient_funds', 'unknown']) {
      testWidgets('error "$code": muestra el mensaje y no vacía los campos', (
        tester,
      ) async {
        repo.failure = Failure('técnico', code);
        await tester.pumpWidget(view());
        await tester.enterText(emailField, 'a@b.com');
        await tester.enterText(passwordField, 'secret123');
        await tester.tap(find.text('Iniciar sesión'));
        await tester.pump();
        await tester.pump();

        final message = messageForFailure(Failure('técnico', code));
        expect(find.text(message), findsOneWidget);
        expect(find.text('técnico'), findsNothing);
        expect(tester.widget<TextField>(emailField).controller?.text, 'a@b.com');
        expect(
          tester.widget<TextField>(passwordField).controller?.text,
          'secret123',
        );
        expect(authenticated, 0);
      });
    }

    testWidgets('en carga el botón queda deshabilitado con indicador', (
      tester,
    ) async {
      repo.gate = Completer<void>();
      await tester.pumpWidget(view());
      await tester.enterText(emailField, 'a@b.com');
      await tester.enterText(passwordField, 'secret123');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      // "Crear cuenta" también se deshabilita y los campos no se editan.
      expect(
        tester
            .widgetList<TextButton>(find.byType(TextButton))
            .any((b) => b.onPressed != null && (b.child is Text)),
        isFalse,
      );
      expect(tester.widget<TextField>(emailField).enabled, isFalse);

      repo.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(authenticated, 1);
    });

    testWidgets('"Crear cuenta" llama a onGoToRegister', (tester) async {
      await tester.pumpWidget(view());
      await tester.tap(find.text('Crear cuenta'));
      expect(registerTaps, 1);
    });

    for (final theme in {
      'claro': AppTheme.light(),
      'oscuro': AppTheme.dark(),
    }.entries) {
      testWidgets('áreas táctiles, etiquetas y contraste, tema ${theme.key}', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(view(theme: theme.value));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('texto al 200 % sin desbordes, también con error', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      repo.failure = const Failure('técnico', 'network');
      await tester.pumpWidget(view(textScale: 2.0));
      expect(tester.takeException(), isNull);

      await tester.enterText(emailField, 'a@b.com');
      await tester.enterText(passwordField, 'secret123');
      await tester.tap(find.text('Iniciar sesión'), warnIfMissed: false);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('LoginPage', () {
    final getIt = GetIt.instance;
    tearDown(() async => getIt.reset());

    testWidgets('crea el Cubit desde GetIt y completa el login', (tester) async {
      getIt.registerFactory<LoginCubit>(() => LoginCubit(SignIn(repo)));
      var authenticated = 0;
      await tester.pumpWidget(
        wrap(
          LoginPage(
            onAuthenticated: () => authenticated++,
            onGoToRegister: () {},
          ),
        ),
      );
      await tester.enterText(emailField, 'a@b.com');
      await tester.enterText(passwordField, 'secret123');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      await tester.pump();
      expect(authenticated, 1);
    });
  });
}
