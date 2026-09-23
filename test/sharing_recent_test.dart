import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokumenty/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('dokumenty/files');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFUlEQVR4nGP8//8/AwMDEwMDA4ICADkbAwP+wj6MAAAAAElFTkSuQmCC',
  );
  tearDown(() => messenger.setMockMethodCallHandler(bridge, null));

  for (final pdf in [false, true]) {
    testWidgets('Udostepnia DOCX: pdf=$pdf i pozostaje w czytniku', (tester) async {
      Map<dynamic, dynamic>? shared;
      messenger.setMockMethodCallHandler(bridge, (call) async {
        if (call.method == 'initialUri') return 'content://test/umowa.docx';
        if (call.method == 'open') {
          return {
            'kind': 'pdf', 'name': 'Umowa.docx', 'extension': 'docx',
            'documentId': 42, 'pages': 1, 'pageSizes': [[600, 800]],
          };
        }
        if (call.method == 'render') return png;
        if (call.method == 'share') shared = call.arguments as Map;
        return null;
      });
      await tester.pumpWidget(const DokumentyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Udostępnij dokument'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pdf ? 'Podgląd PDF' : 'Plik DOCX'));
      await tester.pumpAndSettle();
      expect(shared, {'documentId': 42, 'pdf': pdf});
      expect(find.text('Umowa.docx'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Anulowanie wyboru nie udostepnia i odblokowuje czytnik', (tester) async {
    int shares = 0;
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if (call.method == 'initialUri') return 'content://test/umowa.odt';
      if (call.method == 'open') {
        return {
          'kind': 'pdf', 'name': 'Umowa.odt', 'extension': 'odt',
          'documentId': 43, 'pages': 1, 'pageSizes': [[600, 800]],
        };
      }
      if (call.method == 'render') return png;
      if (call.method == 'share') shares++;
      return null;
    });
    await tester.pumpWidget(const DokumentyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Udostępnij dokument'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(shares, 0);
    expect(find.text('Umowa.odt'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.share_outlined)).onPressed, isNotNull);
  });

  testWidgets('Blad udostepnienia TXT zachowuje tresc i pozwala sprobowac ponownie', (tester) async {
    int shares = 0;
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if (call.method == 'initialUri') return 'content://test/tekst.txt';
      if (call.method == 'open') {
        return {'kind': 'text', 'name': 'Tekst.txt', 'extension': 'txt',
          'text': 'Ważna treść', 'documentId': 44};
      }
      if (call.method == 'share') {
        expect(call.arguments, {'documentId': 44, 'pdf': false});
        shares++;
        if (shares == 1) throw PlatformException(code: 'SHARE', message: 'Brak miejsca.');
      }
      return null;
    });
    await tester.pumpWidget(const DokumentyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Udostępnij dokument'));
    await tester.pumpAndSettle();
    expect(find.text('Brak miejsca.'), findsOneWidget);
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).textSpan!.toPlainText(), 'Ważna treść');
    await tester.tap(find.byTooltip('Udostępnij dokument'));
    await tester.pumpAndSettle();
    expect(shares, 2);
    expect(find.text('Tekst.txt'), findsOneWidget);
  });

  testWidgets('Historia filtruje nazwe i format, przypina i zachowuje przypiete po czyszczeniu', (tester) async {
    var rows = <Map<String, dynamic>>[
      {'id': 'a', 'name': 'Umowa.docx', 'extension': 'docx', 'uri': 'file:///a', 'openedAt': 1, 'pinned': false},
      {'id': 'b', 'name': 'Rachunek.pdf', 'extension': 'pdf', 'uri': 'file:///b', 'openedAt': 2, 'pinned': false},
    ];
    Map<dynamic, dynamic>? pin;
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if (call.method == 'recent') return rows;
      if (call.method == 'pinRecent') {
        pin = call.arguments as Map;
        rows.firstWhere((row) => row['id'] == pin!['id'])['pinned'] = pin!['pinned'];
      }
      if (call.method == 'clearRecent') rows = rows.where((row) => row['pinned'] == true).toList();
      return null;
    });
    await tester.pumpWidget(const DokumentyApp());
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('recent-search'));
    await tester.enterText(search, 'uMoW');
    await tester.pumpAndSettle();
    expect(find.text('Umowa.docx'), findsOneWidget);
    expect(find.text('Rachunek.pdf'), findsNothing);
    await tester.tap(find.byTooltip('Przypnij dokument'));
    await tester.pumpAndSettle();
    expect(pin, {'id': 'a', 'pinned': true});
    await tester.enterText(search, 'PDF');
    await tester.pumpAndSettle();
    expect(find.text('Rachunek.pdf'), findsOneWidget);
    expect(find.text('Umowa.docx'), findsNothing);
    await tester.enterText(search, 'nieistniejacy');
    await tester.pumpAndSettle();
    expect(find.text('Brak pasujących dokumentów.'), findsOneWidget);
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Umowa.docx')).dy, lessThan(tester.getTopLeft(find.text('Rachunek.pdf')).dy));
    await tester.tap(find.byTooltip('Wyczyść ostatnie dokumenty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wyczyść'));
    await tester.pumpAndSettle();
    expect(find.text('Umowa.docx'), findsOneWidget);
    expect(find.text('Rachunek.pdf'), findsNothing);
    expect(find.byTooltip('Odepnij dokument'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
