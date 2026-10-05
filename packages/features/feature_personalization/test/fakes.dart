import 'dart:async';

import 'package:core_errors/core_errors.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:feature_personalization/feature_personalization.dart';

HomeBlock block(String id, BlockType type, [Map<String, Object?> params = const {}]) =>
    HomeBlock(id: id, type: type, params: params);

class FakeLayoutRepository implements HomeLayoutRepository {
  HomeLayout layout;
  HomeLayout? refreshed;
  final controller = StreamController<HomeLayout>.broadcast();

  FakeLayoutRepository(this.layout);

  @override
  HomeLayout get current => layout;

  @override
  Future<HomeLayout> refresh() async {
    layout = refreshed ?? layout;
    return layout;
  }

  @override
  Stream<HomeLayout> get changes => controller.stream;
}

class FakeSpendingRepository implements SpendingRepository {
  SpendingSummary? summary;
  Failure? failure;
  int calls = 0;

  @override
  Future<({SpendingSummary? summary, Failure? failure})> getSpendingSummary({
    required int months,
  }) async {
    calls++;
    return (summary: summary, failure: failure);
  }
}

class FakeTelemetry implements Telemetry {
  final events = <({String name, Map<String, Object?> params})>[];

  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) =>
      events.add((name: name, params: params));

  @override
  void recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String? reason,
  }) {}

  @override
  void setSegment(String? segment) {}

  @override
  Future<T> trace<T>(String name, Future<T> Function() action) => action();
}
