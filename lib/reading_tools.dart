import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'continuous_pdf.dart';

class PageThumbnails extends StatefulWidget {
  const PageThumbnails({super.key, required this.documentId, required this.sizes,
    required this.current, required this.paper, this.names = const []});
  final int documentId, current;
  final List<Size> sizes;
  final String paper;
  final List<String> names;
  @override
  State<PageThumbnails> createState() => _PageThumbnailsState();
}
class _PageThumbnailsState extends State<PageThumbnails> {
  late final controller = ScrollController(initialScrollOffset: (widget.current ~/ 3) * 240.0);
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.names.isEmpty ? 'Miniatury stron' : 'Arkusze')),
    body: GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisExtent: 230, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: widget.sizes.length,
      itemBuilder: (context, index) => InkWell(
        onTap: () => Navigator.pop(context, index),
        child: Column(children: [
          Expanded(child: Card(
            color: index == widget.current ? Theme.of(context).colorScheme.primaryContainer : null,
            child: Padding(padding: const EdgeInsets.all(6), child: _Thumbnail(documentId: widget.documentId, page: index, paper: widget.paper)),
          )),
          Text(widget.names.length == widget.sizes.length ? widget.names[index] : 'Strona ${index + 1}', maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ),
  );
}
class _Thumbnail extends StatefulWidget {
  const _Thumbnail({required this.documentId, required this.page, required this.paper});
  final int documentId, page;
  final String paper;
  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}
class _ThumbnailState extends State<_Thumbnail> {
  Uint8List? bytes;
  bool failed = false;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final result = await const MethodChannel('dokumenty/files').invokeMethod<Uint8List>('render',
        {'documentId': widget.documentId, 'page': widget.page, 'width': 240});
      if (mounted) setState(() { bytes = result; failed = result == null; });
    } on PlatformException { if (mounted) setState(() => failed = true); }
  }
  @override
  Widget build(BuildContext context) => bytes != null
    ? ColorFiltered(colorFilter: paperFilter(widget.paper), child: Image.memory(bytes!, fit: BoxFit.contain))
    : Center(child: failed ? const Icon(Icons.description_outlined) : const CircularProgressIndicator());
  @override
  void dispose() {
    if(bytes != null) PaintingBinding.instance.imageCache.evict(MemoryImage(bytes!));
    super.dispose();
  }
}

class PdfSearchBar extends StatefulWidget {
  const PdfSearchBar({super.key, required this.documentId, required this.pages, required this.onResult, required this.onClose});
  final int documentId, pages;
  final void Function(int page, List<Rect> bounds) onResult;
  final VoidCallback onClose;
  @override
  State<PdfSearchBar> createState() => _PdfSearchBarState();
}
class _PdfSearchBarState extends State<PdfSearchBar> {
  final query = TextEditingController();
  final hits = <({int page, List<Rect> bounds})>[];
  int generation = 0, selected = -1, scanned = 0;
  bool running = false, searched = false;
  String? error;
  void select(int direction) {
    if(hits.isEmpty) return;
    setState(() => selected = (selected + direction) % hits.length);
    final hit = hits[selected]; widget.onResult(hit.page, hit.bounds);
  }
  Future<void> search() async {
    final text = query.text.trim();
    if(text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final token = ++generation;
    setState(() { running = true; searched = true; error = null; hits.clear(); selected = -1; scanned = 0; });
    widget.onResult(-1, const []);
    try {
      for(int page = 0; page < widget.pages; page++) {
        if(!mounted || token != generation) return;
        final rows = await const MethodChannel('dokumenty/files').invokeListMethod<dynamic>('searchPage',
          {'documentId': widget.documentId, 'page': page, 'query': text});
        if(!mounted || token != generation) return;
        setState(() {
          for(final row in rows ?? []) {
            if(hits.length >= 500) break;
            final bounds = (row as List).map((r) => Rect.fromLTRB((r[0] as num).toDouble(), (r[1] as num).toDouble(), (r[2] as num).toDouble(), (r[3] as num).toDouble())).toList();
            if(bounds.isNotEmpty) hits.add((page: page, bounds: bounds));
          }
          scanned = page + 1;
        });
        if(selected < 0 && hits.isNotEmpty) select(1);
        if(hits.length >= 500) break;
      }
    } on PlatformException catch(e) {
      if(mounted && token == generation) setState(() => error = e.message ?? 'Nie udało się wyszukać tekstu.');
    } finally {
      if(mounted && token == generation) setState(() => running = false);
    }
  }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: TextField(controller: query, maxLength: 200,
          decoration: const InputDecoration(hintText: 'Szukaj w dokumencie', counterText: ''),
          onSubmitted: (_) => search())),
        IconButton(onPressed: search, icon: const Icon(Icons.search), tooltip: 'Szukaj'),
        IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close), tooltip: 'Zamknij wyszukiwanie'),
      ]),
      Row(children: [
        Expanded(child: Text(error ?? (running ? 'Sprawdzono $scanned / ${widget.pages} stron · ${hits.length} wyników' : hits.isNotEmpty ? '${selected + 1} / ${hits.length}${hits.length >= 500 ? '+' : ''}' : searched ? 'Brak wyników. Skan może nie zawierać tekstu.' : 'Wyszukiwanie tekstu, bez OCR.'), maxLines: 2)),
        if(running) IconButton(onPressed: () { generation++; setState(() => running = false); }, icon: const Icon(Icons.stop_circle_outlined), tooltip: 'Zatrzymaj wyszukiwanie'),
        IconButton(onPressed: hits.isEmpty ? null : () => select(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Poprzedni wynik'),
        IconButton(onPressed: hits.isEmpty ? null : () => select(1), icon: const Icon(Icons.chevron_right), tooltip: 'Następny wynik'),
      ]),
      if(running) const LinearProgressIndicator(),
    ]),
  );
  @override
  void dispose() { generation++; query.dispose(); super.dispose(); }
}
