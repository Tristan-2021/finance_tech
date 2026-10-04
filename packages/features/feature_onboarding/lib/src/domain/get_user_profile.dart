import 'package:core_errors/core_errors.dart';

import 'auth_repository.dart';
import 'user_profile.dart';

class GetUserProfile {
  final AuthRepository _repository;
  const GetUserProfile(this._repository);

  Future<({UserProfile? profile, Failure? failure})> call() =>
      _repository.getUserProfile();
}
