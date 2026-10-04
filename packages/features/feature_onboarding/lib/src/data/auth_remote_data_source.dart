import '../domain/sign_up_params.dart';

/// Lanza las excepciones de Supabase; el repositorio las mapea a `Failure`.
abstract class AuthRemoteDataSource {
  Future<void> signUp(SignUpParams params);

  Future<void> signIn({required String email, required String password});

  /// `null` si el perfil no existe o aún no tiene segmento.
  Future<String?> fetchSegment();
}
