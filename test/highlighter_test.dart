import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokumenty/highlighter.dart';
import 'package:dokumenty/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('dokumenty/files');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(bridge, null));

  testWidgets('Zakres zaznaczenia jest niezalezny od rozmiaru podgladu', (tester) async {
    final rectangles = <Rect>[];
    Future<void> draw(double width, double height) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SizedBox(
        width: width, height: height, child: MarkLayer(
          marks: const [], enabled: true, color: 'yellow', pageSize: const Size(600, 900),
          onDraw: (rect) async { rectangles.add(rect); return true; },
        ),
      )))));
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(find.byType(MarkLayer));
      await tester.dragFrom(origin + Offset(width * 0.1, height * 0.2), Offset(width * 0.6, height * 0.1));
      await tester.pumpAndSettle();
    }
    await draw(300, 450);
    await draw(360, 540);
    expect(rectangles.length, 2);
    for(final rect in rectangles) {
      expect(rect.left, closeTo(0.1, 0.01)); expect(rect.top, closeTo(0.2, 0.01));
      expect(rect.right, closeTo(0.7, 0.01)); expect(rect.bottom, closeTo(0.3, 0.01));
    }
  });

  testWidgets('Tryb podgladu nie tworzy zaznaczen', (tester) async {
    int calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MarkLayer(
      marks: const [], enabled: false, color: 'pink', pageSize: const Size(600, 900),
      onDraw: (_) async { calls++; return true; },
    ))));
    await tester.drag(find.byType(MarkLayer), const Offset(100, 20));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('Zapis notatki zwraca kolor i pelna polska tresc', (tester) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () async { result = await showDialog<Map<String,dynamic>>(context: context, builder: (_) => const MarkNoteDialog(
        mark: PageMark(id: 'one', page: 2, rect: Rect.fromLTRB(0.1,0.2,0.8,0.3), color: 'yellow', note: ''),
      )); }, child: const Text('Otwórz'),
    )))));
    await tester.tap(find.text('Otwórz')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ważny fragment — zażółć gęślą');
    await tester.tap(find.text('Zielony')); await tester.pumpAndSettle();
    await tester.tap(find.text('Zapisz')); await tester.pumpAndSettle();
    expect(result, {'id':'one', 'color':'green', 'note':'Ważny fragment — zażółć gęślą'});
  });

  testWidgets('Rysowanie w czytniku zapisuje obszar i pozwala go cofnac', (tester) async {
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFUlEQVR4nGP8//8/AwMDEwMDA4ICADkbAwP+wj6MAAAAAElFTkSuQmCC');
    final operations = <String>[];
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if(call.method == 'initialUri') return 'content://test/book.pdf';
      if(call.method == 'open') return {'kind':'pdf', 'name':'Book.pdf', 'extension':'pdf', 'documentId':5,
        'pages':3, 'pageSizes':List.generate(3, (_) => [600,900]), 'highlights':'[]'};
      if(call.method == 'render') return png;
      if(call.method == 'highlight') {
        expect(call.arguments['documentId'], 5);
        final action = call.arguments['action'] as String;
        operations.add(action);
        final input = Map<String,dynamic>.from(jsonDecode(call.arguments['input']) as Map);
        if(action == 'delete') { expect(input['id'], 'mark-1'); return '[]'; }
        expect(input['page'], 0); expect(input['color'], 'yellow');
        expect(input['left'], greaterThanOrEqualTo(0)); expect(input['right'], lessThanOrEqualTo(1));
        return jsonEncode([{...input, 'id':'mark-1', 'note':''}]);
      }
      return null;
    });
    await tester.pumpWidget(const DokumentyApp()); await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Więcej')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Zakreślacz'));
    await tester.tap(find.text('Zakreślacz')); await tester.pumpAndSettle();
    final page = find.byType(MarkLayer).first;
    final start = tester.getTopLeft(page) + const Offset(50, 80);
    await tester.dragFrom(start, const Offset(200, 10)); await tester.pumpAndSettle();
    expect(operations, ['add']);
    expect(tester.widget<MarkLayer>(page).marks.length, 1);
    await tester.tap(find.byTooltip('Cofnij ostatnie zaznaczenie')); await tester.pumpAndSettle();
    expect(operations, ['add', 'delete']);
    expect(tester.widget<MarkLayer>(page).marks, isEmpty);
    await tester.tap(find.text('Zakończ')); await tester.pumpAndSettle();
    expect(tester.widget<MarkLayer>(page).enabled, false);
    expect(tester.takeException(), isNull);
  });
}
