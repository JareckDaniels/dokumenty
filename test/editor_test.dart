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
