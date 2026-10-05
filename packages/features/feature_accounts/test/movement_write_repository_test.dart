import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:feature_accounts/src/data/movement_write_remote_data_source.dart';
import 'package:feature_accounts/src/data/movement_write_repository_impl.dart';
import 'package:feature_accounts/src/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRemote implements MovementWriteRemoteDataSource {
  Object? error;
  final calls = <Map<String, String>>[];

  @override
  Future<void> addMovement({
    required String accountId,
    required String type,
    required String amount,
    required String category,
    required String description,
  }) async {
    calls.add({
      'account': accountId,
      'type': type,
      'amount': amount,
      'category': category,
      'description': description,
    });
    if (error != null) throw error!;
  }
}

void main() {
  late _FakeRemote remote;
  late MovementWriteRepositoryImpl repo;

  setUp(() {
    remote = _FakeRemote();
    repo = MovementWriteRepositoryImpl(remote);
  });

  Future<dynamic> add({
    TransactionType type = TransactionType.debit,
    int cents = 1230,
  }) => repo.addMovement(
    accountId: 'a1',
    type: type,
    amountCents: cents,
    category: 'comida',
    description: 'Gasto manual',
  );

  test('envía el monto como cadena decimal exacta y el tipo del backend', () async {
    expect(await add(), isNull);
    expect(remote.calls.single, {
      'account': 'a1',
      'type': 'debit',
      'amount': '12.30',
      'category': 'comida',
      'description': 'Gasto manual',
    });

    await add(type: TransactionType.credit, cents: 5);
    expect(remote.calls.last['type'], 'credit');
    expect(remote.calls.last['amount'], '0.05');
  });

  test('un monto no positivo ni siquiera llega al servidor', () async {
    final failure = await add(cents: 0);
    expect(failure.code, 'invalid_input');
    expect(remote.calls, isEmpty);
  });

  test('insufficient_funds se mapea a su código', () async {
    remote.error = PostgrestException(message: 'insufficient_funds', code: 'P0001');
    expect((await add()).code, 'insufficient_funds');
  });

  test('sin red se mapea a network', () async {
    remote.error = const SocketException('sin red');
    expect((await add()).code, 'network');
  });

  test('RLS se mapea a rls_denied', () async {
    remote.error = PostgrestException(message: 'denegado', code: '42501');
    expect((await add()).code, 'rls_denied');
  });
}
