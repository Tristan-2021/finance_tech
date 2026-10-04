import 'dart:async';
import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRemote implements AuthRemoteDataSource {
  Object? error;
  String? segment;
  SignUpParams? signUpReceived;

  @override
  Future<void> signUp(SignUpParams params) async {
    signUpReceived = params;
    if (error != null) throw error!;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (error != null) throw error!;
  }

  @override
  Future<String?> fetchSegment() async {
    if (error != null) throw error!;
    return segment;
  }

  @override
  Future<void> signOut() async {
    if (error != null) throw error!;
  }

  @override
  AuthUser? get currentUser => null;

  @override
  Future<Map<String, dynamic>?> fetchProfile() async => null;
}

void main() {
  final params = SignUpParams(
    email: 'a@b.com',
    password: 'secret123',
    fullName: 'Ana Pérez',
    birthDate: DateTime(2000, 5, 7),
    accountUsage: 'personal',
  );

  group('signUpMetadata', () {
    test('envía full_name, birth_date (YYYY-MM-DD) y account_usage', () {
      expect(signUpMetadata(params), {
        'full_name': 'Ana Pérez',
        'birth_date': '2000-05-07',
        'account_usage': 'personal',
      });
    });
  });

  group('AuthRepositoryImpl', () {
    late FakeRemote remote;
    late AuthRepositoryImpl repo;
    setUp(() {
      remote = FakeRemote();
      repo = AuthRepositoryImpl(remote);
    });

    test('signUp exitoso -> null y pasa los params', () async {
      expect(await repo.signUp(params), isNull);
      expect(remote.signUpReceived, same(params));
    });

    test('signUp AuthException -> auth', () async {
      remote.error = const AuthException('ya registrado');
      final f = await repo.signUp(params);
      expect(f?.code, 'auth');
      expect(f?.message, 'ya registrado');
    });

    test('signIn AuthException -> auth', () async {
      remote.error = const AuthException('credenciales inválidas');
      final f = await repo.signIn(email: 'a@b.com', password: 'x');
      expect(f?.code, 'auth');
    });

    test('signIn SocketException -> network', () async {
      remote.error = const SocketException('sin red');
      final f = await repo.signIn(email: 'a@b.com', password: 'x');
      expect(f?.code, 'network');
    });

    test('signIn exitoso -> null', () async {
      expect(await repo.signIn(email: 'a@b.com', password: 'x'), isNull);
    });

    test('getProfileSegment devuelve el segmento', () async {
      remote.segment = 'adulto';
      final r = await repo.getProfileSegment();
      expect(r.segment, 'adulto');
      expect(r.failure, isNull);
    });

    test('getProfileSegment sin fila -> unknown', () async {
      final r = await repo.getProfileSegment();
      expect(r.segment, isNull);
      expect(r.failure?.code, 'unknown');
    });

    test('getProfileSegment 42501 -> rls_denied', () async {
      remote.error = PostgrestException(message: 'denied', code: '42501');
      final r = await repo.getProfileSegment();
      expect(r.segment, isNull);
      expect(r.failure?.code, 'rls_denied');
    });

    test('getProfileSegment TimeoutException -> network', () async {
      remote.error = TimeoutException('lento');
      final r = await repo.getProfileSegment();
      expect(r.failure?.code, 'network');
    });
  });
}
