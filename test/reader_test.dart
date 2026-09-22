import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokumenty/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('dokumenty/files');
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, null);
  });

  testWidgets('Anulowanie wyboru pozostawia ekran startowy', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (_) async => null);
    await tester.pumpWidget(const DokumentyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otwórz plik'));
    await tester.pumpAndSettle();
    expect(find.text('Twoje pliki.\nPo prostu otwórz.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Plik przekazany przez Androida otwiera sie z polskimi znakami', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'initialUri') return 'content://test/tekst.txt';
          if (call.method == 'open') {
            expect(call.arguments['uri'], 'content://test/tekst.txt');
            return {
              'kind': 'text',
              'name': 'Tekst.txt',
              'text': 'Zażółć gęślą jaźń',
              'extension': 'txt',
            };
          }
          return null;
        });
    await tester.pumpWidget(const DokumentyApp());
    await tester.pumpAndSettle();
    expect(find.text('Tekst.txt'), findsOneWidget);
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.textSpan!.toPlainText(), 'Zażółć gęślą jaźń');
    await tester.tap(find.byTooltip('Zamknij dokument'));
    await tester.pumpAndSettle();
    expect(find.text('Otwórz plik'), findsOneWidget);
  });

  testWidgets('Blad silnika jest widoczny i pozwala wybrac inny plik', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'initialUri') return 'content://test/plik.odt';
          if (call.method == 'open')
            throw PlatformException(
              code: 'DOCUMENT_ERROR',
              message: 'Plik jest uszkodzony.',
            );
          return null;
        });
    await tester.pumpWidget(const DokumentyApp());
    await tester.pumpAndSettle();
    expect(find.text('Plik jest uszkodzony.'), findsOneWidget);
    expect(find.text('Otwórz plik'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
