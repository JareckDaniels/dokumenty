import 'package:flutter/material.dart';

Color markerColor(String name) => switch(name) {
  'green' => const Color(0xff65db77),
  'pink' => const Color(0xffff7fbd),
  _ => const Color(0xffffd43b),
};
String markerName(String name) => switch(name) { 'green' => 'Zielony', 'pink' => 'Różowy', _ => 'Żółty' };

class PageMark {
  const PageMark({required this.id, required this.page, required this.rect, required this.color, required this.note});
  final String id, color, note;
  final int page;
  final Rect rect;
  factory PageMark.fromJson(Map<String, dynamic> data) => PageMark(
    id: data['id'] as String, page: (data['page'] as num).toInt(),
    rect: Rect.fromLTRB((data['left'] as num).toDouble(), (data['top'] as num).toDouble(), (data['right'] as num).toDouble(), (data['bottom'] as num).toDouble()),
    color: data['color'] as String, note: data['note'] as String? ?? '',
  );
}

class MarkLayer extends StatefulWidget {
  const MarkLayer({super.key, required this.marks, required this.enabled, required this.color, required this.pageSize, required this.onDraw});
  final List<PageMark> marks;
  final bool enabled;
  final String color;
  final Size pageSize;
  final Future<bool> Function(Rect rect) onDraw;
  @override
  State<MarkLayer> createState() => _MarkLayerState();
}
class _MarkLayerState extends State<MarkLayer> {
  Offset? start, end;
  int pointers = 0;
  bool cancelled = false, saving = false;
  Rect? draft;
  Rect rectangle(Offset a, Offset b, Size size) {
    final raw = Rect.fromPoints(a, b);
    double top = (raw.top / size.height).clamp(0.0, 1.0);
    double bottom = (raw.bottom / size.height).clamp(0.0, 1.0);
    final thickness = (12 / widget.pageSize.height).clamp(0.001, 0.2);
    if(bottom - top < thickness) {
      final center = (top + bottom) / 2;
      top = (center - thickness / 2).clamp(0.0, 1.0 - thickness);
      bottom = top + thickness;
    }
    return Rect.fromLTRB((raw.left / size.width).clamp(0.0, 1.0), top, (raw.right / size.width).clamp(0.0, 1.0), bottom);
  }
  void cancel() { if(mounted && !saving) setState(() { start = end = null; draft = null; }); }
  Future<void> finish() async {
    final area = draft;
    if(cancelled || area == null || area.width * widget.pageSize.width < 2 || saving) { cancel(); return; }
    setState(() => saving = true);
    try { await widget.onDraw(area); }
    finally { if(mounted) setState(() { saving = false; pointers = 0; start = end = null; draft = null; }); }
  }
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final size = constraints.biggest;
    return Stack(fit: StackFit.expand, children: [
      IgnorePointer(child: CustomPaint(painter: MarkerPainter(widget.marks, draft, widget.color))),
      if(widget.enabled && !saving) Listener(
        onPointerDown: (_) { pointers++; if(pointers > 1) { cancelled = true; cancel(); } },
        onPointerUp: (_) => pointers = (pointers - 1).clamp(0, 10).toInt(),
        onPointerCancel: (_) { pointers = 0; cancelled = true; cancel(); },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) { if(pointers <= 1) { cancelled = false; start = end = details.localPosition; } },
          onPanUpdate: (details) {
            if(cancelled || start == null) return;
            setState(() { end = details.localPosition; draft = rectangle(start!, end!, size); });
          },
          onPanEnd: (_) => finish(),
          onPanCancel: cancel,
          child: const SizedBox.expand(),
        ),
      ),
    ]);
  });
}
class MarkerPainter extends CustomPainter {
  MarkerPainter(this.marks, this.draft, this.color);
  final List<PageMark> marks;
  final Rect? draft;
  final String color;
  @override
  void paint(Canvas canvas, Size size) {
    void draw(Rect rect, String color) {
      canvas.drawRect(Rect.fromLTRB(rect.left * size.width, rect.top * size.height, rect.right * size.width, rect.bottom * size.height),
        Paint()..color = markerColor(color).withAlpha(95));
    }
    for(final mark in marks) draw(mark.rect, mark.color);
    if(draft != null) draw(draft!, color);
  }
  @override
  bool shouldRepaint(MarkerPainter old) => old.marks != marks || old.draft != draft || old.color != color;
}

class MarkNoteDialog extends StatefulWidget {
  const MarkNoteDialog({super.key, required this.mark});
  final PageMark mark;
  @override
  State<MarkNoteDialog> createState() => _MarkNoteDialogState();
}
class _MarkNoteDialogState extends State<MarkNoteDialog> {
  late final controller = TextEditingController(text: widget.mark.note);
  late String color = widget.mark.color;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Notatka · strona ${widget.mark.page + 1}'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Wrap(spacing: 6, children: [for(final name in ['yellow', 'green', 'pink']) ChoiceChip(
        label: Text(markerName(name)), selected: color == name, selectedColor: markerColor(name).withAlpha(100),
        onSelected: (_) => setState(() => color = name),
      )]),
      TextField(controller: controller, minLines: 3, maxLines: 6, maxLength: 1000, decoration: const InputDecoration(hintText: 'Twoja notatka do fragmentu')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
      FilledButton(onPressed: () => Navigator.pop(context, {'id': widget.mark.id, 'color': color, 'note': controller.text}), child: const Text('Zapisz'))],
  );
  @override
  void dispose() { controller.dispose(); super.dispose(); }
}
