import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokumenty/main.dart';
import 'package:dokumenty/continuous_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('dokumenty/files');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFUlEQVR4nGP8//8/AwMDEwMDA4ICADkbAwP+wj6MAAAAAElFTkSuQmCC');
  tearDown(() => messenger.setMockMethodCallHandler(bridge, null));

  testWidgets('Dodawanie zakladki, przejscie do strony i nieudane usuniecie', (tester) async {
    final marks = <int>[3];
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if(call.method == 'initialUri') return 'content://test/report.pdf';
      if(call.method == 'open') return {
        'kind': 'pdf', 'extension': 'pdf', 'name': 'Raport.pdf', 'documentId': 61,
        'pages': 8, 'pageSizes': List.generate(8, (_) => [600, 800]),
        'bookmarks': List<int>.from(marks), 'sizeBytes': 2048,
      };
      if(call.method == 'render') return png;
      if(call.method == 'bookmark') {
        expect(call.arguments['documentId'], 61);
        if(call.arguments['add'] == true) {
          expect(call.arguments['page'], 0);
          marks.add(0); marks.sort(); return List<int>.from(marks);
        }
        expect(call.arguments['page'], 3);
        throw PlatformException(code: 'IO', message: 'Nie udało się zapisać zakładki.');
      }
      return null;
    });
    await tester.pumpWidget(const DokumentyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dodaj zakładkę'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Usuń zakładkę'), findsOneWidget);
    await tester.tap(find.byTooltip('Więcej'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zakładki (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Strona 1'), findsOneWidget);
    await tester.tap(find.text('Strona 4'));
    await tester.pumpAndSettle();
    expect(tester.state<ContinuousPdfState>(find.byType(ContinuousPdf)).view['page'], 3);
    await tester.tap(find.byTooltip('Usuń zakładkę'));
    await tester.pumpAndSettle();
    expect(find.text('Nie udało się zapisać zakładki.'), findsOneWidget);
    expect(find.byTooltip('Usuń zakładkę'), findsOneWidget);
    await tester.tap(find.byTooltip('Więcej'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Informacje o pliku'));
    await tester.tap(find.text('Informacje o pliku'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rozmiar pliku: 2,0 KB'), findsOneWidget);
    expect(find.textContaining('Strony podglądu: 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sortowanie zachowuje przypiete, pokazuje postep i otwiera ten sam widok arkusza', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rows = [
      {'id': 'a', 'name': 'B.xlsx', 'extension': 'xlsx', 'openedAt': 3, 'pinned': false, 'uri': 'file:///a', 'sizeBytes': 2048, 'pages': 5, 'lastPage': 2, 'wholeSheets': true},
      {'id': 'b', 'name': 'A.pdf', 'extension': 'pdf', 'openedAt': 2, 'pinned': false, 'uri': 'file:///b'},
      {'id': 'c', 'name': 'Z.pdf', 'extension': 'pdf', 'openedAt': 1, 'pinned': true, 'uri': 'file:///c'},
    ];
    Map<dynamic, dynamic>? opened;
    Map<dynamic, dynamic>? prefs;
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if(call.method == 'recent') return rows;
      if(call.method == 'readerPrefs') {
        if(call.arguments != null) prefs = jsonDecode(call.arguments['value']) as Map;
        return '{"paper":"warm","awake":true,"sort":"recent"}';
      }
      if(call.method == 'open') {
        opened = call.arguments as Map;
        return {'kind': 'text', 'extension': 'txt', 'name': 'Fixture.txt', 'text': 'Treść', 'documentId': 4};
      }
      return null;
    });
    await tester.pumpWidget(const DokumentyApp());
    await tester.pumpAndSettle();
    expect(find.text('Ostatnio: strona 3 z 5'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Z.pdf')).dy, lessThan(tester.getTopLeft(find.text('B.xlsx')).dy));
    await tester.tap(find.byTooltip('Sortuj dokumenty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nazwa A–Z'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Z.pdf')).dy, lessThan(tester.getTopLeft(find.text('A.pdf')).dy));
    expect(tester.getTopLeft(find.text('A.pdf')).dy, lessThan(tester.getTopLeft(find.text('B.xlsx')).dy));
    expect(prefs, {'paper': 'warm', 'awake': true, 'sort': 'name'});
    await tester.tap(find.text('B.xlsx'));
    await tester.pumpAndSettle();
    expect(opened?['wholeSheets'], true);
    expect(opened?['uri'], 'file:///a');
    expect(tester.takeException(), isNull);
  });
}
