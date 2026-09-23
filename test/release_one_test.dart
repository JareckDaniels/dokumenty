import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokumenty/main.dart';
import 'package:dokumenty/pdf_selection.dart';
import 'package:dokumenty/pdf_tiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('dokumenty/files');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFUlEQVR4nGP8//8/AwMDEwMDA4ICADkbAwP+wj6MAAAAAElFTkSuQmCC');
  tearDown(() {
    messenger.setMockMethodCallHandler(bridge, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  testWidgets('Long press selects real text and copies the full Unicode selection', (tester) async {
    String? copied;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if(call.method == 'Clipboard.setData') copied = call.arguments['text'] as String;
      return null;
    });
    messenger.setMockMethodCallHandler(bridge, (call) async {
      expect(call.method, 'selectText');
      expect(call.arguments['documentId'], 5);
      expect(call.arguments['page'], 2);
      return {'text': 'Zażółć gęślą\njaźń', 'rects': [[.1,.1,.5,.2],[.1,.2,.3,.3]]};
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 400, height: 400,
      child: PdfSelectionLayer(documentId: 5, page: 2, onHighlight: (_, _) async => true)))));
    await tester.longPress(find.byType(PdfSelectionLayer)); await tester.pumpAndSettle();
    await tester.tap(find.text('Kopiuj tekst')); await tester.pumpAndSettle();
    expect(copied, 'Zażółć gęślą\njaźń'); expect(tester.takeException(), isNull);
  });
  testWidgets('Holding and dragging extends selection, then saves every selected line', (tester) async {
    final queries = <Map>[];
    List<Rect>? highlighted;
    messenger.setMockMethodCallHandler(bridge, (call) async {
      queries.add(call.arguments as Map);
      return {'text': 'Dwa wiersze', 'rects': [[.1,.1,.5,.2],[.1,.2,.3,.3]]};
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 400, height: 400,
      child: PdfSelectionLayer(documentId: 9, page: 0, onHighlight: (page, rects) async { highlighted = rects; return true; })))));
    final gesture = await tester.startGesture(const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(const Offset(180, 200)); await tester.pump(const Duration(milliseconds: 150));
    await gesture.up(); await tester.pumpAndSettle();
    expect(queries.last['start'], isNot(equals(queries.last['stop'])));
    await tester.tap(find.text('Zakreśl tekst')); await tester.pumpAndSettle();
    expect(highlighted, [const Rect.fromLTRB(.1,.1,.5,.2),const Rect.fromLTRB(.1,.2,.3,.3)]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('A scan produces a useful message and cannot add an empty annotation', (tester) async {
    messenger.setMockMethodCallHandler(bridge, (call) async => {'text': '', 'rects': []});
    bool saved = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 400, height: 400,
      child: PdfSelectionLayer(documentId: 1, page: 0, onHighlight: (_, _) async { saved = true; return true; })))));
    await tester.longPress(find.byType(PdfSelectionLayer)); await tester.pumpAndSettle();
    expect(find.textContaining('Brak tekstu'), findsOneWidget); expect(saved, isFalse);
  });
  testWidgets('Only visible tiles are requested at large zoom, moving viewport loads a new region', (tester) async {
    final calls = <String>[];
    Future<Uint8List?> render(int page, int width, int x, int y, int size, bool Function() visible) async {
      expect(width, 12000); expect(size, 768); calls.add('$x/$y'); return png;
    }
    Widget view(Rect area) => MaterialApp(home: Scaffold(body: SizedBox(width: 600, height: 600,
      child: PdfTiles(page: 0, fullWidth: 12000, pageSize: const Size(600, 600), visible: area, render: render))));
    await tester.pumpWidget(view(const Rect.fromLTWH(0, 0, 40, 40))); await tester.pumpAndSettle();
    expect(calls.length, 4); expect(calls, contains('0/0'));
    calls.clear();
    await tester.pumpWidget(view(const Rect.fromLTWH(400, 400, 40, 40))); await tester.pumpAndSettle();
    expect(calls.length, lessThanOrEqualTo(4)); expect(calls, isNot(contains('0/0')));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Annotated sharing uses its own bridge and keeps original sharing separate', (tester) async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if(call.method == 'initialUri') return 'content://fixture/doc.pdf';
      if(call.method == 'open') return {'kind':'pdf','extension':'pdf','documentId':7,'name':'Doc.pdf','pages':1,'pageSizes':[[600,800]],
        'highlights':jsonEncode([{'id':'a','page':0,'left':.1,'top':.1,'right':.6,'bottom':.2,'color':'yellow','note':'Komentarz'}])};
      if(call.method == 'render') return png;
      if(['share','annotatedPdf'].contains(call.method)) { methods.add(call.method); expect(call.arguments['documentId'],7); }
      return null;
    });
    await tester.pumpWidget(const DokumentyApp()); await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Udostępnij dokument')); await tester.pumpAndSettle();
    await tester.tap(find.text('PDF z zaznaczeniami i komentarzami')); await tester.pumpAndSettle();
    expect(methods, ['annotatedPdf']);
    await tester.tap(find.byTooltip('Udostępnij dokument')); await tester.pumpAndSettle();
    await tester.tap(find.text('Oryginalny plik')); await tester.pumpAndSettle();
    expect(methods, ['annotatedPdf','share']);
  });
  testWidgets('Backup cancelled, retry, then failed import leave the home usable', (tester) async {
    int saves = 0;
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if(call.method == 'recent') return [];
      if(call.method == 'backup') { saves++; return saves == 1 ? null : 'content://copy.json'; }
      if(call.method == 'restoreBackup') throw PlatformException(code:'INVALID',message:'Nieprawidłowa kopia.');
      return null;
    });
    await tester.pumpWidget(const DokumentyApp()); await tester.pumpAndSettle();
    for(int i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Kopia zapasowa')); await tester.pumpAndSettle();
      await tester.tap(find.text('Zapisz kopię')); await tester.pumpAndSettle();
    }
    expect(saves, 2);
    expect(find.text('Zapisano kopię danych czytnika.'), findsOneWidget);
    await tester.tap(find.byTooltip('Kopia zapasowa')); await tester.pumpAndSettle();
    await tester.tap(find.text('Przywróć z pliku')); await tester.pumpAndSettle();
    expect(find.text('Nieprawidłowa kopia.'), findsOneWidget);
    expect(find.text('Zapisano kopię danych czytnika.'), findsNothing);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.backup_outlined)).onPressed, isNotNull);
    expect(find.byTooltip('Kopia zapasowa'), findsOneWidget); expect(tester.takeException(), isNull);
  });
}
