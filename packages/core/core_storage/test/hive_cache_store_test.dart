import 'dart:convert';
import 'dart:io';

import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class FakeSecretStore implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late Directory dir;
  late FakeSecretStore secrets;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('core_storage_test_');
    secrets = FakeSecretStore();
  });

  tearDown(() async {
    await Hive.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<HiveCacheStore> open({
    FakeSecretStore? secretStore,
    DateTime Function()? clock,
  }) {
    return HiveCacheStore.open(
      keyProvider: EncryptionKeyProvider(secretStore ?? secrets),
      path: dir.path,
      clock: clock,
    );
  }

  test('escribir y leer devuelve el valor y la fecha de guardado', () async {
    final savedAt = DateTime.utc(2026, 10, 4, 12, 30);
    final store = await open(clock: () => savedAt);

    await store.write('accounts', '{"a":1}');
    final entry = await store.read('accounts');

    expect(entry?.value, '{"a":1}');
    expect(entry?.savedAt, savedAt);
  });

  test('leer una clave inexistente devuelve null', () async {
    final store = await open();
    expect(await store.read('nada'), isNull);
  });

  test('sobrescribir actualiza el valor y la fecha', () async {
    var now = DateTime.utc(2026, 10, 4, 12);
    final store = await open(clock: () => now);

    await store.write('k', 'viejo');
    now = DateTime.utc(2026, 10, 4, 13);
    await store.write('k', 'nuevo');

    final entry = await store.read('k');
    expect(entry?.value, 'nuevo');
    expect(entry?.savedAt, DateTime.utc(2026, 10, 4, 13));
  });

  test('clear borra todo', () async {
    final store = await open();
    await store.write('a', '1');
    await store.write('b', '2');

    await store.clear();

    expect(await store.read('a'), isNull);
    expect(await store.read('b'), isNull);
  });

  test('los datos persisten al cerrar y reabrir con la misma clave', () async {
    final first = await open();
    await first.write('k', 'persistente');
    await first.close();

    final second = await open();
    expect((await second.read('k'))?.value, 'persistente');
  });

  test('en disco el contenido está cifrado', () async {
    final store = await open();
    await store.write('k', 'valor-en-claro-123');
    await store.close();

    final file = dir
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('.hive'));
    final text = latin1.decode(file.readAsBytesSync(), allowInvalid: true);

    expect(text.contains('valor-en-claro-123'), isFalse);
  });

  test('con otra clave no se lee lo anterior y no se rompe', () async {
    final first = await open();
    await first.write('k', 'secreto');
    await first.close();

    final second = await open(secretStore: FakeSecretStore()); // otra clave
    expect(await second.read('k'), isNull);

    await second.write('k', 'nuevo');
    expect((await second.read('k'))?.value, 'nuevo');
  });

  group('dueño de la caché', () {
    test('el primer dueño descarta lo guardado sin dueño', () async {
      final store = await open();
      await store.write('k', 'sin-dueño');

      await store.bindOwner('u1');

      expect(await store.read('k'), isNull);
    });

    test('el mismo dueño conserva los datos', () async {
      final store = await open();
      await store.bindOwner('u1');
      await store.write('k', 'de-u1');

      await store.bindOwner('u1');

      expect((await store.read('k'))?.value, 'de-u1');
    });

    test('otro dueño no ve los datos del anterior', () async {
      final store = await open();
      await store.bindOwner('u1');
      await store.write('k', 'de-u1');

      await store.bindOwner('u2');

      expect(await store.read('k'), isNull);
    });

    test('el dueño se recuerda al reabrir', () async {
      final first = await open();
      await first.bindOwner('u1');
      await first.write('k', 'de-u1');
      await first.close();

      final second = await open();
      await second.bindOwner('u1');
      expect((await second.read('k'))?.value, 'de-u1');

      await second.bindOwner('u2');
      expect(await second.read('k'), isNull);
    });

    test('clear (cerrar sesión) deja la caché sin dueño ni datos', () async {
      final store = await open();
      await store.bindOwner('u1');
      await store.write('k', 'de-u1');

      await store.clear();
      await store.bindOwner('u1'); // vuelve a empezar vacía

      expect(await store.read('k'), isNull);
    });
  });
}
