import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hold a word, then drag without lifting to extend the selection on this page.
class PdfSelectionLayer extends StatefulWidget {
  const PdfSelectionLayer({super.key, required this.documentId, required this.page, required this.onHighlight});
  final int documentId, page;
  final Future<bool> Function(int, List<Rect>) onHighlight;
  @override
  State<PdfSelectionLayer> createState() => _PdfSelectionLayerState();
}
class _PdfSelectionLayerState extends State<PdfSelectionLayer> {
  static const bridge = MethodChannel('dokumenty/files');
  Offset? start, end;
  List<Rect> rectangles = [];
  String text = '';
  int serial = 0;
  Timer? timer;
  bool active = false;
  Offset normalized(Offset point, Size size) => Offset((point.dx / size.width).clamp(0.0, 1.0), (point.dy / size.height).clamp(0.0, 1.0));
  Future<bool> select() async {
    final a = start, b = end;
    if(a == null || b == null) return false;
    final request = ++serial;
    try {
      final result = await bridge.invokeMapMethod<String, dynamic>('selectText', {
        'documentId': widget.documentId, 'page': widget.page, 'start': [a.dx, a.dy], 'stop': [b.dx, b.dy],
      });
      if(!mounted || request != serial || result == null) return false;
      setState(() {
        text = result['text'] as String? ?? '';
        rectangles = (result['rects'] as List? ?? []).map((r) => Rect.fromLTRB((r[0] as num).toDouble(), (r[1] as num).toDouble(), (r[2] as num).toDouble(), (r[3] as num).toDouble())).toList();
      });
      return true;
    } on PlatformException catch(e) {
      if(mounted && request == serial) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Nie można zaznaczyć tekstu.')));
      return false;
    }
  }
  void clear() {
    timer?.cancel(); serial++;
    if(mounted) setState(() { start = end = null; rectangles = []; text = ''; active = false; });
  }
  Future<void> finish() async {
    timer?.cancel(); active = false;
    final ok = await select();
    if(!mounted) return;
    if(!ok) { clear(); return; }
    if(text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brak tekstu w tym miejscu. Na skanie użyj zakreślacza obszaru.')));
      clear(); return;
    }
    final selectedText = text, selectedRects = List<Rect>.from(rectangles);
    final action = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (context) => SafeArea(
      child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(selectedText, maxLines: 4, overflow: TextOverflow.ellipsis), const SizedBox(height: 12),
        Wrap(spacing: 12, children: [
          FilledButton.tonalIcon(onPressed: () => Navigator.pop(context, 'copy'), icon: const Icon(Icons.copy), label: const Text('Kopiuj tekst')),
          FilledButton.icon(onPressed: selectedRects.isEmpty ? null : () => Navigator.pop(context, 'highlight'), icon: const Icon(Icons.highlight), label: const Text('Zakreśl tekst')),
        ]),
        const SizedBox(height: 8), const Text('Aby rozszerzyć zaznaczenie, przytrzymaj słowo i przeciągnij palcem przed jego podniesieniem.'),
      ])),
    ));
    if(!mounted) return;
    if(action == 'copy') await Clipboard.setData(ClipboardData(text: selectedText));
    if(action == 'highlight') await widget.onHighlight(widget.page, selectedRects);
    clear();
  }
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onLongPressStart: (d) { active = true; start = end = normalized(d.localPosition, constraints.biggest); unawaited(select()); },
    onLongPressMoveUpdate: (d) {
      if(!active) return;
      end = normalized(d.localPosition, constraints.biggest);
      timer ??= Timer(const Duration(milliseconds: 100), () { timer = null; if(active) unawaited(select()); });
    },
    onLongPressEnd: (_) => finish(),
    onLongPressCancel: clear,
    child: CustomPaint(painter: _SelectionPainter(rectangles), child: const SizedBox.expand()),
  ));
  @override
  void dispose() { timer?.cancel(); serial++; super.dispose(); }
}
class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.rectangles);
  final List<Rect> rectangles;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x66408cff);
    for(final rect in rectangles) canvas.drawRect(Rect.fromLTRB(rect.left * size.width, rect.top * size.height, rect.right * size.width, rect.bottom * size.height), paint);
  }
  @override
  bool shouldRepaint(_SelectionPainter old) => old.rectangles != rectangles;
}
