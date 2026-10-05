import 'dart:async';

import 'package:core_telemetry/core_telemetry.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/home_block.dart';
import '../domain/home_layout.dart';
import '../domain/layout_use_cases.dart';

class HomeState {
  final List<HomeBlock> blocks;
  const HomeState(this.blocks);
}

/// Decide qué bloques se muestran para [segment]. Arranca con el último layout
/// válido (sin esperar a la red), pide uno nuevo y escucha los cambios de
/// Remote Config.
///
/// Registra `block_viewed` una vez por bloque y por Cubit, solo con id, tipo y
/// segmento: nunca importes ni datos del usuario.
class HomeCubit extends Cubit<HomeState> {
  final GetHomeLayout _getLayout;
  final RefreshHomeLayout _refreshLayout;
  final WatchHomeLayout _watchLayout;
  final Telemetry _telemetry;
  final String _segment;
  final Set<String> _viewed = {};
  StreamSubscription<void>? _subscription;

  HomeCubit(
    this._getLayout,
    this._refreshLayout,
    this._watchLayout,
    this._telemetry,
    this._segment,
  ) : super(const HomeState([]));

  Future<void> start() async {
    _show(_getLayout());
    _subscription = _watchLayout().listen(_show);
    final refreshed = await _refreshLayout();
    _show(refreshed);
  }

  void _show(HomeLayout layout) {
    if (isClosed) return;
    final blocks = layout.blocksFor(_segment);
    emit(HomeState(blocks));
    for (final block in blocks) {
      if (_viewed.add(block.id)) {
        _telemetry.logEvent('block_viewed', {
          'block_id': block.id,
          'block_type': block.type.wire,
          'segment': _segment,
        });
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
