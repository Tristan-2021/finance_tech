/// Tasa de cambio diaria (referencia del Banco Central Europeo, no en vivo).
///
/// La tasa se guarda como entero escalado a 6 decimales ([rateScale]): `1.1204`
/// es `1120400`. Nunca se usa `double`.
class ExchangeRate {
  static const rateScale = 1000000;

  final String base;
  final String target;
  final int rateMicros;

  /// Día al que corresponde la tasa.
  final DateTime date;

  const ExchangeRate({
    required this.base,
    required this.target,
    required this.rateMicros,
    required this.date,
  });

  /// `1.120400`: para mostrar la tasa usada, con aritmética entera.
  String get rateText {
    final whole = rateMicros ~/ rateScale;
    final fraction = (rateMicros % rateScale).toString().padLeft(6, '0');
    return '$whole.$fraction';
  }
}
