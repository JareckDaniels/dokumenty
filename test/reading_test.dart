import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokumenty/main.dart';
import 'package:dokumenty/continuous_pdf.dart';
import 'package:dokumenty/reading_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('dokumenty/files');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFUlEQVR4nGP8//8/AwMDEwMDA4ICADkbAwP+wj6MAAAAAElFTkSuQmCC');
  tearDown(() => messenger.setMockMethodCallHandler(bridge, null));

  testWidgets('Tryb czytania: kolory, pelen ekran, dwa powroty i zapis pozycji', (tester) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(bridge, (call) async {
      calls.add(call);
      if(call.method == 'readerPrefs') return call.arguments?['value'] ?? '{}';
      if(call.method == 'initialUri') return 'content://test/book.pdf';
      if(call.method == 'open') return {
        'kind': 'pdf', 'name': 'Książka.pdf', 'extension': 'pdf', 'documentId': 9,
        'pages': 10, 'pageSizes': List.generate(10, (_) => [600, 800]),
        'readingState': '{"page":2,"fraction":0.25,"zoom":1.5,"x":0}',
        'searchAvailable': true,
      };
      if(call.method == 'render') return png;
      return null;
    });
    await tester.pumpWidget(const DokumentyApp());
    await tester.pumpAndSettle();
    final pdf = tester.state<ContinuousPdfState>(find.byType(ContinuousPdf));
    expect(pdf.view['page'], 2);
    expect(pdf.view['zoom'], 1.5);
    await tester.tap(find.byTooltip('Tryb czytania'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ciemny'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nie wygaszaj ekranu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Czytaj na pełnym ekranie'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(tester.widget<ContinuousPdf>(find.byType(ContinuousPdf)).paper, 'dark');
    expect(calls.where((c) => c.method == 'readerWindow').last.arguments, {'fullscreen': true, 'awake': true});
    await tester.tapAt(tester.getCenter(find.byType(ContinuousPdf)));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'finishExternal'), isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'finishExternal').length, 1);
    final saved = calls.where((c) => c.method == 'saveReading').last;
    expect(saved.arguments['documentId'], 9);
    expect(jsonDecode(saved.arguments['view'])['page'], 2);
    final preferences = calls.where((c) => c.method == 'readerPrefs' && c.arguments != null).last;
    expect(jsonDecode(preferences.arguments['value']), {'paper': 'dark', 'awake': true});
  });

  testWidgets('Obrot zachowuje strone, powiekszenie i miejsce na stronie', (tester) async {
    messenger.setMockMethodCallHandler(bridge, (call) async => call.method == 'render' ? png : null);
    final key = GlobalKey<ContinuousPdfState>();
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ContinuousPdf(
      key: key, documentId: 2, pageSizes: List.generate(20, (_) => const Size(600, 800)),
      initialView: const {'page': 6, 'fraction': 0.4, 'zoom': 2.0, 'x': 0.1}, onPageChanged: (_) {},
    ))));
    await tester.pumpAndSettle();
    final before = key.currentState!.view;
    await tester.binding.setSurfaceSize(const Size(800, 400));
    await tester.pumpAndSettle();
    final after = key.currentState!.view;
    expect(after['page'], before['page']);
    expect(after['fraction'], closeTo(before['fraction'] as num, 0.01));
    expect(after['zoom'], 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wyszukiwanie przechodzi miedzy wynikami na roznych stronach', (tester) async {
    final selected = <int>[];
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if(call.method != 'searchPage') return null;
      expect(call.arguments['query'], 'umowa');
      expect(call.arguments['documentId'], 12);
      if(call.arguments['page'] == 1) return [];
      return [[[0.1, 0.2, 0.4, 0.25]]];
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PdfSearchBar(
      documentId: 12, pages: 3, onResult: (page, bounds) { if(page >= 0) selected.add(page); }, onClose: () {},
    ))));
    await tester.enterText(find.byType(TextField), 'umowa');
    await tester.tap(find.byTooltip('Szukaj'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Następny wynik'));
    await tester.pumpAndSettle();
    expect(selected, [0, 2]);
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Poprzedni wynik'));
    await tester.pumpAndSettle();
    expect(selected.last, 0);
  });

  testWidgets('Zamkniecie wyszukiwania przerywa dalsze strony', (tester) async {
    final pending = Completer<List<dynamic>>();
    int calls = 0;
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if(call.method == 'searchPage') { calls++; return pending.future; }
      return null;
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PdfSearchBar(
      documentId: 1, pages: 100, onResult: (_, __) {}, onClose: () {},
    ))));
    await tester.enterText(find.byType(TextField), 'test');
    await tester.tap(find.byTooltip('Szukaj'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Miniatury prosza o male obrazy tylko widocznych stron', (tester) async {
    final pages = <int>[];
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if(call.method == 'render') {
        expect(call.arguments['documentId'], 7);
        expect(call.arguments['width'], 240);
        pages.add(call.arguments['page'] as int);
        return png;
      }
      return null;
    });
    await tester.pumpWidget(MaterialApp(home: PageThumbnails(
      documentId: 7, sizes: List.generate(100, (_) => const Size(600, 800)), current: 0, paper: 'warm',
    )));
    await tester.pumpAndSettle();
    expect(pages.length, lessThan(30));
    expect(pages, contains(0));
    expect(tester.takeException(), isNull);
  });
}
