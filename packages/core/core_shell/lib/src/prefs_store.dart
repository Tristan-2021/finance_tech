import 'package:flutter/services.dart';

/// 기기 내 화면 설정(쉬운 화면, 큰 글씨 등) 영구 저장소.
abstract interface class LocalPrefsStore {
  Future<Map<String, bool>> load();
  Future<void> saveBool(String key, bool value);
  Future<void> clear();
}

/// 테스트·기본용 메모리 저장소.
class MemoryPrefsStore implements LocalPrefsStore {
  final Map<String, bool> _values;

  MemoryPrefsStore([Map<String, bool>? initial]) : _values = Map<String, bool>.from(initial ?? const {});

  @override
  Future<Map<String, bool>> load() async => Map<String, bool>.from(_values);

  @override
  Future<void> saveBool(String key, bool value) async {
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
  final Map<String, bool> _fallback = {};

  MethodChannelPrefsStore({this.channel = defaultChannel});

  @override
  Future<Map<String, bool>> load() async {
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>('getAll');
      if (raw != null) {
        final parsed = <String, bool>{};
        for (final entry in raw.entries) {
          if (entry.value is bool) parsed[entry.key] = entry.value as bool;
        }
        _fallback
          ..clear()
          ..addAll(parsed);
        return parsed;
      }
    } catch (_) {}
    return Map<String, bool>.from(_fallback);
  }

  @override
  Future<void> saveBool(String key, bool value) async {
    _fallback[key] = value;
    try {
      await channel.invokeMethod<void>('setBool', {'key': key, 'value': value});
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
