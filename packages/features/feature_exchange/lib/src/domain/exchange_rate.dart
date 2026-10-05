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

  /// `1.120400`: la tasa exacta, con aritmética entera.
  String get rateText {
    final whole = rateMicros ~/ rateScale;
    final fraction = (rateMicros % rateScale).toString().padLeft(6, '0');
    return '$whole.$fraction';
  }

  /// `1.1204`: sin ceros finales, con al menos dos decimales. Para mostrar.
  String get shortRateText {
    final text = rateText;
    var end = text.length;
    while (end > text.indexOf('.') + 3 && text[end - 1] == '0') {
      end--;
    }
    return text.substring(0, end);
  }
}
