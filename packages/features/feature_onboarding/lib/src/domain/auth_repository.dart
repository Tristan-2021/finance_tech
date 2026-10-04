import 'package:core_errors/core_errors.dart';

import 'sign_up_params.dart';

abstract class AuthRepository {
  /// Devuelve `null` si el registro fue exitoso.
  Future<Failure?> signUp(SignUpParams params);

  /// Devuelve `null` si el inicio de sesión fue exitoso.
  Future<Failure?> signIn({required String email, required String password});

  /// El segmento lo calcula el backend; la app solo lo lee.
  Future<({String? segment, Failure? failure})> getProfileSegment();
}
