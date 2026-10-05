import 'dart:convert';

import 'package:feature_personalization/feature_personalization.dart';
import 'package:feature_personalization/src/data/default_layout.dart';
import 'package:feature_personalization/src/data/home_layout_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String _json({
  Object? version = 1,
  Object? defaults,
  Object? segments,
}) => jsonEncode({
  'schema_version': version,
  'default': defaults ??
      [
        {'id': 'a', 'type': 'tip'},
      ],
  'segments': ?segments,
});

void main() {
  const parser = HomeLayoutParser();

  test('el layout por defecto embebido siempre parsea', () {
    final layout = parser.parse(defaultHomeLayoutJson);
    expect(layout, isNotNull);
    expect(layout!.defaultBlocks, isNotEmpty);
    expect(layout.segmentBlocks.keys, containsAll(['joven', 'adulto']));
  });

  group('regla 1: JSON inválido', () {
    test('null, vacío, mal formado o raíz no objeto → null', () {
      expect(parser.parse(null), isNull);
      expect(parser.parse('  '), isNull);
      expect(parser.parse('{no es json'), isNull);
      expect(parser.parse('[1, 2]'), isNull);
    });
  });

  group('regla 2: schema_version', () {
    test('versión distinta o ausente → null', () {
      expect(parser.parse(_json(version: 2)), isNull);
      expect(parser.parse(_json(version: '1')), isNull);
      expect(parser.parse(jsonEncode({'default': []})), isNull);
    });
  });

  group('regla 3: bloques inválidos se descartan', () {
    test('tipo desconocido, sin id y id repetido', () {
      final layout = parser.parse(
        _json(
          defaults: [
            {'id': 'ok', 'type': 'tip'},
            {'id': 'raro', 'type': 'hologram'},
            {'type': 'tip'},
            {'id': '', 'type': 'tip'},
            {'id': 'ok', 'type': 'promo'},
            'basura',
          ],
        ),
      );
      expect(layout!.defaultBlocks.map((b) => b.id), ['ok']);
      expect(layout.defaultBlocks.single.type, BlockType.tip);
    });

    test('params no objeto se convierte en vacío', () {
      final layout = parser.parse(
        _json(
          defaults: [
            {'id': 'a', 'type': 'tip', 'params': 'x'},
            {
              'id': 'b',
              'type': 'tip',
              'params': {'text': 'hola', 'n': 3},
            },
          ],
        ),
      );
      expect(layout!.defaultBlocks[0].params, isEmpty);
      expect(layout.defaultBlocks[1].stringParam('text'), 'hola');
      expect(layout.defaultBlocks[1].intParam('n'), 3);
      expect(layout.defaultBlocks[1].stringParam('n'), isNull);
    });
  });

  group('regla 4: tope de bloques', () {
    test('recorta cada lista a maxBlocksPerList', () {
      final many = [
        for (var i = 0; i < 20; i++) {'id': 'b$i', 'type': 'tip'},
      ];
      final layout = parser.parse(_json(defaults: many));
      expect(layout!.defaultBlocks, hasLength(HomeLayoutParser.maxBlocksPerList));
      expect(layout.defaultBlocks.first.id, 'b0');
    });
  });

  group('regla 5: default obligatorio', () {
    test('default ausente, vacío o sin bloques válidos → null', () {
      expect(parser.parse(jsonEncode({'schema_version': 1})), isNull);
      expect(parser.parse(_json(defaults: [])), isNull);
      expect(
        parser.parse(
          _json(
            defaults: [
              {'id': 'x', 'type': 'nada'},
            ],
          ),
        ),
        isNull,
      );
    });

    test('segmento vacío o inválido se omite y cae en default', () {
      final layout = parser.parse(
        _json(
          segments: {
            'joven': [
              {'id': 'j', 'type': 'promo'},
            ],
            'vacio': [],
            'roto': 'no-lista',
          },
        ),
      );
      expect(layout!.segmentBlocks.keys, ['joven']);
      expect(layout.blocksFor('joven').single.id, 'j');
      expect(layout.blocksFor('vacio').single.id, 'a');
      expect(layout.blocksFor('segmento_nuevo').single.id, 'a');
      expect(layout.blocksFor(null).single.id, 'a');
    });
  });
}
