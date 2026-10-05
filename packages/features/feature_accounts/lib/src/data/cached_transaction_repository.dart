import 'dart:convert';

import 'package:core_errors/core_errors.dart';
import 'package:core_storage/core_storage.dart';

import '../domain/stale_list.dart';
import '../domain/transaction.dart';
import '../domain/transaction_repository.dart';
import 'cache_codecs.dart';

/// *Cache-then-network* para los movimientos. Solo la **primera página**
/// (`offset == 0`) de cada cuenta se guarda y se puede servir desde la caché;
/// las páginas siguientes van siempre al servidor.
class CachedTransactionRepository implements TransactionRepository {
  final TransactionRepository _remote;
  final CacheStore _cache;

  const CachedTransactionRepository(this._remote, this._cache);

  static String cacheKey(String accountId) => 'transactions:$accountId';

  @override
  Future<({List<Transaction>? transactions, Failure? failure})> getTransactions({
    required String accountId,
    required int offset,
    required int limit,
  }) async {
    final result = await _remote.getTransactions(
      accountId: accountId,
      offset: offset,
      limit: limit,
    );
    if (offset != 0) return result;

    final items = result.transactions;
    if (items != null) {
      await _save(accountId, items);
      return result;
    }

    if (canServeFromCache(result.failure)) {
      final cached = await _load(accountId, limit);
      if (cached != null) return (transactions: cached, failure: null);
    }
    return result;
  }

  Future<void> _save(String accountId, List<Transaction> items) async {
    try {
      await _cache.write(
        cacheKey(accountId),
        jsonEncode(items.map(transactionToJson).toList()),
      );
    } catch (_) {
      // Sin caché la app sigue funcionando.
    }
  }

  Future<StaleList<Transaction>?> _load(String accountId, int limit) async {
    try {
      final entry = await _cache.read(cacheKey(accountId));
      if (entry == null) return null;
      final items = (jsonDecode(entry.value) as List)
          .cast<Map<String, dynamic>>()
          .map(transactionFromJson)
          .take(limit)
          .toList();
      return StaleList<Transaction>(items, entry.savedAt);
    } catch (_) {
      return null; // copia ilegible: se trata como si no existiera
    }
  }
}
