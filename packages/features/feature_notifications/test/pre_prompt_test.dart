import 'package:feature_notifications/feature_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool?> openAndTap(WidgetTester tester, String? label) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await showNotificationsPrePrompt(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Te avisaremos de tus movimientos.'), findsOneWidget);
    if (label != null) {
      await tester.tap(find.text(label));
    } else {
      await tester.tapAt(const Offset(2, 2)); // fuera del diálogo
    }
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('aceptar devuelve true', (tester) async {
    expect(await openAndTap(tester, 'Activar'), isTrue);
  });

  testWidgets('"Ahora no" devuelve false', (tester) async {
    expect(await openAndTap(tester, 'Ahora no'), isFalse);
  });

  testWidgets('cerrar tocando fuera devuelve false', (tester) async {
    expect(await openAndTap(tester, null), isFalse);
  });
}
