import 'home_block.dart';

/// Composición del home: una lista por defecto y una lista por segmento.
class HomeLayout {
  final int schemaVersion;
  final List<HomeBlock> defaultBlocks;
  final Map<String, List<HomeBlock>> segmentBlocks;

  const HomeLayout({
    required this.schemaVersion,
    required this.defaultBlocks,
    required this.segmentBlocks,
  });

  /// Bloques del [segment]; un segmento desconocido (o `null`) usa la lista
  /// por defecto. El segmento es un dato, no un enum cerrado.
  List<HomeBlock> blocksFor(String? segment) {
    final blocks = segment == null ? null : segmentBlocks[segment];
    return blocks ?? defaultBlocks;
  }
}
