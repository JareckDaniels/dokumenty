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

  testWidgets(
    'Zewnetrzny dokument wraca bez ekranu glownego po gescie wstecz',
    (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bridge, (call) async {
            calls.add(call.method);
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
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(calls, contains('finishExternal'));
      expect(calls, isNot(contains('close')));
      expect(find.text('Otwórz plik'), findsNothing);
    },
  );

  testWidgets('Blad zewnetrznego dokumentu nie pokazuje ekranu glownego', (
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
    expect(find.text('Wróć'), findsOneWidget);
    expect(find.text('Otwórz plik'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets('Dokument wybrany w aplikacji wraca do listy ostatnich', (
    tester,
  ) async {
    final calls = <String>[];
    bool opened = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          calls.add(call.method);
          if (call.method == 'pick') return 'content://test/notatka.txt';
          if (call.method == 'open') {
            opened = true;
            return {
              'kind': 'text',
              'name': 'Notatka.txt',
              'text': 'Treść',
              'extension': 'txt',
            };
          }
          if (call.method == 'recent')
            return opened
                ? [
                    {
                      'name': 'Notatka.txt',
                      'extension': 'txt',
                      'uri': 'file:///private/recent.txt',
                      'openedAt': 0,
                    },
                  ]
                : [];
          return null;
        });
    await tester.pumpWidget(const DokumentyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otwórz plik'));
    await tester.pumpAndSettle();
    expect(find.text('Notatka.txt'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls, contains('close'));
    expect(calls, isNot(contains('finishExternal')));
    expect(find.text('Ostatnio otwierane'), findsOneWidget);
    expect(find.text('Notatka.txt'), findsOneWidget);
  });
}
