import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';

import '../domain/device_token_repository.dart';
import 'device_token_remote_data_source.dart';

class DeviceTokenRepositoryImpl implements DeviceTokenRepository {
  final DeviceTokenRemoteDataSource _remote;
  const DeviceTokenRepositoryImpl(this._remote);

  @override
  Future<Failure?> register(String token) =>
      _run(() => _remote.register(token));

  @override
  Future<Failure?> unregister(String token) =>
      _run(() => _remote.unregister(token));

  Future<Failure?> _run(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (e) {
      return mapToFailure(e);
    }
  }
}
