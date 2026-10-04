import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';

import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../domain/sign_up_params.dart';
import '../domain/user_profile.dart';
import 'auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  const AuthRepositoryImpl(this._remote);

  @override
  Future<Failure?> signUp(SignUpParams params) async {
    try {
      await _remote.signUp(params);
      return null;
    } catch (e) {
      return mapToFailure(e);
    }
  }

  @override
  Future<Failure?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _remote.signIn(email: email, password: password);
      return null;
    } catch (e) {
      return mapToFailure(e);
    }
  }

  @override
  Future<Failure?> signOut() async {
    try {
      await _remote.signOut();
      return null;
    } catch (e) {
      return mapToFailure(e);
    }
  }

  @override
  AuthUser? getCurrentUser() => _remote.currentUser;

  @override
  Future<({String? segment, Failure? failure})> getProfileSegment() async {
    try {
      final segment = await _remote.fetchSegment();
      if (segment == null) {
        return (
          segment: null,
          failure: const Failure('Perfil sin segmento', 'unknown'),
        );
      }
      return (segment: segment, failure: null);
    } catch (e) {
      return (segment: null, failure: mapToFailure(e));
    }
  }

  @override
  Future<({UserProfile? profile, Failure? failure})> getUserProfile() async {
    try {
      final row = await _remote.fetchProfile();
      if (row == null) {
        return (
          profile: null,
          failure: const Failure('Perfil no encontrado', 'unknown'),
        );
      }
      final profile = UserProfile(
        fullName: row['full_name'] as String,
        segment: row['segment'] as String,
      );
      return (profile: profile, failure: null);
    } catch (e) {
      return (profile: null, failure: mapToFailure(e));
    }
  }
}
