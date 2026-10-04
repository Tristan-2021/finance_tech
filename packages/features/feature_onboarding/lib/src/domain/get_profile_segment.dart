import 'package:core_errors/core_errors.dart';

import 'auth_repository.dart';

class GetProfileSegment {
  final AuthRepository _repository;
  const GetProfileSegment(this._repository);

  Future<({String? segment, Failure? failure})> call() =>
      _repository.getProfileSegment();
}
