import '../domain/auth_user.dart';
import '../domain/sign_up_params.dart';

/// Lanza las excepciones de Supabase; el repositorio las mapea a `Failure`.
abstract class AuthRemoteDataSource {
  Future<void> signUp(SignUpParams params);

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Usuario de la sesión actual (lectura local), o `null` si no hay sesión.
  AuthUser? get currentUser;

  /// `null` si el perfil no existe o aún no tiene segmento.
  Future<String?> fetchSegment();
}
