import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('goto keeps prefs, resets filters and closes sheets', () {
    final shell = ShellCubit()
      ..togglePref(PrefKey.largeText)
      ..setTxFilter('in')
      ..showSos('senior');
    final before = shell.state.closeSheetsTick;
    shell.goto(Persona.guardian, AppTab.history);
    expect(shell.state.persona, Persona.guardian);
    expect(shell.state.tab, AppTab.history);
    expect(shell.state.txFilter, 'all');
    expect(shell.state.sosMemberId, isNull);
    expect(shell.state.prefs.largeText, isTrue);
    expect(shell.state.closeSheetsTick, before + 1);
  });

  test('feedback requests are streamed', () async {
    final shell = ShellCubit();
    final next = shell.feedback.first;
    shell.say('보호자에게 알렸어요', vibrate: const [200, 100, 200]);
    final f = await next;
    expect(f.message, '보호자에게 알렸어요');
    expect(f.vibrate, [200, 100, 200]);
    await shell.close();
  });

  test('reset goes back to the senior home with default prefs', () {
    final shell = ShellCubit()
      ..goto(Persona.child, AppTab.settings)
      ..togglePref(PrefKey.highContrast)
      ..reset();
    expect(shell.state.persona, Persona.senior);
    expect(shell.state.tab, AppTab.home);
    expect(shell.state.prefs.highContrast, isFalse);
  });

  test('switching away from the guardian moves the alerts tab to history', () {
    final shell = ShellCubit()..goto(Persona.guardian, AppTab.alerts);
    expect(shell.state.tab, AppTab.alerts);
    shell.goto(Persona.senior);
    expect(shell.state.tab, AppTab.history);
  });

  test('easy mode and prompt state persist and restore via LocalPrefsStore', () async {
    final store = MemoryPrefsStore();
    final first = ShellCubit(const ShellState(), store);
    await first.loadPrefs();
    expect(first.state.prefs.easyMode, isFalse);
    expect(first.state.prefs.easyModePrompted, isFalse);

    first.setEasyMode(true);
    expect(first.state.prefs.easyMode, isTrue);
    expect(first.state.prefs.easyModePrompted, isTrue);
    await first.close();

    final second = ShellCubit(const ShellState(), store);
    await second.loadPrefs();
    expect(second.state.prefs.easyMode, isTrue);
    expect(second.state.prefs.easyModePrompted, isTrue);

    second.answerEasyModePrompt(false);
    await second.close();

    final third = ShellCubit(const ShellState(), store);
    await third.loadPrefs();
    expect(third.state.prefs.easyMode, isFalse);
    expect(third.state.prefs.easyModePrompted, isTrue);

    third.reset();
    await third.close();

    final fourth = ShellCubit(const ShellState(), store);
    await fourth.loadPrefs();
    expect(fourth.state.prefs.easyMode, isFalse);
    expect(fourth.state.prefs.easyModePrompted, isFalse);
    await fourth.close();
  });

  test('persona persists, restores, falls back on invalid value, and clears on reset', () async {
    final store = MemoryPrefsStore();
    final first = ShellCubit(const ShellState(), store);
    await first.loadPrefs();
    expect(first.state.persona, Persona.senior);

    first.goto(Persona.guardian, AppTab.alerts);
    expect(first.state.persona, Persona.guardian);
    await first.close();

    final second = ShellCubit(const ShellState(), store);
    await second.loadPrefs();
    expect(second.state.persona, Persona.guardian);
    second.reset();
    await second.close();

    final third = ShellCubit(const ShellState(), store);
    await third.loadPrefs();
    expect(third.state.persona, Persona.senior);
    await third.close();

    final invalid = ShellCubit(const ShellState(), MemoryPrefsStore({'persona': 'unknown'}));
    await invalid.loadPrefs();
    expect(invalid.state.persona, Persona.senior);
    await invalid.close();
  });

  test('MethodChannelPrefsStore saves and loads persona string and bool prefs', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('test/prefs');
    final backing = <String, Object?>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        switch (call.method) {
          case 'getAll':
            return Map<String, Object?>.from(backing);
          case 'setBool':
          case 'setString':
            final args = Map<Object?, Object?>.from(call.arguments as Map);
            backing[args['key'] as String] = args['value'];
            return null;
          case 'clear':
            backing.clear();
            return null;
        }
        return null;
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final store = MethodChannelPrefsStore(channel: channel);
    final first = ShellCubit(const ShellState(), store);
    first.goto(Persona.child);
    first.setPref(PrefKey.highContrast, true);
    await Future<void>.delayed(Duration.zero);
    await first.close();

    final second = ShellCubit(const ShellState(), store);
    await second.loadPrefs();
    expect(second.state.persona, Persona.child);
    expect(second.state.prefs.highContrast, isTrue);
    await second.close();
  });

  test('ProviderPrefsStore reads shared map, returns empty on failure, and rejects writes', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('test/shared_prefs');
    var shouldFail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (shouldFail) {
          throw PlatformException(code: 'unavailable', message: 'provider missing');
        }
        return <String, Object?>{'persona': 'guardian', 'largeText': true, 'highContrast': true};
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final store = ProviderPrefsStore(channel: channel);
    expect(await store.load(), {'persona': 'guardian', 'largeText': true, 'highContrast': true});

    shouldFail = true;
    expect(await store.load(), isEmpty);

    await expectLater(store.saveBool('largeText', true), throwsUnsupportedError);
    await expectLater(store.saveString('persona', 'senior'), throwsUnsupportedError);
    await expectLater(store.clear(), throwsUnsupportedError);
  });
}
