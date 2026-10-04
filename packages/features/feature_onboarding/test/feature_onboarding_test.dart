import 'package:core_errors/core_errors.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  SignUpParams? signUpReceived;
  ({String email, String password})? signInReceived;
  Failure? failure;
  String? segment;

  @override
  Future<Failure?> signUp(SignUpParams params) async {
    signUpReceived = params;
    return failure;
  }

  @override
  Future<Failure?> signIn({
    required String email,
    required String password,
  }) async {
    signInReceived = (email: email, password: password);
    return failure;
  }

  @override
  Future<({String? segment, Failure? failure})> getProfileSegment() async =>
      (segment: failure == null ? segment : null, failure: failure);

  @override
  Future<Failure?> signOut() async => failure;

  @override
  AuthUser? getCurrentUser() => null;
}

void main() {
  late FakeAuthRepository repo;
  setUp(() => repo = FakeAuthRepository());

  group('SignUp', () {
    final params = SignUpParams(
      email: 'a@b.com',
      password: 'secret123',
      fullName: 'Ana Pérez',
      birthDate: DateTime(2000, 5, 17),
      accountUsage: 'personal',
    );

    test('entrega al repositorio nombre, fecha y uso de cuenta', () async {
      final failure = await SignUp(repo)(params);
      expect(failure, isNull);
      expect(repo.signUpReceived?.fullName, 'Ana Pérez');
      expect(repo.signUpReceived?.birthDate, DateTime(2000, 5, 17));
      expect(repo.signUpReceived?.accountUsage, 'personal');
    });

    test('propaga el Failure de auth', () async {
      repo.failure = const Failure('ya existe', 'auth');
      final failure = await SignUp(repo)(params);
      expect(failure?.code, 'auth');
      expect(failure?.message, 'ya existe');
    });
  });

  group('SignIn', () {
    test('entrega credenciales al repositorio', () async {
      final failure = await SignIn(repo)(email: 'a@b.com', password: 'pw');
      expect(failure, isNull);
      expect(repo.signInReceived, (email: 'a@b.com', password: 'pw'));
    });

    test('propaga el Failure de auth', () async {
      repo.failure = const Failure('credenciales', 'auth');
      final failure = await SignIn(repo)(email: 'a@b.com', password: 'x');
      expect(failure?.code, 'auth');
    });
  });

  group('GetProfileSegment', () {
    test('devuelve el segmento leído', () async {
      repo.segment = 'joven';
      final r = await GetProfileSegment(repo)();
      expect(r.segment, 'joven');
      expect(r.failure, isNull);
    });

    test('propaga el Failure', () async {
      repo.failure = const Failure('sin sesión', 'rls_denied');
      final r = await GetProfileSegment(repo)();
      expect(r.segment, isNull);
      expect(r.failure?.code, 'rls_denied');
    });
  });
}
