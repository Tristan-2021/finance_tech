import 'dart:async';

import 'package:core_errors/core_errors.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/domain/movement_write_repository.dart';
import 'package:feature_accounts/src/presentation/add_movement_cubit.dart';
import 'package:feature_accounts/src/presentation/add_movement_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWriteRepository implements MovementWriteRepository {
  Failure? failure;
  Completer<Failure?>? hold;
  final calls = <({
    String accountId,
    TransactionType type,
    int cents,
    String category,
    String description,
  })>[];

  @override
  Future<Failure?> addMovement({
    required String accountId,
    required TransactionType type,
    required int amountCents,
    required String category,
    required String description,
  }) {
    calls.add((
      accountId: accountId,
      type: type,
      cents: amountCents,
      category: category,
      description: description,
    ));
    return hold?.future ?? Future.value(failure);
  }
}

class FakeTelemetry implements Telemetry {
  final events = <({String name, Map<String, Object?> params})>[];

  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) =>
      events.add((name: name, params: params));

  @override
  void recordError(Object error, StackTrace stack, {bool fatal = false, String? reason}) {}

  @override
  void setSegment(String? segment) {}

  @override
  Future<T> trace<T>(String name, Future<T> Function() action) => action();
}

void main() {
  late FakeWriteRepository repo;
  late FakeTelemetry telemetry;
  late AddMovementCubit cubit;

  setUp(() {
    repo = FakeWriteRepository();
    telemetry = FakeTelemetry();
    cubit = AddMovementCubit(AddMovement(repo), 'a1', telemetry: telemetry);
  });
  tearDown(() => cubit.close());

  Future<void> submit({
    String amount = '12,30',
    TransactionType type = TransactionType.debit,
    String category = 'comida',
    String description = '',
  }) => cubit.submit(
    amountText: amount,
    type: type,
    category: category,
    description: description,
  );

  group('validación: no envía nada si es inválido', () {
    test('vacío, cero y más de dos decimales', () async {
      await submit(amount: '');
      expect(cubit.state.amountError, 'Escribe un monto.');
      await submit(amount: '0');
      expect(cubit.state.amountError, 'El monto debe ser mayor que cero.');
      await submit(amount: '1.234');
      expect(cubit.state.amountError, 'Usa como máximo dos decimales.');
      await submit(amount: 'abc');
      expect(cubit.state.amountError, 'Escribe un monto válido, por ejemplo 12,50.');
      expect(repo.calls, isEmpty);
      expect(telemetry.events, isEmpty);
    });

    test('descripción de más de 80 caracteres', () async {
      await submit(description: 'x' * 81);
      expect(cubit.state.descriptionError, 'Máximo 80 caracteres.');
      expect(repo.calls, isEmpty);

      await submit(description: 'x' * 80);
      expect(repo.calls, hasLength(1));
    });
  });

  group('envío', () {
    test('éxito: llama al repositorio con centavos exactos y avisa', () async {
      await submit(description: '  Almuerzo  ');

      expect(repo.calls.single, (
        accountId: 'a1',
        type: TransactionType.debit,
        cents: 1230,
        category: 'comida',
        description: 'Almuerzo',
      ));
      expect(cubit.state.status, AddMovementStatus.success);
      expect(telemetry.events.single.name, 'movement_added');
      expect(telemetry.events.single.params, {'result': 'ok'});
    });

    test('sin descripción usa el texto por defecto según el tipo', () async {
      await submit();
      expect(repo.calls.last.description, 'Gasto manual');

      await submit(type: TransactionType.credit, category: 'ingreso');
      expect(repo.calls.last.description, 'Ingreso manual');
      expect(repo.calls.last.type, TransactionType.credit);
    });

    test('insufficient_funds muestra "Saldo insuficiente."', () async {
      repo.failure = const Failure('x', 'insufficient_funds');
      await submit();
      expect(cubit.state.status, AddMovementStatus.error);
      expect(cubit.state.message, 'Saldo insuficiente.');
      expect(telemetry.events.single.params, {
        'result': 'error',
        'code': 'insufficient_funds',
      });
    });

    test('sin conexión muestra un mensaje claro', () async {
      repo.failure = const Failure('x', 'network');
      await submit();
      expect(
        cubit.state.message,
        'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
      );
    });

    test('la telemetría nunca lleva importes', () async {
      await submit(amount: '999,99');
      repo.failure = const Failure('x', 'network');
      await submit(amount: '999,99');
      for (final event in telemetry.events) {
        expect(event.params.keys, everyElement(isIn(['result', 'code'])));
        expect(event.params.values.join(), isNot(contains('999')));
      }
    });

    test('un segundo envío mientras se envía se ignora', () async {
      repo.hold = Completer<Failure?>();
      final first = submit();
      await pumpEventQueue();
      expect(cubit.state.isSubmitting, isTrue);

      await submit();
      expect(repo.calls, hasLength(1));

      repo.hold!.complete(null);
      await first;
      expect(cubit.state.status, AddMovementStatus.success);
    });

    test('tras un error se puede reintentar y salir bien', () async {
      repo.failure = const Failure('x', 'network');
      await submit();
      expect(cubit.state.status, AddMovementStatus.error);

      repo.failure = null;
      await submit();
      expect(cubit.state.status, AddMovementStatus.success);
      expect(cubit.state.message, isNull);
    });
  });
}
