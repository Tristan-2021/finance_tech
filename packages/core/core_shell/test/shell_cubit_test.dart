import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
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
}
