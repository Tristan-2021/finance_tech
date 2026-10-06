import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';
import 'package:core_telemetry/core_telemetry.dart';

import '../domain/account.dart';
import '../domain/account_repository.dart';
import 'accounts_remote_data_source.dart';
import 'money_parser.dart';

/// Mide la llamada remota con la traza `load_balance` y, si falla por red
/// (reintentos agotados), emite `retry_exhausted` con `source: accounts`.
class AccountRepositoryImpl implements AccountRepository {
  final AccountsRemoteDataSource _remote;
  final Telemetry _telemetry;
  const AccountRepositoryImpl(
    this._remote, {
    this._telemetry = const NoopTelemetry(),
  });

  @override
  Future<({List<Account>? accounts, Failure? failure})> getAccounts() async {
    try {
      final rows = await _telemetry.trace('load_balance', _remote.fetchAccounts);
      final accounts = rows.map(_toAccount).toList();
      return (accounts: accounts, failure: null);
    } catch (e) {
      final failure = mapToFailure(e);
      if (failure.code == 'network') {
        _telemetry.logEvent('retry_exhausted', {
          'source': 'accounts',
          'code': failure.code,
        });
      }
      return (accounts: null, failure: failure);
    }
  }

  Account _toAccount(Map<String, dynamic> row) => Account(
    id: row['id'] as String,
    name: row['name'] as String,
    type: row['type'] as String,
    currency: row['currency'] as String,
    balanceCents: parseCents(row['balance']),
  );
}
