import 'package:feature_personalization/feature_personalization.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

HomeLayout _layout({
  required List<HomeBlock> defaults,
  Map<String, List<HomeBlock>> segments = const {},
}) => HomeLayout(
  schemaVersion: 1,
  defaultBlocks: defaults,
  segmentBlocks: segments,
);

void main() {
  late FakeLayoutRepository repository;
  late FakeTelemetry telemetry;

  HomeCubit buildCubit(String segment) => HomeCubit(
    GetHomeLayout(repository),
    RefreshHomeLayout(repository),
    WatchHomeLayout(repository),
    telemetry,
    segment,
  );

  setUp(() {
    telemetry = FakeTelemetry();
    repository = FakeLayoutRepository(
      _layout(
        defaults: [block('d', BlockType.tip)],
        segments: {
          'joven': [
            block('j1', BlockType.promo),
            block('j2', BlockType.spendingSummary),
          ],
        },
      ),
    );
  });

  tearDown(() => repository.controller.close());

  test('muestra los bloques del segmento y registra block_viewed', () async {
    final cubit = buildCubit('joven');
    await cubit.start();

    expect(cubit.state.blocks.map((b) => b.id), ['j1', 'j2']);
    expect(telemetry.events.map((e) => e.name), everyElement('block_viewed'));
    expect(telemetry.events.map((e) => e.params['block_id']), ['j1', 'j2']);
    expect(telemetry.events.first.params, {
      'block_id': 'j1',
      'block_type': 'promo',
      'segment': 'joven',
    });
    await cubit.close();
  });

  test('un segmento desconocido usa los bloques por defecto', () async {
    final cubit = buildCubit('nuevo');
    await cubit.start();
    expect(cubit.state.blocks.map((b) => b.id), ['d']);
    await cubit.close();
  });

  test('un layout nuevo reemplaza los bloques y solo registra los nuevos', () async {
    repository.refreshed = _layout(
      defaults: [block('d', BlockType.tip)],
      segments: {
        'joven': [
          block('j1', BlockType.promo),
          block('j3', BlockType.tip),
        ],
      },
    );
    final cubit = buildCubit('joven');
    await cubit.start();

    expect(cubit.state.blocks.map((b) => b.id), ['j1', 'j3']);
    expect(telemetry.events.map((e) => e.params['block_id']), [
      'j1',
      'j2',
      'j3',
    ]);
    await cubit.close();
  });

  test('aplica los cambios publicados por Remote Config', () async {
    final cubit = buildCubit('adulto');
    await cubit.start();
    expect(cubit.state.blocks.map((b) => b.id), ['d']);

    repository.controller.add(
      _layout(defaults: [block('d2', BlockType.promo)]),
    );
    await pumpEventQueue();

    expect(cubit.state.blocks.map((b) => b.id), ['d2']);
    await cubit.close();
  });

  test('tras cerrar el Cubit ya no reacciona a cambios', () async {
    final cubit = buildCubit('adulto');
    await cubit.start();
    await cubit.close();
    repository.controller.add(
      _layout(defaults: [block('d2', BlockType.promo)]),
    );
    await pumpEventQueue();
    expect(cubit.state.blocks.map((b) => b.id), ['d']);
  });
}
