import 'package:core_errors/core_errors.dart';

abstract interface class DeviceTokenRepository {
  /// Asocia [token] al usuario autenticado. `null` si salió bien.
  Future<Failure?> register(String token);

  /// Borra [token] del backend. `null` si salió bien.
  Future<Failure?> unregister(String token);
}
