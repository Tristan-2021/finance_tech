import 'package:core_errors/core_errors.dart';

/// Filtro de privacidad: lo único que sale de la app hacia Analytics y
/// Crashlytics pasa por aquí. Lista cerrada de claves; valores solo texto
/// corto, número o booleano; todo lo demás se descarta.
abstract final class TelemetrySanitizer {
  /// Únicas claves de parámetros permitidas. Nunca correos, nombres, saldos,
  /// montos ni descripciones.
  static const allowedKeys = <String>{
    'screen',
    'step',
    'code',
    'segment',
    'block_id',
    'block_type',
    'source',
    'result',
    'count',
    'duration_ms',
  };

  static const maxTextLength = 100;
  static const maxEventNameLength = 40;

  static final _eventNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');

  /// El nombre si es `snake_case` válido (máx. 40 caracteres); si no, `null`
  /// y el evento no se envía.
  static String? eventName(String name) {
    if (name.isEmpty || name.length > maxEventNameLength) return null;
    return _eventNamePattern.hasMatch(name) ? name : null;
  }

  /// Texto corto (máx. 100 caracteres). Un texto con `@` podría ser un correo:
  /// se descarta (`null`).
  static String? text(String value) {
    if (value.contains('@')) return null;
    return value.length > maxTextLength
        ? value.substring(0, maxTextLength)
        : value;
  }

  /// Solo las claves permitidas, con valores de texto corto, número finito o
  /// booleano.
  static Map<String, Object> params(Map<String, Object?> input) {
    final out = <String, Object>{};
    for (final entry in input.entries) {
      if (!allowedKeys.contains(entry.key)) continue;
      final value = switch (entry.value) {
        final String s => text(s),
        final int n => n,
        final double d when d.isFinite => d,
        final bool b => b,
        _ => null,
      };
      if (value != null) out[entry.key] = value;
    }
    return out;
  }
}

/// Lo que se envía a Crashlytics en lugar del error original: solo el nombre
/// del tipo y, si es un `Failure`, su **código**. Nunca el mensaje, que puede
/// contener datos del usuario.
class SanitizedError implements Exception {
  final String type;
  final String? code;

  const SanitizedError(this.type, [this.code]);

  factory SanitizedError.from(Object error) {
    if (error is Failure) {
      final code = error.code;
      return SanitizedError(
        'Failure',
        code == null ? null : TelemetrySanitizer.text(code),
      );
    }
    return SanitizedError(error.runtimeType.toString());
  }

  @override
  String toString() => code == null ? type : '$type (code: $code)';
}
