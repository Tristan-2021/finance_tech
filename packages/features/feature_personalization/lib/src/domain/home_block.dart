import 'block_type.dart';

/// Un bloque del home tal como lo describe el JSON de Remote Config.
class HomeBlock {
  final String id;
  final BlockType type;
  final Map<String, Object?> params;

  const HomeBlock({
    required this.id,
    required this.type,
    this.params = const {},
  });

  String? stringParam(String key) {
    final value = params[key];
    return value is String ? value : null;
  }

  int? intParam(String key) {
    final value = params[key];
    return value is int ? value : null;
  }
}
