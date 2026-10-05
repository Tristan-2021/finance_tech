import 'package:core_ui/core_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/exchange_rate.dart';
import '../domain/get_rate.dart';

enum ExchangeStatus { loading, loaded, error }

class ExchangeState {
  final ExchangeStatus status;
  final ExchangeRate? rate;

  /// Si no es `null`, la tasa viene de una copia guardada (obsoleta).
  final DateTime? cachedAt;
  final String? message;

  const ExchangeState._(
    this.status, {
    this.rate,
    this.cachedAt,
    this.message,
  });

  const ExchangeState.loading() : this._(ExchangeStatus.loading);

  const ExchangeState.loaded(ExchangeRate rate, {DateTime? cachedAt})
    : this._(ExchangeStatus.loaded, rate: rate, cachedAt: cachedAt);

  const ExchangeState.error(String message)
    : this._(ExchangeStatus.error, message: message);

  bool get isStale => cachedAt != null;
}

class ExchangeCubit extends Cubit<ExchangeState> {
  final GetRate _getRate;
  final String from;
  final String to;

  ExchangeCubit(this._getRate, {required this.from, required this.to})
    : super(const ExchangeState.loading());

  Future<void> load() async {
    emit(const ExchangeState.loading());
    final result = await _getRate(from: from, to: to);
    if (isClosed) return;
    final rate = result.rate;
    final failure = result.failure;
    if (rate != null) {
      emit(ExchangeState.loaded(rate, cachedAt: result.cachedAt));
    } else {
      emit(ExchangeState.error(messageForFailure(failure!)));
    }
  }
}
