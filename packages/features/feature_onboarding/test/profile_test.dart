import 'dart:async';
import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:feature_onboarding/src/data/auth_remote_data_source.dart';
import 'package:feature_onboarding/src/data/auth_repository_impl.dart';
import 'package:feature_onboarding/src/domain/auth_user.dart';
import 'package:feature_onboarding/src/domain/get_profile_segment.dart';
import 'package:feature_onboarding/src/domain/get_user_profile.dart';
import 'package:feature_onboarding/src/domain/sign_up_params.dart';
import 'package:feature_onboarding/src/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRemote implements AuthRemoteDataSource {
  Object? error;
  Map<String, dynamic>? row;
  String? segment;
  int profileCalls = 0;

  @override
  Future<Map<String, dynamic>?> fetchProfile() async {
    profileCalls++;
    if (error != null) throw error!;
    return row;
  }

  @override
  Future<String?> fetchSegment() async {
    if (error != null) throw error!;
    return segment;
  }

  @override
  AuthUser? get currentUser => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp(SignUpParams params) async {}

  @override
  Future<void> signIn({required String email, required String password}) async {}
}

void main() {
  late FakeRemote remote;
  late AuthRepositoryImpl repo;
  setUp(() {
    remote = FakeRemote();
    repo = AuthRepositoryImpl(remote);
  });

  group('GetUserProfile', () {
    test('perfil completo', () async {
      remote.row = {'full_name': 'Ana Pérez', 'segment': 'joven'};
      final r = await GetUserProfile(repo)();
      expect(r.failure, isNull);
      expect(r.profile?.fullName, 'Ana Pérez');
      expect(r.profile?.segment, 'joven');
      expect(remote.profileCalls, 1);
    });

    test('perfil sin fila -> Failure', () async {
      final r = await GetUserProfile(repo)();
      expect(r.profile, isNull);
      expect(r.failure?.code, 'unknown');
      expect(r.failure?.message, 'Perfil no encontrado');
    });

    test('42501 -> rls_denied', () async {
      remote.error = PostgrestException(message: 'denied', code: '42501');
      final r = await GetUserProfile(repo)();
      expect(r.profile, isNull);
      expect(r.failure?.code, 'rls_denied');
    });

    test('SocketException -> network', () async {
      remote.error = const SocketException('sin red');
      final r = await GetUserProfile(repo)();
      expect(r.profile, isNull);
      expect(r.failure?.code, 'network');
    });

    test('TimeoutException -> network', () async {
      remote.error = TimeoutException('lento');
      final r = await GetUserProfile(repo)();
      expect(r.failure?.code, 'network');
    });

    test('fila incompleta o con tipos inesperados -> Failure', () async {
      for (final bad in <Map<String, dynamic>>[
        {'full_name': 'Ana'},
        {'segment': 'joven'},
        {'full_name': null, 'segment': 'joven'},
        {'full_name': 'Ana', 'segment': 7},
      ]) {
        remote.row = bad;
        final r = await GetUserProfile(repo)();
        expect(r.profile, isNull, reason: '$bad');
        expect(r.failure?.code, 'unknown', reason: '$bad');
      }
    });
  });

  group('GetProfileSegment sigue funcionando', () {
    test('devuelve el segmento', () async {
      remote.segment = 'adulto';
      final r = await GetProfileSegment(repo)();
      expect(r.segment, 'adulto');
      expect(r.failure, isNull);
    });
  });

  group('UserProfile', () {
    test('igualdad por valor', () {
      const a = UserProfile(fullName: 'Ana', segment: 'joven');
      const b = UserProfile(fullName: 'Ana', segment: 'joven');
      const c = UserProfile(fullName: 'Ana', segment: 'adulto');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
