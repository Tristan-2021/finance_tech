import 'package:core_errors/core_errors.dart';

import 'auth_repository.dart';

class SignIn {
  final AuthRepository _repository;
  const SignIn(this._repository);

  Future<Failure?> call({required String email, required String password}) =>
      _repository.signIn(email: email, password: password);
}
