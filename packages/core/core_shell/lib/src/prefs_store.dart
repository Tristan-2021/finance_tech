import 'package:flutter/services.dart';

/// 기기 내 화면 설정(쉬운 화면, 큰 글씨 등) 및 역할 영구 저장소.
abstract interface class LocalPrefsStore {
  Future<Map<String, Object?>> load();
  Future<void> saveBool(String key, bool value);
  Future<void> saveString(String key, String value);
  Future<void> clear();
}

Map<String, Object?> _parsePrefsMap(Map<String, dynamic> raw) {
  final parsed = <String, Object?>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is bool || value is String) {
      parsed[entry.key] = value;
    }
  }
  return parsed;
}

/// 테스트·기본용 메모리 저장소.
class MemoryPrefsStore implements LocalPrefsStore {
  final Map<String, Object?> _values;

  MemoryPrefsStore([Map<String, Object?>? initial]) : _values = Map<String, Object?>.from(initial ?? const {});

  @override
  Future<Map<String, Object?>> load() async => Map<String, Object?>.from(_values);

  @override
  Future<void> saveBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> saveString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }
}

/// Android SharedPreferences 채널(`kr.fingersnap.fingerbell/prefs`)로 저장하는 구현.
/// 채널이 없는 환경(테스트·데스크톱)에서는 예외를 삼키고 메모리 사본으로 동작합니다.
class MethodChannelPrefsStore implements LocalPrefsStore {
  static const defaultChannel = MethodChannel('kr.fingersnap.fingerbell/prefs');

  final MethodChannel channel;
  final Map<String, Object?> _fallback = {};

  MethodChannelPrefsStore({this.channel = defaultChannel});

  @override
  Future<Map<String, Object?>> load() async {
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>('getAll');
      if (raw != null) {
        final parsed = _parsePrefsMap(raw);
        _fallback
          ..clear()
          ..addAll(parsed);
        return parsed;
      }
    } catch (_) {}
    return Map<String, Object?>.from(_fallback);
  }

  @override
  Future<void> saveBool(String key, bool value) async {
    _fallback[key] = value;
    try {
      await channel.invokeMethod<void>('setBool', {'key': key, 'value': value});
    } catch (_) {}
  }

  @override
  Future<void> saveString(String key, String value) async {
    _fallback[key] = value;
    try {
      await channel.invokeMethod<void>('setString', {'key': key, 'value': value});
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    _fallback.clear();
    try {
      await channel.invokeMethod<void>('clear');
    } catch (_) {}
  }
}

/// 핑거벨 앱의 ContentProvider에서 공유 역할·설정을 읽기 전용으로 가져오는 저장소.
/// 앱이 없거나 읽기에 실패하면 빈 맵을 돌려주어 기본값으로 동작합니다.
class ProviderPrefsStore implements LocalPrefsStore {
  static const defaultChannel = MethodChannel('kr.fingersnap.fingerbell/shared_prefs');

  final MethodChannel channel;

  ProviderPrefsStore({this.channel = defaultChannel});

  @override
  Future<Map<String, Object?>> load() async {
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>('getAll');
      if (raw == null) return const {};
      return _parsePrefsMap(raw);
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<void> saveBool(String key, bool value) =>
      Future<void>.error(UnsupportedError('공유 설정은 핑거벨 앱에서만 바꿀 수 있습니다.'));

  @override
  Future<void> saveString(String key, String value) =>
      Future<void>.error(UnsupportedError('공유 설정은 핑거벨 앱에서만 바꿀 수 있습니다.'));

  @override
  Future<void> clear() =>
      Future<void>.error(UnsupportedError('공유 설정은 핑거벨 앱에서만 바꿀 수 있습니다.'));
}
