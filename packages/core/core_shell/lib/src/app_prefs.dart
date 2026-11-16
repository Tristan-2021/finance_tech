/// 설정 화면의 켜고 끄는 항목.
enum PrefKey { largeText, highContrast, voice, sound, haptics, shake, hideBalance, easyMode, easyModePrompted }

/// 취약계층 맞춤 화면 설정 (기획서 5.10, 7.1, 7.3).
class AppPrefs {
  final bool largeText;
  final bool highContrast;
  final bool voice;
  final bool sound;
  final bool haptics;
  final bool shake;
  final bool hideBalance;
  final bool easyMode;
  final bool easyModePrompted;

  const AppPrefs({
    this.largeText = false,
    this.highContrast = false,
    this.voice = false,
    this.sound = true,
    this.haptics = true,
    this.shake = true,
    this.hideBalance = false,
    this.easyMode = false,
    this.easyModePrompted = false,
  });

  bool operator [](PrefKey key) => switch (key) {
    PrefKey.largeText => largeText,
    PrefKey.highContrast => highContrast,
    PrefKey.voice => voice,
    PrefKey.sound => sound,
    PrefKey.haptics => haptics,
    PrefKey.shake => shake,
    PrefKey.hideBalance => hideBalance,
    PrefKey.easyMode => easyMode,
    PrefKey.easyModePrompted => easyModePrompted,
  };

  AppPrefs set(PrefKey key, bool value) => AppPrefs(
    largeText: key == PrefKey.largeText ? value : largeText,
    highContrast: key == PrefKey.highContrast ? value : highContrast,
    voice: key == PrefKey.voice ? value : voice,
    sound: key == PrefKey.sound ? value : sound,
    haptics: key == PrefKey.haptics ? value : haptics,
    shake: key == PrefKey.shake ? value : shake,
    hideBalance: key == PrefKey.hideBalance ? value : hideBalance,
    easyMode: key == PrefKey.easyMode ? value : easyMode,
    easyModePrompted: key == PrefKey.easyModePrompted ? value : easyModePrompted,
  );

  static AppPrefs fromMap(Map<String, Object?> map) {
    var next = const AppPrefs();
    for (final key in PrefKey.values) {
      final v = map[key.name];
      if (v is bool) next = next.set(key, v);
    }
    return next;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppPrefs &&
          largeText == other.largeText &&
          highContrast == other.highContrast &&
          voice == other.voice &&
          sound == other.sound &&
          haptics == other.haptics &&
          shake == other.shake &&
          hideBalance == other.hideBalance &&
          easyMode == other.easyMode &&
          easyModePrompted == other.easyModePrompted;

  @override
  int get hashCode => Object.hash(
    largeText,
    highContrast,
    voice,
    sound,
    haptics,
    shake,
    hideBalance,
    easyMode,
    easyModePrompted,
  );
}
