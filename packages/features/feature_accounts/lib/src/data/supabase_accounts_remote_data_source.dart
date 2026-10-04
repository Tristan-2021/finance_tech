import 'package:core_network/core_network.dart';

import 'accounts_remote_data_source.dart';

class SupabaseAccountsRemoteDataSource implements AccountsRemoteDataSource {
  final SupabaseClient _client;
  const SupabaseAccountsRemoteDataSource(this._client);

  @override
  Future<List<Map<String, dynamic>>> fetchAccounts() {
    return _client.from('accounts').select();
  }
}
