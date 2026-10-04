String _groupThousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// `123456` -> `$1,234.56`; negativos `-$1.00`. Solo aritmética entera.
/// Otras monedas distintas de USD se muestran con su código: `EUR 1.00`.
String formatCents(int cents, {String currency = 'USD'}) {
  final abs = cents.abs();
  final whole = _groupThousands(abs ~/ 100);
  final fraction = (abs % 100).toString().padLeft(2, '0');
  final symbol = currency == 'USD' ? '\$' : '$currency ';
  final sign = cents < 0 ? '-' : '';
  return '$sign$symbol$whole.$fraction';
}

/// Forma hablada para lectores de pantalla: `50 dólares con 00 centavos`,
/// `1 dólar con 00 centavos`. Sin separadores de miles.
String spokenAmountEs(int cents) {
  final abs = cents.abs();
  final dollars = abs ~/ 100;
  final fraction = abs % 100;
  final dollarsText = '$dollars ${dollars == 1 ? 'dólar' : 'dólares'}';
  final centsText =
      '${fraction.toString().padLeft(2, '0')} '
      '${fraction == 1 ? 'centavo' : 'centavos'}';
  final sign = cents < 0 ? 'menos ' : '';
  return '$sign$dollarsText con $centsText';
}
