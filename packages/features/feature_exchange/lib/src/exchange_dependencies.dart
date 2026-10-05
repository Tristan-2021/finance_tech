import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import 'data/cached_exchange_rate_repository.dart';
import 'data/exchange_rate_remote_data_source.dart';
import 'data/exchange_rate_repository_impl.dart';
import 'domain/exchange_rate_repository.dart';
import 'domain/get_rate.dart';
import 'presentation/exchange_cubit.dart';

/// Registra en [getIt] la fuente de tasas, el repositorio, el caso de uso y la
/// fábrica del Cubit.
///
/// [httpClient] lo pone el shell: en debug es el que inyecta fallos, así la
/// demostración de conectividad cubre también este servicio. Aquí se envuelve
/// con `buildRetryClient` (3 reintentos con backoff).
///
/// Si hay un `CacheStore` registrado, la tasa se guarda y se sirve la última
/// guardada cuando no hay red; si hay un `NetworkStatusNotifier`, se le avisa
/// de los reintentos.
void registerExchangeDependencies(
  GetIt getIt, {
  required http.Client httpClient,
}) {
  getIt
    ..registerLazySingleton<ExchangeRateRemoteDataSource>(
      () => FrankfurterDataSource(
        buildRetryClient(
          httpClient,
          null,
          getIt.isRegistered<NetworkStatusNotifier>()
              ? getIt<NetworkStatusNotifier>()
              : null,
        ),
      ),
    )
    ..registerLazySingleton<ExchangeRateRepository>(() {
      final ExchangeRateRepository remote = ExchangeRateRepositoryImpl(
        getIt<ExchangeRateRemoteDataSource>(),
      );
      return getIt.isRegistered<CacheStore>()
          ? CachedExchangeRateRepository(remote, getIt<CacheStore>())
          : remote;
    })
    ..registerLazySingleton<GetRate>(
      () => GetRate(getIt<ExchangeRateRepository>()),
    )
    ..registerFactoryParam<ExchangeCubit, String, String>(
      (from, to) => ExchangeCubit(getIt<GetRate>(), from: from, to: to),
    );
}
