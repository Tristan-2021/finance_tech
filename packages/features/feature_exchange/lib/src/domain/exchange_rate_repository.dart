import 'package:core_errors/core_errors.dart';

import 'exchange_rate.dart';

/// Resultado de pedir una tasa. Si [cachedAt] no es `null`, la tasa salió de
/// una copia guardada (obsoleta) porque no se pudo contactar al servicio.
typedef RateResult = ({ExchangeRate? rate, DateTime? cachedAt, Failure? failure});

abstract interface class ExchangeRateRepository {
  Future<RateResult> getRate({required String from, required String to});
}
