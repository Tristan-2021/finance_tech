import 'package:core_network/core_network.dart';

import 'page_range.dart';
import 'transactions_remote_data_source.dart';

class SupabaseTransactionsRemoteDataSource
    implements TransactionsRemoteDataSource {
  final SupabaseClient _client;
  const SupabaseTransactionsRemoteDataSource(this._client);

  @override
  Future<List<Map<String, dynamic>>> fetchTransactions({
    required String accountId,
    int offset = 0,
    int limit = 20,
  }) {
    final range = pageRange(offset, limit);
    return _client
        .from('transactions')
        .select()
        .eq('account_id', accountId)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(range.from, range.to);
  }
}
