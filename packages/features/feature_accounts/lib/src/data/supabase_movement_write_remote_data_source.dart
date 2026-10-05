import 'package:core_network/core_network.dart';

import 'movement_write_remote_data_source.dart';

/// RPC `add_demo_movement`: valida que la cuenta sea del usuario y rechaza un
/// débito mayor al saldo con `insufficient_funds`.
class SupabaseMovementWriteRemoteDataSource
    implements MovementWriteRemoteDataSource {
  final SupabaseClient _client;
  const SupabaseMovementWriteRemoteDataSource(this._client);

  @override
  Future<void> addMovement({
    required String accountId,
    required String type,
    required String amount,
    required String category,
    required String description,
  }) async {
    await _client.rpc(
      'add_demo_movement',
      params: {
        'p_account_id': accountId,
        'p_type': type,
        'p_amount': amount,
        'p_category': category,
        'p_description': description,
      },
    );
  }
}
