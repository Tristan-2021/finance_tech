import 'package:core_errors/core_errors.dart';

import 'auth_repository.dart';

class SignOut {
  final AuthRepository _repository;
  const SignOut(this._repository);

  Future<Failure?> call() => _repository.signOut();
}
