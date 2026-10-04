import 'package:core_errors/core_errors.dart';

import 'auth_user.dart';
import 'sign_up_params.dart';
import 'user_profile.dart';

abstract class AuthRepository {
  /// Devuelve `null` si el registro fue exitoso.
  Future<Failure?> signUp(SignUpParams params);

  /// Devuelve `null` si el inicio de sesión fue exitoso.
  Future<Failure?> signIn({required String email, required String password});

  /// Cierra la sesión. Devuelve `null` si fue exitoso.
  Future<Failure?> signOut();

  /// Usuario de la sesión actual, o `null` si no hay sesión. Es una lectura
  /// local (la sesión la restaura Supabase al arrancar): no usa la red.
  AuthUser? getCurrentUser();

  /// El segmento lo calcula el backend; la app solo lo lee.
  Future<({String? segment, Failure? failure})> getProfileSegment();

  /// Nombre y segmento del usuario autenticado.
  Future<({UserProfile? profile, Failure? failure})> getUserProfile();
}
