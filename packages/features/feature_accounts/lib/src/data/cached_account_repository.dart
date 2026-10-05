import 'dart:convert';

import 'package:core_errors/core_errors.dart';
import 'package:core_storage/core_storage.dart';

import '../domain/account.dart';
import '../domain/account_repository.dart';
import '../domain/stale_list.dart';
import 'cache_codecs.dart';

/// *Cache-then-network* para las cuentas: pide al servidor y guarda el
/// resultado; si el servidor no responde, sirve la copia guardada marcada como
/// [StaleList]. Un fallo de la propia caché nunca rompe la carga.
class CachedAccountRepository implements AccountRepository {
  static const cacheKey = 'accounts';

  final AccountRepository _remote;
  final CacheStore _cache;

  const CachedAccountRepository(this._remote, this._cache);

  @override
  Future<({List<Account>? accounts, Failure? failure})> getAccounts() async {
    final result = await _remote.getAccounts();

    final accounts = result.accounts;
    if (accounts != null) {
      await _save(accounts);
      return result;
    }

    if (canServeFromCache(result.failure)) {
      final cached = await _load();
      if (cached != null) return (accounts: cached, failure: null);
    }
    return result;
  }

  Future<void> _save(List<Account> accounts) async {
    try {
      await _cache.write(
        cacheKey,
        jsonEncode(accounts.map(accountToJson).toList()),
      );
    } catch (_) {
      // Sin caché la app sigue funcionando.
    }
  }

  Future<StaleList<Account>?> _load() async {
    try {
      final entry = await _cache.read(cacheKey);
      if (entry == null) return null;
      final accounts = (jsonDecode(entry.value) as List)
          .cast<Map<String, dynamic>>()
          .map(accountFromJson)
          .toList();
      return StaleList<Account>(accounts, entry.savedAt);
    } catch (_) {
      return null; // copia ilegible: se trata como si no existiera
    }
  }
}
