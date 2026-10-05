import 'dart:convert';

import '../domain/block_type.dart';
import '../domain/home_block.dart';
import '../domain/home_layout.dart';

/// Parsea el JSON `home_layout` de Remote Config.
///
/// Reglas:
/// 1. JSON mal formado, o raíz que no es un objeto → `null`.
/// 2. `schema_version` distinto de [supportedSchemaVersion] → `null`
///    (un esquema que esta app no entiende no se interpreta a medias).
/// 3. Bloques con tipo desconocido, sin `id` o con `id` repetido en la misma
///    lista se descartan; el resto sigue.
/// 4. Cada lista se recorta a [maxBlocksPerList] bloques.
/// 5. La lista `default` es obligatoria y debe quedar con al menos un bloque;
///    si no, `null`. Un segmento cuya lista queda vacía se omite (cae en
///    `default`).
///
/// `null` significa "layout inválido": quien llama conserva el último válido.
class HomeLayoutParser {
  static const supportedSchemaVersion = 1;
  static const maxBlocksPerList = 12;

  const HomeLayoutParser();

  HomeLayout? parse(String? source) {
    if (source == null || source.trim().isEmpty) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    if (decoded['schema_version'] != supportedSchemaVersion) return null;

    final defaults = _parseBlocks(decoded['default']);
    if (defaults.isEmpty) return null;

    final segments = <String, List<HomeBlock>>{};
    final rawSegments = decoded['segments'];
    if (rawSegments is Map<String, Object?>) {
      for (final entry in rawSegments.entries) {
        final blocks = _parseBlocks(entry.value);
        if (blocks.isNotEmpty) segments[entry.key] = blocks;
      }
    }

    return HomeLayout(
      schemaVersion: supportedSchemaVersion,
      defaultBlocks: defaults,
      segmentBlocks: segments,
    );
  }

  List<HomeBlock> _parseBlocks(Object? raw) {
    if (raw is! List<Object?>) return const [];
    final blocks = <HomeBlock>[];
    final seenIds = <String>{};
    for (final item in raw) {
      if (blocks.length >= maxBlocksPerList) break;
      if (item is! Map<String, Object?>) continue;
      final id = item['id'];
      final type = BlockType.fromWire(item['type']);
      if (id is! String || id.isEmpty || type == null) continue;
      if (!seenIds.add(id)) continue;
      final params = item['params'];
      blocks.add(
        HomeBlock(
          id: id,
          type: type,
          params: params is Map<String, Object?> ? params : const {},
        ),
      );
    }
    return blocks;
  }
}
