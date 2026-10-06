import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:get_it/get_it.dart';

import 'data/account_repository_impl.dart';
import 'data/accounts_remote_data_source.dart';
import 'data/cached_account_repository.dart';
import 'data/cached_transaction_repository.dart';
import 'data/movement_write_remote_data_source.dart';
import 'data/movement_write_repository_impl.dart';
import 'data/supabase_accounts_remote_data_source.dart';
import 'data/supabase_movement_write_remote_data_source.dart';
import 'data/supabase_transactions_remote_data_source.dart';
import 'data/transaction_repository_impl.dart';
import 'data/transactions_remote_data_source.dart';
import 'domain/account_repository.dart';
import 'domain/add_movement.dart';
import 'domain/get_accounts.dart';
import 'domain/get_balance.dart';
import 'domain/get_transactions.dart';
import 'domain/movement_write_repository.dart';
import 'domain/transaction_repository.dart';
import 'presentation/accounts_cubit.dart';
import 'presentation/add_movement_cubit.dart';
import 'presentation/movements_cubit.dart';

/// Registra en [getIt] data sources, repositorios, casos de uso (singletons
/// perezosos) y las fábricas de Cubit del feature.
///
/// Asume que un `SupabaseClient` ya está registrado en [getIt]. Si además hay
/// un [CacheStore] registrado, los repositorios guardan y sirven copias
/// (*cache-then-network*); si no, funcionan solo contra el servidor. Si hay un
/// `Telemetry` registrado, miden las cargas y emiten los eventos de estados
/// degradados (`cache_served`, `retry_exhausted`).
void registerAccountsDependencies(GetIt getIt) {
  Telemetry telemetry() =>
      getIt.isRegistered<Telemetry>() ? getIt<Telemetry>() : const NoopTelemetry();

  getIt
    ..registerLazySingleton<AccountsRemoteDataSource>(
      () => SupabaseAccountsRemoteDataSource(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<AccountRepository>(() {
      final AccountRepository remote = AccountRepositoryImpl(
        getIt<AccountsRemoteDataSource>(),
        telemetry: telemetry(),
      );
      return getIt.isRegistered<CacheStore>()
          ? CachedAccountRepository(
              remote,
              getIt<CacheStore>(),
              telemetry: telemetry(),
            )
          : remote;
    })
    ..registerLazySingleton<TransactionsRemoteDataSource>(
      () => SupabaseTransactionsRemoteDataSource(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<TransactionRepository>(() {
      final TransactionRepository remote = TransactionRepositoryImpl(
        getIt<TransactionsRemoteDataSource>(),
        telemetry: telemetry(),
      );
      return getIt.isRegistered<CacheStore>()
          ? CachedTransactionRepository(
              remote,
              getIt<CacheStore>(),
              telemetry: telemetry(),
            )
          : remote;
    })
    ..registerLazySingleton<GetAccounts>(
      () => GetAccounts(getIt<AccountRepository>()),
    )
    ..registerLazySingleton<GetBalance>(
      () => GetBalance(getIt<AccountRepository>()),
    )
    ..registerLazySingleton<GetTransactions>(
      () => GetTransactions(getIt<TransactionRepository>()),
    )
    ..registerFactory<AccountsCubit>(
      () => AccountsCubit(getIt<GetAccounts>()),
    )
    ..registerLazySingleton<MovementsCubitFactory>(
      () =>
          (accountId) => MovementsCubit(getIt<GetTransactions>(), accountId),
    )
    ..registerLazySingleton<MovementWriteRemoteDataSource>(
      () => SupabaseMovementWriteRemoteDataSource(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<MovementWriteRepository>(
      () => MovementWriteRepositoryImpl(getIt<MovementWriteRemoteDataSource>()),
    )
    ..registerLazySingleton<AddMovement>(
      () => AddMovement(getIt<MovementWriteRepository>()),
    )
    ..registerLazySingleton<AddMovementCubitFactory>(
      () =>
          (accountId) => AddMovementCubit(
            getIt<AddMovement>(),
            accountId,
            telemetry: telemetry(),
          ),
    );
}
