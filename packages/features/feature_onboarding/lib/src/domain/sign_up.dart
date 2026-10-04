import 'package:core_errors/core_errors.dart';

import 'auth_repository.dart';
import 'sign_up_params.dart';

class SignUp {
  final AuthRepository _repository;
  const SignUp(this._repository);

  Future<Failure?> call(SignUpParams params) => _repository.signUp(params);
}
