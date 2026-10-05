import 'exchange_rate_repository.dart';

class GetRate {
  final ExchangeRateRepository _repository;
  const GetRate(this._repository);

  Future<RateResult> call({String from = 'EUR', String to = 'USD'}) =>
      _repository.getRate(from: from, to: to);
}
