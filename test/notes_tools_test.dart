import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokumenty/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('dokumenty/files');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(bridge, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  testWidgets('Filtry, kopiowanie, edycja widocznej notatki i ponowna proba udostepnienia', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFUlEQVR4nGP8//8/AwMDEwMDA4ICADkbAwP+wj6MAAAAAElFTkSuQmCC');
    final notes = <Map<String,dynamic>>[
      {'id':'a','page':0,'left':0.1,'top':0.1,'right':0.8,'bottom':0.2,'color':'yellow','note':'Ważne: pierwszy fragment'},
      {'id':'b','page':6,'left':0.1,'top':0.1,'right':0.8,'bottom':0.2,'color':'green','note':'WAŻNE: drugi fragment'},
      {'id':'c','page':9,'left':0.1,'top':0.1,'right':0.8,'bottom':0.2,'color':'pink','note':''},
    ];
    String? clipboard;
    int shares = 0;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if(call.method == 'Clipboard.setData') clipboard = call.arguments['text'] as String;
      return null;
    });
    messenger.setMockMethodCallHandler(bridge, (call) async {
      if(call.method == 'initialUri') return 'content://test/notes.pdf';
      if(call.method == 'open') return {'kind':'pdf','extension':'pdf','name':'Notes.pdf','documentId':55,
        'pages':10,'pageSizes':List.generate(10, (_) => [600,800]),'highlights':jsonEncode(notes)};
      if(call.method == 'render') return png;
      if(call.method == 'highlight') {
        expect(call.arguments['documentId'],55);
        expect(call.arguments['action'],'edit');
        final input = jsonDecode(call.arguments['input']) as Map;
        expect(input['id'],'b');
        notes[1]['note'] = input['note']; notes[1]['color'] = input['color'];
        return jsonEncode(notes);
      }
      if(call.method == 'shareNotes') {
        expect(call.arguments, {'documentId':55}); shares++;
        if(shares == 1) throw PlatformException(code:'IO',message:'Nie udało się przygotować zestawienia.');
      }
      return null;
    });
    await tester.pumpWidget(const DokumentyApp()); await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Więcej')); await tester.pumpAndSettle();
    await tester.tap(find.text('Zaznaczenia i notatki (3)')); await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('notes-search')), 'ważne'); await tester.pumpAndSettle();
    expect(find.text('Widoczne: 2 / 3'), findsOneWidget);
    await tester.tap(find.text('Zielony')); await tester.pumpAndSettle();
    expect(find.text('Widoczne: 1 / 3'), findsOneWidget);
    expect(find.text('WAŻNE: drugi fragment'), findsOneWidget);
    await tester.tap(find.byTooltip('Opcje zaznaczenia')); await tester.pumpAndSettle();
    await tester.tap(find.text('Kopiuj notatkę')); await tester.pumpAndSettle();
    expect(clipboard,'WAŻNE: drugi fragment');
    await tester.tap(find.byTooltip('Opcje zaznaczenia')); await tester.pumpAndSettle();
    await tester.tap(find.text('Edytuj notatkę i kolor')); await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of:find.byType(AlertDialog),matching:find.byType(TextField)), 'Nowa treść');
    await tester.tap(find.descendant(of:find.byType(AlertDialog),matching:find.text('Różowy'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Zapisz')); await tester.pumpAndSettle();
    expect(find.text('Brak pasujących notatek.'),findsOneWidget);
    expect(notes[0]['note'],'Ważne: pierwszy fragment');
    expect(notes[1]['note'],'Nowa treść');
    expect(notes[1]['color'],'pink');
    await tester.ensureVisible(find.text('Udostępnij wszystkie (TXT)'));
    await tester.tap(find.text('Udostępnij wszystkie (TXT)')); await tester.pumpAndSettle();
    await tester.tap(find.text('Udostępnij wszystkie (TXT)')); await tester.pumpAndSettle();
    expect(shares,2);
    expect(tester.takeException(),isNull);
  });
}
