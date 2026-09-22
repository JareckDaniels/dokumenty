import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dokumenty/continuous_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('dokumenty/files');
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFUlEQVR4nGP8//8/AwMDEwMDA4ICADkbAwP+wj6MAAAAAElFTkSuQmCC',
  );
  final requested = <int>[];
  setUp(() {
    requested.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          if (call.method == 'render') {
            expect(call.arguments['documentId'], 7);
            requested.add(call.arguments['page'] as int);
            return png;
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, null);
  });

  testWidgets(
    'Przeciagniecie w gore przechodzi na kolejne strony i nie laduje calego pliku',
    (tester) async {
      int page = 0;
      final key = GlobalKey<ContinuousPdfState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContinuousPdf(
              key: key,
              documentId: 7,
              pageSizes: List.generate(30, (_) => const Size(400, 600)),
              onPageChanged: (p) => page = p,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requested, contains(0));
      expect(requested.length, lessThan(5));
      final list = find.byKey(const ValueKey('continuous-document'));
      await tester.timedDrag(
        list,
        const Offset(0, -1500),
        const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();
      expect(page, greaterThan(0));
      expect(requested.any((p) => p > 0), isTrue);
      expect(requested.length, lessThan(15));
      key.currentState!.goToPage(20);
      await tester.pumpAndSettle();
      expect(page, 20);
      expect(requested, contains(20));
      key.currentState!.goToPage(0);
      await tester.pumpAndSettle();
      expect(page, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
