import 'dart:io';

import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRemote implements TransactionsRemoteDataSource {
  Object? error;
  List<Map<String, dynamic>> rows = [];
  int calls = 0;
  ({String accountId, int offset, int limit})? received;

  @override
  Future<List<Map<String, dynamic>>> fetchTransactions({
    required String accountId,
    int offset = 0,
    int limit = 20,
  }) async {
    calls++;
    received = (accountId: accountId, offset: offset, limit: limit);
    if (error != null) throw error!;
    return rows;
  }
}

class FakeRepository implements TransactionRepository {
  Failure? failure;
  List<Transaction> transactions = [];
  ({String accountId, int offset, int limit})? received;

  @override
  Future<({List<Transaction>? transactions, Failure? failure})> getTransactions({
    required String accountId,
    required int offset,
    required int limit,
  }) async {
    received = (accountId: accountId, offset: offset, limit: limit);
    return failure == null
        ? (transactions: transactions, failure: null)
        : (transactions: null, failure: failure);
  }
}

Map<String, dynamic> row({
  String id = 't1',
  Object? type = 'credit',
  Object? amount = '12.30',
  Object? balanceAfter = '512.30',
  String? category = 'ingreso',
  String? description = 'Transferencia recibida',
  String createdAt = '2026-10-04T10:00:00+00:00',
}) => {
  'id': id,
  'account_id': 'a1',
  'type': type,
  'amount': amount,
  'category': category,
  'description': description,
  'balance_after': balanceAfter,
  'created_at': createdAt,
};

void main() {
  group('pageRange', () {
    test('0, 20 -> 0..19', () => expect(pageRange(0, 20), (from: 0, to: 19)));
    test('20, 20 -> 20..39', () {
      expect(pageRange(20, 20), (from: 20, to: 39));
    });
    test('0, 5 -> 0..4', () => expect(pageRange(0, 5), (from: 0, to: 4)));
  });

  group('TransactionRepositoryImpl', () {
    late FakeRemote remote;
    late TransactionRepositoryImpl repo;
    setUp(() {
      remote = FakeRemote();
      repo = TransactionRepositoryImpl(remote);
    });

    Future<({List<Transaction>? transactions, Failure? failure})> load() =>
        repo.getTransactions(accountId: 'a1', offset: 0, limit: 20);

    group('type', () {
      test('credit', () async {
        remote.rows = [row(type: 'credit')];
        final r = await load();
        expect(r.transactions?.single.type, TransactionType.credit);
      });

      test('debit', () async {
        remote.rows = [row(type: 'debit')];
        final r = await load();
        expect(r.transactions?.single.type, TransactionType.debit);
      });

      test('valor desconocido -> Failure', () async {
        remote.rows = [row(type: 'refund')];
        final r = await load();
        expect(r.transactions, isNull);
        expect(r.failure?.code, 'unknown');
      });
    });

    group('montos', () {
      test("'12.30' -> 1230 centavos", () async {
        remote.rows = [row(amount: '12.30')];
        final r = await load();
        expect(r.transactions?.single.amountCents, 1230);
      });

      test('12.3 (número JSON sin cero final) -> 1230 centavos', () async {
        remote.rows = [row(amount: 12.3)];
        final r = await load();
        expect(r.transactions?.single.amountCents, 1230);
      });

      test("'1000.00' -> 100000 centavos", () async {
        remote.rows = [row(amount: '1000.00', balanceAfter: '1500.50')];
        final r = await load();
        expect(r.transactions?.single.amountCents, 100000);
        expect(r.transactions?.single.balanceAfterCents, 150050);
      });

      test('monto corrupto -> Failure', () async {
        remote.rows = [row(amount: 'abc')];
        final r = await load();
        expect(r.transactions, isNull);
        expect(r.failure?.code, 'unknown');
      });

      test('balance_after corrupto -> Failure', () async {
        remote.rows = [row(balanceAfter: null)];
        final r = await load();
        expect(r.failure?.code, 'unknown');
      });
    });

    group('category', () {
      test('valor fuera de la lista de la demo se acepta', () async {
        remote.rows = [row(category: 'mascotas')];
        final r = await load();
        expect(r.failure, isNull);
        expect(r.transactions?.single.category, 'mascotas');
      });

      test('category y description nulos se aceptan', () async {
        remote.rows = [row(category: null, description: null)];
        final r = await load();
        expect(r.failure, isNull);
        expect(r.transactions?.single.category, isNull);
        expect(r.transactions?.single.description, isNull);
      });
    });

    group('paginación', () {
      test('pasa accountId, offset y limit al data source', () async {
        await repo.getTransactions(accountId: 'a9', offset: 20, limit: 10);
        expect(remote.received, (accountId: 'a9', offset: 20, limit: 10));
      });

      test('offset negativo -> Failure sin llamar al data source', () async {
        final r = await repo.getTransactions(
          accountId: 'a1',
          offset: -1,
          limit: 20,
        );
        expect(r.transactions, isNull);
        expect(r.failure?.code, 'invalid_input');
        expect(remote.calls, 0);
      });

      test('limit 0 -> Failure', () async {
        final r = await repo.getTransactions(
          accountId: 'a1',
          offset: 0,
          limit: 0,
        );
        expect(r.failure?.code, 'invalid_input');
        expect(remote.calls, 0);
      });

      test('limit negativo -> Failure', () async {
        final r = await repo.getTransactions(
          accountId: 'a1',
          offset: 0,
          limit: -5,
        );
        expect(r.failure?.code, 'invalid_input');
        expect(remote.calls, 0);
      });
    });

    group('resultados y errores', () {
      test('lista vacía', () async {
        final r = await load();
        expect(r.failure, isNull);
        expect(r.transactions, isEmpty);
      });

      test('lista con datos y orden preservado', () async {
        remote.rows = [
          row(id: 't3', createdAt: '2026-10-04T10:00:00Z'),
          row(id: 't2', createdAt: '2026-10-03T10:00:00Z'),
          row(id: 't1', createdAt: '2026-10-02T10:00:00Z'),
        ];
        final r = await load();
        expect(r.transactions?.map((t) => t.id), ['t3', 't2', 't1']);
        expect(r.transactions?.first.accountId, 'a1');
        expect(
          r.transactions?.first.createdAt.toUtc(),
          DateTime.utc(2026, 10, 4, 10),
        );
      });

      test('42501 -> rls_denied', () async {
        remote.error = PostgrestException(message: 'denied', code: '42501');
        final r = await load();
        expect(r.transactions, isNull);
        expect(r.failure?.code, 'rls_denied');
      });

      test('SocketException -> network', () async {
        remote.error = const SocketException('sin red');
        final r = await load();
        expect(r.transactions, isNull);
        expect(r.failure?.code, 'network');
      });
    });
  });

  group('GetTransactions', () {
    late FakeRepository repo;
    setUp(() => repo = FakeRepository());

    test('pasa accountId, offset y limit al repositorio', () async {
      await GetTransactions(repo)('a1', offset: 40, limit: 10);
      expect(repo.received, (accountId: 'a1', offset: 40, limit: 10));
    });

    test('usa offset 0 y limit 20 por defecto', () async {
      await GetTransactions(repo)('a1');
      expect(repo.received, (accountId: 'a1', offset: 0, limit: 20));
    });

    test('devuelve los movimientos del repositorio', () async {
      repo.transactions = [
        Transaction(
          id: 't1',
          accountId: 'a1',
          type: TransactionType.debit,
          amountCents: 1230,
          balanceAfterCents: 48770,
          createdAt: DateTime.utc(2026, 10, 4),
        ),
      ];
      final r = await GetTransactions(repo)('a1');
      expect(r.failure, isNull);
      expect(r.transactions?.single.id, 't1');
    });

    test('propaga el Failure', () async {
      repo.failure = const Failure('denegado', 'rls_denied');
      final r = await GetTransactions(repo)('a1');
      expect(r.transactions, isNull);
      expect(r.failure?.code, 'rls_denied');
    });
  });
}
