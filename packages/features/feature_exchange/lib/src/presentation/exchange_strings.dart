/// Textos del conversor de remesas.
abstract final class ExchangeStrings {
  static const title = 'Remesas';
  static const amountLabel = 'Monto en euros';
  static const amountHint = 'Escribe un monto para ver cuánto recibirías.';
  static const retry = 'Reintentar';
  static const dailyNote = 'Tasa diaria de referencia, no en tiempo real.';

  static String pair(String from, String to) => '$from → $to';

  static String result(String amount) => 'Recibirías $amount';

  static String rateUsed(String from, String to, String rate) =>
      '1 $from = $rate $to';

  static String rateDate(String date) => 'Tasa del $date (BCE)';

  static String staleNotice(String date) =>
      'Sin conexión: tasa guardada del $date.';
}
