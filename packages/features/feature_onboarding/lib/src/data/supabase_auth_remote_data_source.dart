import 'package:core_network/core_network.dart';

import '../domain/auth_user.dart';
import '../domain/sign_up_params.dart';
import 'auth_remote_data_source.dart';
import 'sign_up_metadata.dart';

class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  final SupabaseClient _client;
  const SupabaseAuthRemoteDataSource(this._client);

  @override
  Future<void> signUp(SignUpParams params) async {
    await _client.auth.signUp(
      email: params.email,
      password: params.password,
      data: signUpMetadata(params),
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return AuthUser(id: user.id, email: user.email ?? '');
  }

  @override
  Future<String?> fetchSegment() async {
    // RLS limita `profiles` a la fila del usuario autenticado.
    final row = await _client.from('profiles').select('segment').maybeSingle();
    return row?['segment'] as String?;
  }

  @override
  Future<Map<String, dynamic>?> fetchProfile() {
    // RLS limita `profiles` a la fila del usuario autenticado (sin `user_id`).
    return _client.from('profiles').select('full_name, segment').maybeSingle();
  }
}
