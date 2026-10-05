import 'package:core_errors/core_errors.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TelemetrySanitizer.params', () {
    test('conserva solo las claves permitidas', () {
      final result = TelemetrySanitizer.params({
        'screen': 'home',
        'segment': 'joven',
        'block_id': 'tip_ahorro',
        'count': 3,
      });

      expect(result, {
        'screen': 'home',
        'segment': 'joven',
        'block_id': 'tip_ahorro',
        'count': 3,
      });
    });

    test('descarta correo, nombre, saldo, monto y descripción', () {
      final result = TelemetrySanitizer.params({
        'email': 'ana@example.com',
        'full_name': 'Ana Pérez',
        'balance': 123456,
        'saldo': 1234.56,
        'amount': 5000,
        'description': 'Transferencia a Juan',
        'screen': 'home',
      });

      expect(result, {'screen': 'home'});
    });

    test('acepta texto, enteros, decimales y booleanos', () {
      final result = TelemetrySanitizer.params({
        'screen': 'login',
        'count': 2,
        'duration_ms': 12.5,
        'result': true,
      });

      expect(result, {
        'screen': 'login',
        'count': 2,
        'duration_ms': 12.5,
        'result': true,
      });
    });

    test('descarta valores de otros tipos y números no finitos', () {
      final result = TelemetrySanitizer.params({
        'screen': ['home'],
        'step': {'a': 1},
        'source': DateTime(2026),
        'code': null,
        'count': double.nan,
        'duration_ms': double.infinity,
        'result': Object(),
      });

      expect(result, isEmpty);
    });

    test('trunca los textos a 100 caracteres', () {
      final result = TelemetrySanitizer.params({'screen': 'a' * 250});
      expect((result['screen'] as String).length, 100);
    });

    test('descarta un texto que parece un correo, incluso en una clave permitida', () {
      final result = TelemetrySanitizer.params({
        'screen': 'ana@example.com',
        'source': 'login',
      });
      expect(result, {'source': 'login'});
    });
  });

  group('TelemetrySanitizer.eventName', () {
    test('acepta snake_case válido', () {
      expect(TelemetrySanitizer.eventName('block_viewed'), 'block_viewed');
      expect(TelemetrySanitizer.eventName('login_ok'), 'login_ok');
    });

    test('rechaza mayúsculas, espacios, guiones y arranque numérico', () {
      expect(TelemetrySanitizer.eventName('BlockViewed'), isNull);
      expect(TelemetrySanitizer.eventName('block viewed'), isNull);
      expect(TelemetrySanitizer.eventName('block-viewed'), isNull);
      expect(TelemetrySanitizer.eventName('1_evento'), isNull);
      expect(TelemetrySanitizer.eventName('_evento'), isNull);
    });

    test('rechaza vacío y más de 40 caracteres', () {
      expect(TelemetrySanitizer.eventName(''), isNull);
      expect(TelemetrySanitizer.eventName('a' * 40), 'a' * 40);
      expect(TelemetrySanitizer.eventName('a' * 41), isNull);
    });
  });

  group('SanitizedError (lo que llega a Crashlytics)', () {
    test('un Failure envía su código y nunca su mensaje', () {
      final text = SanitizedError.from(
        const Failure('Saldo de Ana Pérez: 1234.56', 'insufficient_funds'),
      ).toString();

      expect(text, 'Failure (code: insufficient_funds)');
      expect(text, isNot(contains('Ana')));
      expect(text, isNot(contains('1234')));
    });

    test('otro error envía solo el nombre del tipo', () {
      final text = SanitizedError.from(
        const FormatException('correo ana@example.com no válido'),
      ).toString();

      expect(text, 'FormatException');
      expect(text, isNot(contains('ana@')));
    });

    test('un Failure sin código envía solo el tipo', () {
      expect(SanitizedError.from(const Failure('algo')).toString(), 'Failure');
    });

    test('un código con aspecto de correo se descarta', () {
      final text = SanitizedError.from(
        const Failure('x', 'ana@example.com'),
      ).toString();
      expect(text, 'Failure');
    });
  });

  group('NoopTelemetry', () {
    const telemetry = NoopTelemetry();

    test('no hace nada y no falla', () {
      telemetry.logEvent('screen_viewed', {'screen': 'home'});
      telemetry.setSegment('joven');
      telemetry.recordError(StateError('x'), StackTrace.current);
    });

    test('trace ejecuta la acción y devuelve su resultado', () async {
      final result = await telemetry.trace('cargar_cuentas', () async => 42);
      expect(result, 42);
    });

    test('trace deja pasar los errores de la acción', () async {
      await expectLater(
        telemetry.trace<void>('cargar_cuentas', () async {
          throw StateError('x');
        }),
        throwsStateError,
      );
    });
  });
}
