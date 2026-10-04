import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';

import '../domain/account.dart';
import '../domain/account_repository.dart';
import 'accounts_remote_data_source.dart';
import 'money_parser.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AccountsRemoteDataSource _remote;
  const AccountRepositoryImpl(this._remote);

  @override
  Future<({List<Account>? accounts, Failure? failure})> getAccounts() async {
    try {
      final rows = await _remote.fetchAccounts();
      final accounts = rows.map(_toAccount).toList();
      return (accounts: accounts, failure: null);
    } catch (e) {
      return (accounts: null, failure: mapToFailure(e));
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
