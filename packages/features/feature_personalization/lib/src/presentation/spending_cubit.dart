import 'package:core_ui/core_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/get_spending_summary.dart';
import '../domain/spending_summary.dart';

enum SpendingStatus { loading, loaded, empty, error }

class SpendingState {
  final SpendingStatus status;
  final SpendingSummary? summary;
  final String? message;

  const SpendingState._(this.status, {this.summary, this.message});

  const SpendingState.loading() : this._(SpendingStatus.loading);
  const SpendingState.empty() : this._(SpendingStatus.empty);
  const SpendingState.loaded(SpendingSummary summary)
    : this._(SpendingStatus.loaded, summary: summary);
  const SpendingState.error(String message)
    : this._(SpendingStatus.error, message: message);
}

/// Carga el resumen de gastos del mes para el bloque `spending_summary`.
class SpendingCubit extends Cubit<SpendingState> {
  final GetSpendingSummary _getSummary;

  SpendingCubit(this._getSummary) : super(const SpendingState.loading());

  Future<void> load() async {
    emit(const SpendingState.loading());
    final result = await _getSummary();
    if (isClosed) return;
    final summary = result.summary;
    final failure = result.failure;
    if (failure != null) {
      emit(SpendingState.error(messageForFailure(failure)));
    } else if (summary == null) {
      emit(const SpendingState.empty());
    } else {
      emit(SpendingState.loaded(summary));
    }
  }
}
