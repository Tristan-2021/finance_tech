import 'package:core_errors/core_errors.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_onboarding/src/domain/sign_up_params.dart';
import 'package:feature_onboarding/src/presentation/login/login_cubit.dart';
import 'package:feature_onboarding/src/presentation/register/register_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTelemetry implements Telemetry {
  final events = <({String name, Map<String, Object?> params})>[];

  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) =>
      events.add((name: name, params: params));

  @override
  void recordError(Object error, StackTrace stack, {bool fatal = false, String? reason}) {}

  @override
  void setSegment(String? segment) {}

  @override
  Future<T> trace<T>(String name, Future<T> Function() action) => action();
}

class _FakeSignUp implements SignUp {
  Failure? failure;

  @override
  Future<Failure?> call(SignUpParams params) async => failure;
}

class _FakeSignIn implements SignIn {
  Failure? failure;

  @override
  Future<Failure?> call({required String email, required String password}) async =>
      failure;
}

class _FakeGetCurrentUser implements GetCurrentUser {
  @override
  AuthUser? call() => const AuthUser(id: 'u1', email: 'ana@correo.com');
}

/// El mensaje de un error puede contener datos del usuario: nunca debe salir.
const _leakyFailure = Failure('ana@correo.com secret123', 'auth');

void main() {
  late _FakeTelemetry telemetry;

  setUp(() => telemetry = _FakeTelemetry());

  void expectPrivate() {
    for (final event in telemetry.events) {
      expect(
        TelemetrySanitizer.allowedKeys,
        containsAll(event.params.keys),
        reason: '${event.name} usa una clave no permitida',
      );
      final values = event.params.values.join(' ');
      for (final secret in ['ana@correo.com', 'secret123', 'Ana', '@']) {
        expect(values, isNot(contains(secret)), reason: event.name);
      }
    }
  }

  group('RegisterCubit', () {
    late _FakeSignUp signUp;
    late RegisterCubit cubit;

    setUp(() {
      signUp = _FakeSignUp();
      cubit = RegisterCubit(
        signUp: signUp,
        getCurrentUser: _FakeGetCurrentUser(),
        clock: () => DateTime(2026, 10, 5),
        telemetry: telemetry,
      );
    });
    tearDown(() => cubit.close());

    void fillAllSteps() {
      cubit.nextFromCredentials(email: 'ana@correo.com', password: 'secret123');
      cubit.nextFromProfile(fullName: 'Ana Pérez', birthDate: DateTime(1990, 1, 1));
      cubit.selectUsage('Ahorrar');
    }

    test('emite un register_step_completed por cada paso', () async {
      fillAllSteps();
      await cubit.submit();

      expect(telemetry.events.map((e) => e.name), everyElement('register_step_completed'));
      expect(telemetry.events.map((e) => e.params['step']), [1, 2, 3]);
      expectPrivate();
    });

    test('datos inválidos no avanzan de paso ni emiten nada', () {
      cubit.nextFromCredentials(email: 'no-es-correo', password: '123');
      cubit.nextFromProfile(fullName: '', birthDate: null);
      expect(telemetry.events, isEmpty);
    });

    test('si el registro falla emite register_failed con el código, no el mensaje', () async {
      signUp.failure = _leakyFailure;
      fillAllSteps();
      await cubit.submit();

      expect(telemetry.events.map((e) => e.name), [
        'register_step_completed',
        'register_step_completed',
        'register_failed',
      ]);
      expect(telemetry.events.last.params, {'step': 3, 'code': 'auth'});
      expectPrivate();
    });
  });

  group('LoginCubit', () {
    late _FakeSignIn signIn;
    late LoginCubit cubit;

    setUp(() {
      signIn = _FakeSignIn();
      cubit = LoginCubit(signIn, telemetry: telemetry);
    });
    tearDown(() => cubit.close());

    test('un login fallido emite login_failed solo con el código', () async {
      signIn.failure = _leakyFailure;
      await cubit.submit(email: 'ana@correo.com', password: 'secret123');

      expect(telemetry.events.single.name, 'login_failed');
      expect(telemetry.events.single.params, {'code': 'auth'});
      expectPrivate();
    });

    test('un login correcto o con campos inválidos no emite login_failed', () async {
      await cubit.submit(email: 'ana@correo.com', password: 'secret123');
      await cubit.submit(email: '', password: '');
      expect(telemetry.events, isEmpty);
    });
  });
}
