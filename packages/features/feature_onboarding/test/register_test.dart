import 'dart:async';

import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_onboarding/src/presentation/onboarding_strings.dart';
import 'package:feature_onboarding/src/presentation/register/register_cubit.dart';
import 'package:feature_onboarding/src/presentation/register/register_state.dart';
import 'package:feature_onboarding/src/presentation/register/register_view.dart';
import 'package:feature_onboarding/src/presentation/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class FakeAuthRepository implements AuthRepository {
  Failure? signUpFailure;
  AuthUser? user = const AuthUser(id: 'u1', email: 'a@b.com');
  Completer<void>? gate;
  int signUpCalls = 0;
  SignUpParams? received;

  @override
  Future<Failure?> signUp(SignUpParams params) async {
    signUpCalls++;
    received = params;
    if (gate != null) await gate!.future;
    return signUpFailure;
  }

  @override
  AuthUser? getCurrentUser() => user;

  @override
  Future<Failure?> signIn({
    required String email,
    required String password,
  }) async => null;

  @override
  Future<Failure?> signOut() async => null;

  @override
  Future<({String? segment, Failure? failure})> getProfileSegment() async =>
      (segment: null, failure: null);

  @override
  Future<({UserProfile? profile, Failure? failure})> getUserProfile() async =>
      (profile: null, failure: null);
}

// "Hoy" fijo para los tests de edad.
final today = DateTime(2026, 10, 4);

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

void main() {
  late FakeAuthRepository repo;
  late RegisterCubit cubit;
  setUp(() {
    repo = FakeAuthRepository();
    cubit = RegisterCubit(
      signUp: SignUp(repo),
      getCurrentUser: GetCurrentUser(repo),
      clock: () => today,
    );
  });
  tearDown(() => cubit.close());

  void toStep3({DateTime? birth}) {
    cubit.nextFromCredentials(email: 'a@b.com', password: 'secret123');
    cubit.nextFromProfile(
      fullName: 'Ana Pérez',
      birthDate: birth ?? DateTime(2000, 5, 7),
    );
  }

  group('isAtLeast18', () {
    test('el día exacto de los 18 cuenta', () {
      expect(isAtLeast18(DateTime(2008, 10, 4), today), isTrue);
    });
    test('el día anterior a cumplir 18 no cuenta', () {
      expect(isAtLeast18(DateTime(2008, 10, 5), today), isFalse);
    });
    test('un día después de cumplir 18 cuenta', () {
      expect(isAtLeast18(DateTime(2008, 10, 3), today), isTrue);
    });
    test('mes posterior en el mismo año no cuenta', () {
      expect(isAtLeast18(DateTime(2008, 11, 1), today), isFalse);
    });
    test('nacido un 29 de febrero', () {
      final leap = DateTime(2008, 2, 29);
      expect(isAtLeast18(leap, DateTime(2026, 2, 28)), isFalse);
      expect(isAtLeast18(leap, DateTime(2026, 3, 1)), isTrue);
    });
  });

  group('RegisterCubit: paso 1 (credenciales)', () {
    test('estado inicial', () {
      expect(cubit.state.step, 1);
      expect(cubit.state.status, RegisterStatus.editing);
    });

    test('vacío -> errores y no avanza', () {
      cubit.nextFromCredentials(email: '', password: '');
      expect(cubit.state.step, 1);
      expect(cubit.state.emailError, 'Escribe tu correo');
      expect(cubit.state.passwordError, 'Escribe tu contraseña');
    });

    test('correo con formato inválido', () {
      cubit.nextFromCredentials(email: 'abc', password: 'secret123');
      expect(cubit.state.step, 1);
      expect(cubit.state.emailError, 'Escribe un correo válido');
      expect(cubit.state.passwordError, isNull);
    });

    test('contraseña de 7 caracteres no avanza', () {
      cubit.nextFromCredentials(email: 'a@b.com', password: '1234567');
      expect(cubit.state.step, 1);
      expect(
        cubit.state.passwordError,
        'La contraseña debe tener al menos 8 caracteres',
      );
    });

    test('contraseña de 8 caracteres avanza y guarda el correo limpio', () {
      cubit.nextFromCredentials(email: ' a@b.com ', password: '12345678');
      expect(cubit.state.step, 2);
      expect(cubit.state.email, 'a@b.com');
      expect(cubit.state.emailError, isNull);
      expect(cubit.state.passwordError, isNull);
    });
  });

  group('RegisterCubit: paso 2 (perfil y mayoría de edad)', () {
    setUp(() {
      cubit.nextFromCredentials(email: 'a@b.com', password: 'secret123');
    });

    test('nombre vacío y sin fecha', () {
      cubit.nextFromProfile(fullName: '  ', birthDate: null);
      expect(cubit.state.step, 2);
      expect(cubit.state.fullNameError, 'Escribe tu nombre completo');
      expect(cubit.state.birthDateError, 'Selecciona tu fecha de nacimiento');
    });

    test('menor de 18 no avanza y explica por qué', () {
      cubit.nextFromProfile(fullName: 'Ana', birthDate: DateTime(2008, 10, 5));
      expect(cubit.state.step, 2);
      expect(
        cubit.state.birthDateError,
        'Debes ser mayor de 18 años para crear una cuenta',
      );
    });

    test('el día exacto de los 18 avanza', () {
      cubit.nextFromProfile(fullName: 'Ana', birthDate: DateTime(2008, 10, 4));
      expect(cubit.state.step, 3);
      expect(cubit.state.birthDateError, isNull);
    });

    test('fecha futura es inválida', () {
      cubit.nextFromProfile(fullName: 'Ana', birthDate: DateTime(2027, 1, 1));
      expect(cubit.state.step, 2);
      expect(cubit.state.birthDateError, 'Selecciona una fecha válida');
    });

    test('adulto avanza con el nombre limpio y la fecha sin hora', () {
      cubit.nextFromProfile(
        fullName: '  Ana Pérez ',
        birthDate: DateTime(2000, 5, 7, 13, 45),
      );
      expect(cubit.state.step, 3);
      expect(cubit.state.fullName, 'Ana Pérez');
      expect(cubit.state.birthDate, DateTime(2000, 5, 7));
    });
  });

  group('RegisterCubit: volver atrás', () {
    test('conserva lo ingresado en cada paso', () {
      toStep3();
      cubit.selectUsage('Ahorrar');

      cubit.back();
      expect(cubit.state.step, 2);
      expect(cubit.state.fullName, 'Ana Pérez');
      expect(cubit.state.birthDate, DateTime(2000, 5, 7));
      expect(cubit.state.accountUsage, 'Ahorrar');

      cubit.back();
      expect(cubit.state.step, 1);
      expect(cubit.state.email, 'a@b.com');
    });

    test('en el paso 1 no hace nada', () {
      cubit.back();
      expect(cubit.state.step, 1);
    });

    test('la contraseña de antes de volver se usa al terminar', () async {
      toStep3();
      cubit.back();
      cubit.back();
      expect(cubit.state.step, 1);
      // Se avanza otra vez sin reescribir la contraseña en el Cubit.
      cubit.nextFromCredentials(email: 'a@b.com', password: 'secret123');
      cubit.nextFromProfile(fullName: 'Ana', birthDate: DateTime(2000, 5, 7));
      cubit.selectUsage('Ahorrar');
      await cubit.submit();
      expect(repo.received?.password, 'secret123');
    });
  });

  group('RegisterCubit: paso 3 (crear la cuenta)', () {
    test('SignUp recibe los tres campos con el formato correcto', () async {
      toStep3(birth: DateTime(2000, 5, 7));
      cubit.selectUsage('Recibir remesas');
      await cubit.submit();

      final params = repo.received!;
      expect(params.email, 'a@b.com');
      expect(params.fullName, 'Ana Pérez');
      expect(params.accountUsage, 'Recibir remesas');
      expect(signUpMetadata(params), {
        'full_name': 'Ana Pérez',
        'birth_date': '2000-05-07',
        'account_usage': 'Recibir remesas',
      });
    });

    test('sin elegir uso -> error y no llama a SignUp', () async {
      toStep3();
      await cubit.submit();
      expect(cubit.state.usageError, 'Elige para qué usarás tu cuenta');
      expect(repo.signUpCalls, 0);
    });

    test('con sesión inmediata -> registered', () async {
      toStep3();
      cubit.selectUsage('Ahorrar');
      await cubit.submit();
      expect(cubit.state.status, RegisterStatus.registered);
    });

    test('sin sesión inmediata -> confirmEmail', () async {
      repo.user = null;
      toStep3();
      cubit.selectUsage('Ahorrar');
      await cubit.submit();
      expect(cubit.state.status, RegisterStatus.confirmEmail);
    });

    test('error de auth -> mensaje y conserva los datos', () async {
      repo.signUpFailure = const Failure('técnico', 'auth');
      toStep3();
      cubit.selectUsage('Ahorrar');
      await cubit.submit();
      expect(cubit.state.status, RegisterStatus.error);
      expect(cubit.state.message, 'Correo o contraseña incorrectos.');
      expect(cubit.state.step, 3);
      expect(cubit.state.accountUsage, 'Ahorrar');
      expect(cubit.state.fullName, 'Ana Pérez');
    });

    test('cada código de Failure produce su mensaje', () async {
      const expected = {
        'network': 'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
        'rls_denied': 'No tienes permiso para ver esta información.',
        'unknown': 'Algo salió mal. Inténtalo de nuevo.',
      };
      toStep3();
      cubit.selectUsage('Ahorrar');
      for (final entry in expected.entries) {
        repo.signUpFailure = Failure('técnico', entry.key);
        await cubit.submit();
        expect(cubit.state.message, entry.value, reason: entry.key);
      }
    });

    test('ignora un segundo envío mientras carga', () async {
      repo.gate = Completer<void>();
      toStep3();
      cubit.selectUsage('Ahorrar');
      final first = cubit.submit();
      await Future<void>.delayed(Duration.zero);
      await cubit.submit();
      expect(repo.signUpCalls, 1);
      repo.gate!.complete();
      await first;
      expect(cubit.state.status, RegisterStatus.registered);
    });
  });

  group('RegisterView', () {
    late int registered;
    late int goToLogin;

    Widget view({ThemeData? theme, double textScale = 1}) => wrap(
      theme: theme,
      textScale: textScale,
      RegisterView(
        cubit: cubit,
        onRegistered: () => registered++,
        onGoToLogin: () => goToLogin++,
      ),
    );

    setUp(() {
      registered = 0;
      goToLogin = 0;
    });

    Finder field(int i) => find.byType(TextField).at(i);

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.tap(find.text(text));
      await tester.pump();
    }

    Future<void> toStep2(WidgetTester tester) async {
      await tester.enterText(field(0), 'a@b.com');
      await tester.enterText(field(1), 'secret123');
      await tapText(tester, 'Continuar');
    }

    Future<void> pickDate(WidgetTester tester) async {
      await tester.tap(find.textContaining('Fecha de nacimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    Future<void> toStep3Ui(WidgetTester tester) async {
      await toStep2(tester);
      await tester.enterText(field(0), 'Ana Pérez');
      await pickDate(tester);
      await tapText(tester, 'Continuar');
    }

    testWidgets('paso 1: indicador, campos ocultos y autofill', (tester) async {
      await tester.pumpWidget(view());
      expect(find.text('Paso 1 de 3'), findsOneWidget);
      expect(find.text('Crea tu cuenta'), findsOneWidget);
      expect(tester.widget<TextField>(field(1)).obscureText, isTrue);
      expect(tester.widget<TextField>(field(1)).autofillHints, [
        AutofillHints.newPassword,
      ]);
      expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
    });

    testWidgets('paso 1: validaciones', (tester) async {
      await tester.pumpWidget(view());
      await tapText(tester, 'Continuar');
      expect(find.text('Escribe tu correo'), findsOneWidget);
      expect(find.text('Escribe tu contraseña'), findsOneWidget);

      await tester.enterText(field(0), 'a@b.com');
      await tester.enterText(field(1), '1234567');
      await tapText(tester, 'Continuar');
      expect(find.text('La contraseña debe tener al menos 8 caracteres'),
          findsOneWidget);
      expect(find.text('Paso 1 de 3'), findsOneWidget);
    });

    testWidgets('"Ya tengo una cuenta" llama a onGoToLogin', (tester) async {
      await tester.pumpWidget(view());
      await tapText(tester, 'Ya tengo una cuenta');
      expect(goToLogin, 1);
    });

    testWidgets('paso 2: sin datos muestra los errores', (tester) async {
      await tester.pumpWidget(view());
      await toStep2(tester);
      expect(find.text('Paso 2 de 3'), findsOneWidget);
      await tapText(tester, 'Continuar');
      expect(find.text('Escribe tu nombre completo'), findsOneWidget);
      expect(find.text('Selecciona tu fecha de nacimiento'), findsOneWidget);
      expect(find.text('Paso 2 de 3'), findsOneWidget);
    });

    testWidgets('el selector devuelve exactamente 18 años y se acepta', (
      tester,
    ) async {
      await tester.pumpWidget(view());
      await toStep2(tester);
      await tester.enterText(field(0), 'Ana Pérez');
      await pickDate(tester);
      expect(find.textContaining('4 oct 2008'), findsOneWidget);
      await tapText(tester, 'Continuar');
      expect(find.text('Paso 3 de 3'), findsOneWidget);
    });

    testWidgets('"Atrás" vuelve conservando lo ingresado', (tester) async {
      await tester.pumpWidget(view());
      await toStep2(tester);
      await tester.enterText(field(0), 'Ana Pérez');
      await tapText(tester, 'Atrás');
      expect(find.text('Paso 1 de 3'), findsOneWidget);
      expect(tester.widget<TextField>(field(0)).controller?.text, 'a@b.com');
      expect(tester.widget<TextField>(field(1)).controller?.text, 'secret123');

      await tapText(tester, 'Continuar');
      expect(tester.widget<TextField>(field(0)).controller?.text, 'Ana Pérez');
    });

    testWidgets('paso 3: cuatro opciones y selección con icono', (tester) async {
      await tester.pumpWidget(view());
      await toStep3Ui(tester);
      expect(find.text('Paso 3 de 3'), findsOneWidget);
      for (final option in OnboardingStrings.usageOptions) {
        expect(find.text(option), findsOneWidget);
      }
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
      await tapText(tester, 'Ahorrar');
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
    });

    testWidgets('paso 3: crear sin elegir uso muestra el error', (tester) async {
      await tester.pumpWidget(view());
      await toStep3Ui(tester);
      await tapText(tester, 'Crear cuenta');
      expect(find.text('Elige para qué usarás tu cuenta'), findsOneWidget);
      expect(repo.signUpCalls, 0);
    });

    testWidgets('flujo completo: llama a SignUp y a onRegistered', (
      tester,
    ) async {
      await tester.pumpWidget(view());
      await toStep3Ui(tester);
      await tapText(tester, 'Recibir remesas');
      await tapText(tester, 'Crear cuenta');
      await tester.pump();

      expect(registered, 1);
      final params = repo.received!;
      expect(params.email, 'a@b.com');
      expect(params.password, 'secret123');
      expect(params.fullName, 'Ana Pérez');
      expect(signUpMetadata(params)['birth_date'], '2008-10-04');
      expect(params.accountUsage, 'Recibir remesas');
    });

    testWidgets('error de auth: muestra el mensaje y conserva el paso', (
      tester,
    ) async {
      repo.signUpFailure = const Failure('técnico', 'auth');
      await tester.pumpWidget(view());
      await toStep3Ui(tester);
      await tapText(tester, 'Ahorrar');
      await tapText(tester, 'Crear cuenta');
      await tester.pump();

      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(find.text('técnico'), findsNothing);
      expect(find.text('Paso 3 de 3'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(registered, 0);
    });

    testWidgets('sin sesión inmediata: pide revisar el correo', (tester) async {
      repo.user = null;
      await tester.pumpWidget(view());
      await toStep3Ui(tester);
      await tapText(tester, 'Ahorrar');
      await tapText(tester, 'Crear cuenta');
      await tester.pump();

      expect(find.text('Revisa tu correo para confirmar tu cuenta'),
          findsOneWidget);
      expect(registered, 0);
      await tapText(tester, 'Ir a iniciar sesión');
      expect(goToLogin, 1);
    });

    testWidgets('en carga: botón deshabilitado con indicador', (tester) async {
      repo.gate = Completer<void>();
      await tester.pumpWidget(view());
      await toStep3Ui(tester);
      await tapText(tester, 'Ahorrar');
      await tapText(tester, 'Crear cuenta');

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      repo.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(registered, 1);
    });

    for (final theme in {
      'claro': AppTheme.light(),
      'oscuro': AppTheme.dark(),
    }.entries) {
      testWidgets('accesibilidad en los 3 pasos, tema ${theme.key}', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(view(theme: theme.value));

        Future<void> check() async {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }

        await check();
        await toStep2(tester);
        await check();
        await tester.enterText(field(0), 'Ana Pérez');
        await pickDate(tester);
        await tapText(tester, 'Continuar');
        await check();
        handle.dispose();
      });
    }

    testWidgets('texto al 200 % sin desbordes en los 3 pasos', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(view(textScale: 2.0));
      expect(tester.takeException(), isNull);

      cubit.nextFromCredentials(email: 'a@b.com', password: 'secret123');
      await tester.pump();
      expect(tester.takeException(), isNull);

      cubit.nextFromProfile(fullName: 'Ana Pérez', birthDate: DateTime(2000, 5, 7));
      await tester.pump();
      expect(tester.takeException(), isNull);

      cubit.selectUsage('Gastos del día a día');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('RegisterPage', () {
    final getIt = GetIt.instance;
    tearDown(() async => getIt.reset());

    testWidgets('crea el Cubit desde GetIt', (tester) async {
      getIt.registerFactory<RegisterCubit>(
        () => RegisterCubit(
          signUp: SignUp(repo),
          getCurrentUser: GetCurrentUser(repo),
          clock: () => today,
        ),
      );
      var goToLogin = 0;
      await tester.pumpWidget(
        wrap(RegisterPage(onRegistered: () {}, onGoToLogin: () => goToLogin++)),
      );
      expect(find.text('Paso 1 de 3'), findsOneWidget);
      await tester.tap(find.text('Ya tengo una cuenta'));
      expect(goToLogin, 1);
    });
  });
}
