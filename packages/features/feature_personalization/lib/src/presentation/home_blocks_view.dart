import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'block_registry.dart';
import 'home_cubit.dart';

/// Dibuja los bloques del [HomeCubit] uno bajo otro. Recibe sus dependencias
/// (no usa GetIt) para probarse sola.
class HomeBlocksView extends StatelessWidget {
  final HomeCubit cubit;
  final BlockRegistry registry;

  const HomeBlocksView({super.key, required this.cubit, required this.registry});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      bloc: cubit,
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final block in state.blocks)
            KeyedSubtree(
              key: ValueKey(block.id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: registry.build(context, block),
              ),
            ),
        ],
      ),
    );
  }
}
