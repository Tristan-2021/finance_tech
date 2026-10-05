/// Tipos de bloque que entiende el home. Un tipo desconocido en el JSON se
/// ignora (así una app vieja no se rompe con bloques nuevos).
enum BlockType {
  tip('tip'),
  promo('promo'),
  spendingSummary('spending_summary'),
  exchangeRate('exchange_rate');

  /// Nombre del tipo en el JSON de Remote Config.
  final String wire;

  const BlockType(this.wire);

  static BlockType? fromWire(Object? value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}
