import 'dart:async';
import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRemote implements AuthRemoteDataSource {
  Object? error;
  AuthUser? user;
  int signOutCalls = 0;

  @override
  AuthUser? get currentUser => user;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (error != null) throw error!;
  }

  @override
  Future<void> signUp(SignUpParams params) async {}

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<String?> fetchSegment() async => null;
}

void main() {
  late FakeRemote remote;
  late AuthRepositoryImpl repo;
  setUp(() {
    remote = FakeRemote();
    repo = AuthRepositoryImpl(remote);
  });

  group('GetCurrentUser', () {
    test('usuario presente', () {
      remote.user = const AuthUser(id: 'u1', email: 'a@b.com');
      final user = GetCurrentUser(repo)();
      expect(user, isNotNull);
      expect(user?.id, 'u1');
      expect(user?.email, 'a@b.com');
    });

    test('usuario ausente -> null', () {
      expect(GetCurrentUser(repo)(), isNull);
    });
  });

  group('SignOut', () {
    test('exitoso -> null y llama al data source', () async {
      expect(await SignOut(repo)(), isNull);
      expect(remote.signOutCalls, 1);
    });

    test('SocketException -> network', () async {
      remote.error = const SocketException('sin red');
      final failure = await SignOut(repo)();
      expect(failure?.code, 'network');
    });

    test('TimeoutException -> network', () async {
      remote.error = TimeoutException('lento');
      expect((await SignOut(repo)())?.code, 'network');
    });

    test('AuthException -> auth', () async {
      remote.error = const AuthException('sesión inválida');
      final failure = await SignOut(repo)();
      expect(failure?.code, 'auth');
      expect(failure?.message, 'sesión inválida');
    });
  });

  group('AuthUser', () {
    test('igualdad por valor', () {
      const a = AuthUser(id: 'u1', email: 'a@b.com');
      const b = AuthUser(id: 'u1', email: 'a@b.com');
      const c = AuthUser(id: 'u2', email: 'a@b.com');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
