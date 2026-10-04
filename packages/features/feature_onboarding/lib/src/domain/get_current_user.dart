import 'auth_repository.dart';
import 'auth_user.dart';

class GetCurrentUser {
  final AuthRepository _repository;
  const GetCurrentUser(this._repository);

  /// `null` si no hay sesión.
  AuthUser? call() => _repository.getCurrentUser();
}
