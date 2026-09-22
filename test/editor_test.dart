import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokumenty/document_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dokumenty/files');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  testWidgets('Blad zapisu TXT zachowuje tresc i pozwala ponowic zapis', (
    tester,
  ) async {
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'saveEdited') {
            attempts++;
            expect(call.arguments['text'], 'Poprawiona treść');
            if (attempts == 1) {
              throw PlatformException(code: 'SAVE', message: 'Brak miejsca');
            }
          }
          return null;
        });
    await tester.pumpWidget(
      const MaterialApp(home: DocumentEditor(format: 'txt')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-text')),
      'Poprawiona treść',
    );
    await tester.tap(find.text('Zapisz jako'));
    await tester.pumpAndSettle();
    expect(find.text('Brak miejsca'), findsOneWidget);
    expect(find.text('Poprawiona treść'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Zapisz jako'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Brak miejsca'), findsNothing);
    expect(find.text('Poprawiona treść'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Edycja TXT zmienia istniejacy tekst i zachowuje zmiany po anulowaniu zapisu',
    (tester) async {
      Map<dynamic, dynamic>? saved;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'saveEdited') saved = call.arguments as Map;
            return null; // User cancels Android's save dialog.
          });
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentEditor(
            format: 'txt',
            document: {
              'name': 'Umowa.txt',
              'documentId': 27,
              'text': 'Pierwotne zdanie',
            },
          ),
        ),
      );
      expect(find.text('Pierwotne zdanie'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('editor-text')),
        'Zażółć 😀',
      );
      await tester.tap(find.text('Zapisz jako'));
      await tester.pumpAndSettle();
      expect(saved?['text'], 'Zażółć 😀');
      expect(saved?['createNew'], false);
      expect(saved?['documentId'], 27);
      expect(saved?['filename'], 'Umowa-edycja.txt');
      expect(find.text('Zażółć 😀'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
