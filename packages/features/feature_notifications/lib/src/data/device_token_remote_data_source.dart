import 'package:core_network/core_network.dart';

abstract interface class DeviceTokenRemoteDataSource {
  Future<void> register(String token);
  Future<void> unregister(String token);
}

class SupabaseDeviceTokenRemoteDataSource
    implements DeviceTokenRemoteDataSource {
  final SupabaseClient _client;
  final String _platform;

  SupabaseDeviceTokenRemoteDataSource(this._client, this._platform);

  @override
  Future<void> register(String token) async {
    await _client.rpc(
      'register_device_token',
      params: {'p_token': token, 'p_platform': _platform},
    );
  }

  /// RLS permite al usuario borrar solo sus propios tokens.
  @override
  Future<void> unregister(String token) async {
    await _client.from('device_tokens').delete().eq('token', token);
  }
}
