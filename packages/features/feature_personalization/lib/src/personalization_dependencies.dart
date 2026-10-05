import 'package:core_network/core_network.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:get_it/get_it.dart';

import 'data/home_layout_repository_impl.dart';
import 'data/layout_source.dart';
import 'data/spending_repository_impl.dart';
import 'domain/get_spending_summary.dart';
import 'domain/home_layout_repository.dart';
import 'domain/layout_use_cases.dart';
import 'domain/spending_repository.dart';
import 'presentation/home_cubit.dart';
import 'presentation/spending_cubit.dart';

/// Registra en [getIt] las fuentes, repositorios, casos de uso y fábricas de
/// Cubit del feature.
///
/// Asume que un `SupabaseClient` ya está registrado. Si hay un [Telemetry]
/// registrado lo usa para `block_viewed`; si no, no registra nada. Remote
/// Config se obtiene al usarse: si Firebase no arrancó, la app sigue con el
/// layout embebido.
void registerPersonalizationDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<LayoutSource>(
      () => RemoteConfigLayoutSource(() => FirebaseRemoteConfig.instance),
    )
    ..registerLazySingleton<HomeLayoutRepository>(
      () => HomeLayoutRepositoryImpl(getIt<LayoutSource>()),
    )
    ..registerLazySingleton<SpendingRepository>(
      () => SpendingRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<GetHomeLayout>(
      () => GetHomeLayout(getIt<HomeLayoutRepository>()),
    )
    ..registerLazySingleton<RefreshHomeLayout>(
      () => RefreshHomeLayout(getIt<HomeLayoutRepository>()),
    )
    ..registerLazySingleton<WatchHomeLayout>(
      () => WatchHomeLayout(getIt<HomeLayoutRepository>()),
    )
    ..registerLazySingleton<GetSpendingSummary>(
      () => GetSpendingSummary(getIt<SpendingRepository>()),
    )
    ..registerFactoryParam<HomeCubit, String, void>(
      (segment, _) => HomeCubit(
        getIt<GetHomeLayout>(),
        getIt<RefreshHomeLayout>(),
        getIt<WatchHomeLayout>(),
        getIt.isRegistered<Telemetry>()
            ? getIt<Telemetry>()
            : const NoopTelemetry(),
        segment,
      ),
    )
    ..registerFactory<SpendingCubit>(
      () => SpendingCubit(getIt<GetSpendingSummary>()),
    );
}
