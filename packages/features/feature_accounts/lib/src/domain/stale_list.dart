import 'dart:collection';

/// Lista servida desde una copia guardada porque no se pudo contactar al
/// servidor. [cachedAt] es cuándo se guardó (UTC).
///
/// Para quien no la distingue es una lista normal e inmutable; quien quiera
/// avisar al usuario comprueba `lista is StaleList`.
class StaleList<T> extends UnmodifiableListView<T> {
  final DateTime cachedAt;

  StaleList(super.source, this.cachedAt);
}
