import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../domain/block_type.dart';
import 'block_registry.dart';
import 'home_blocks_view.dart';
import 'home_cubit.dart';
import 'spending_cubit.dart';

/// Bloques personalizados para [segment]. Resuelve sus Cubits desde
/// `GetIt.instance` (registrados por `registerPersonalizationDependencies`) y
/// cierra el [HomeCubit] al salir.
class PersonalizedHome extends StatefulWidget {
  final String segment;

  /// Constructores de bloque que reemplazan a los estándar (los pone el shell).
  final Map<BlockType, BlockBuilder> blockOverrides;

  const PersonalizedHome({
    super.key,
    required this.segment,
    this.blockOverrides = const {},
  });

  @override
  State<PersonalizedHome> createState() => _PersonalizedHomeState();
}

class _PersonalizedHomeState extends State<PersonalizedHome> {
  final _getIt = GetIt.instance;
  late final HomeCubit _cubit = _getIt<HomeCubit>(param1: widget.segment);
  late final BlockRegistry _registry = BlockRegistry.standard(
    spendingCubitFactory: () => _getIt<SpendingCubit>(),
    overrides: widget.blockOverrides,
  );

  @override
  void initState() {
    super.initState();
    _cubit.start();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      HomeBlocksView(cubit: _cubit, registry: _registry);
}
