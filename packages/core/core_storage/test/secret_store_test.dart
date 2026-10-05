import 'dart:convert';

import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSecretStore implements SecretStore {
  final values = <String, String>{};
  int writes = 0;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    values[key] = value;
  }
}

void main() {
  late FakeSecretStore secrets;
  late EncryptionKeyProvider provider;
  setUp(() {
    secrets = FakeSecretStore();
    provider = EncryptionKeyProvider(secrets);
  });

  test('la primera vez crea una clave AES-256 y la guarda una sola vez', () async {
    final key = await provider.loadOrCreate();

    expect(key.length, 32);
    expect(secrets.writes, 1);
    expect(
      base64Decode(secrets.values[EncryptionKeyProvider.keyName]!),
      key,
    );
  });

  test('las siguientes veces reutiliza la misma clave sin volver a escribir', () async {
    final first = await provider.loadOrCreate();
    final second = await provider.loadOrCreate();
    final third = await EncryptionKeyProvider(secrets).loadOrCreate();

    expect(second, first);
    expect(third, first);
    expect(secrets.writes, 1);
  });

  test('instalaciones distintas generan claves distintas', () async {
    final a = await provider.loadOrCreate();
    final b = await EncryptionKeyProvider(FakeSecretStore()).loadOrCreate();
    expect(a, isNot(b));
  });

  test('un valor corrupto se reemplaza por una clave nueva', () async {
    secrets.values[EncryptionKeyProvider.keyName] = 'no-es-base64!!';
    final key = await provider.loadOrCreate();

    expect(key.length, 32);
    expect(
      base64Decode(secrets.values[EncryptionKeyProvider.keyName]!),
      key,
    );
  });

  test('una clave de longitud incorrecta se reemplaza', () async {
    secrets.values[EncryptionKeyProvider.keyName] = base64Encode(
      List.filled(16, 7),
    );
    final key = await provider.loadOrCreate();
    expect(key.length, 32);
  });
}
