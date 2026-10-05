import 'dart:async';

import '../domain/home_layout.dart';
import '../domain/home_layout_repository.dart';
import 'default_layout.dart';
import 'home_layout_parser.dart';
import 'layout_source.dart';

/// Conserva siempre el último layout válido. Parte del embebido, así que
/// [current] nunca espera ni falla.
class HomeLayoutRepositoryImpl implements HomeLayoutRepository {
  final LayoutSource _source;
  final HomeLayoutParser _parser = const HomeLayoutParser();
  late HomeLayout _current;

  HomeLayoutRepositoryImpl(this._source) {
    _current = _parser.parse(defaultHomeLayoutJson)!;
  }

  @override
  HomeLayout get current => _current;

  @override
  Future<HomeLayout> refresh() async {
    try {
      _accept(await _source.fetch());
    } catch (_) {
      // Sin red o servicio caído: se queda el último válido.
    }
    return _current;
  }

  @override
  Stream<HomeLayout> get changes => _source.updates
      .handleError((Object _) {})
      .where(_accept)
      .map((_) => _current);

  bool _accept(String? raw) {
    final parsed = _parser.parse(raw);
    if (parsed == null) return false;
    _current = parsed;
    return true;
  }
}
