import 'dart:io';

import 'package:feature_notifications/src/data/device_token_remote_data_source.dart';
import 'package:feature_notifications/src/data/device_token_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRemote implements DeviceTokenRemoteDataSource {
  Object? error;
  final calls = <String>[];

  @override
  Future<void> register(String token) async {
    calls.add('register:$token');
    if (error != null) throw error!;
  }

  @override
  Future<void> unregister(String token) async {
    calls.add('unregister:$token');
    if (error != null) throw error!;
  }
}

void main() {
  late _FakeRemote remote;
  late DeviceTokenRepositoryImpl repository;

  setUp(() {
    remote = _FakeRemote();
    repository = DeviceTokenRepositoryImpl(remote);
  });

  test('éxito devuelve null', () async {
    expect(await repository.register('t'), isNull);
    expect(await repository.unregister('t'), isNull);
    expect(remote.calls, ['register:t', 'unregister:t']);
  });

  test('un error de red se mapea a Failure con código network', () async {
    remote.error = const SocketException('sin red');
    expect((await repository.register('t'))?.code, 'network');
    expect((await repository.unregister('t'))?.code, 'network');
  });

  test('un error desconocido se mapea a unknown', () async {
    remote.error = Exception('boom');
    expect((await repository.register('t'))?.code, 'unknown');
  });
}
