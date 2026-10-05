import 'dart:async';

import 'package:feature_personalization/src/data/default_layout.dart';
import 'package:feature_personalization/src/data/home_layout_parser.dart';
import 'package:feature_personalization/src/data/home_layout_repository_impl.dart';
import 'package:feature_personalization/src/data/layout_source.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSource implements LayoutSource {
  String? next;
  Object? error;
  final controller = StreamController<String?>.broadcast();

  @override
  Future<String?> fetch() async {
    if (error != null) throw error!;
    return next;
  }

  @override
  Stream<String?> get updates => controller.stream;
}

const _valid =
    '{"schema_version":1,"default":[{"id":"nuevo","type":"promo"}]}';

void main() {
  late _FakeSource source;
  late HomeLayoutRepositoryImpl repository;

  setUp(() {
    source = _FakeSource();
    repository = HomeLayoutRepositoryImpl(source);
  });

  tearDown(() => source.controller.close());

  test('current parte del layout embebido, sin red', () {
    final expected = const HomeLayoutParser().parse(defaultHomeLayoutJson)!;
    expect(
      repository.current.defaultBlocks.map((b) => b.id),
      expected.defaultBlocks.map((b) => b.id),
    );
  });

  test('refresh adopta un layout válido', () async {
    source.next = _valid;
    final layout = await repository.refresh();
    expect(layout.defaultBlocks.single.id, 'nuevo');
    expect(repository.current.defaultBlocks.single.id, 'nuevo');
  });

  test('refresh con JSON inválido conserva el último válido', () async {
    source.next = _valid;
    await repository.refresh();
    source.next = '{roto';
    final layout = await repository.refresh();
    expect(layout.defaultBlocks.single.id, 'nuevo');
  });

  test('refresh con error de red conserva el layout actual', () async {
    source.error = Exception('sin red');
    final layout = await repository.refresh();
    expect(layout.defaultBlocks, isNotEmpty);
    expect(layout.defaultBlocks.first.id, 'tip_default');
  });

  test('changes emite solo layouts válidos', () async {
    final received = <String>[];
    final sub = repository.changes.listen(
      (l) => received.add(l.defaultBlocks.first.id),
    );
    await pumpEventQueue();
    source.controller.add('{roto');
    source.controller.add(_valid);
    await pumpEventQueue();
    await sub.cancel();
    expect(received, ['nuevo']);
    expect(repository.current.defaultBlocks.single.id, 'nuevo');
  });
}
