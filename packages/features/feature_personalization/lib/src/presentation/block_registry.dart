import 'package:flutter/widgets.dart';

import '../domain/block_type.dart';
import '../domain/home_block.dart';
import 'blocks/info_blocks.dart';
import 'blocks/spending_block.dart';
import 'spending_cubit.dart';

typedef BlockBuilder = Widget Function(BuildContext context, HomeBlock block);

/// Asocia cada [BlockType] con el widget que lo dibuja. Un tipo sin builder
/// no se dibuja: añadir un bloque nuevo es registrar una entrada aquí.
class BlockRegistry {
  final Map<BlockType, BlockBuilder> _builders;

  BlockRegistry(this._builders);

  /// Registro estándar. [spendingCubitFactory] crea el Cubit del resumen.
  /// [overrides] reemplaza o añade constructores por tipo: así el shell puede
  /// dibujar un bloque con un widget de otro feature sin que este paquete lo
  /// conozca.
  factory BlockRegistry.standard({
    required SpendingCubit Function() spendingCubitFactory,
    Map<BlockType, BlockBuilder> overrides = const {},
  }) => BlockRegistry({
    BlockType.tip: (_, block) => TipBlock(block: block),
    BlockType.promo: (_, block) => PromoBlock(block: block),
    BlockType.exchangeRate: (_, block) => ExchangeRateBlock(block: block),
    BlockType.spendingSummary: (_, block) =>
        SpendingSummaryBlock(cubitFactory: spendingCubitFactory),
    ...overrides,
  });

  Widget build(BuildContext context, HomeBlock block) {
    final builder = _builders[block.type];
    return builder == null ? const SizedBox.shrink() : builder(context, block);
  }
}
