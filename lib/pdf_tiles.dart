import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef TileRender = Future<Uint8List?> Function(int page, int width, int x, int y, int size, bool Function() visible);

/// Only visible 768px tiles are decoded; no full-page bitmap at high zoom.
class PdfTiles extends StatelessWidget {
  const PdfTiles({super.key, required this.page, required this.fullWidth, required this.pageSize,
    required this.visible, required this.render});
  final int page, fullWidth;
  final Size pageSize;
  final Rect visible;
  final TileRender render;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    const tile = 768;
    final size = constraints.biggest;
    if(visible.isEmpty || size.width <= 0 || size.height <= 0) return const SizedBox.shrink();
    final scale = fullWidth / size.width;
    final fullHeight = (fullWidth * pageSize.height / pageSize.width).ceil();
    final firstX = math.max(0, (visible.left * scale / tile).floor());
    final lastX = math.min((fullWidth - 1) ~/ tile, (visible.right * scale / tile).floor());
    final firstY = math.max(0, (visible.top * scale / tile).floor());
    final lastY = math.min((fullHeight - 1) ~/ tile, (visible.bottom * scale / tile).floor());
    return IgnorePointer(child: Stack(children: [
      for(int y = firstY; y <= lastY; y++) for(int x = firstX; x <= lastX; x++) Positioned(
        left: x * tile / scale, top: y * tile / scale,
        width: math.min(tile, fullWidth - x * tile) / scale,
        height: math.min(tile, fullHeight - y * tile) / scale,
        child: _Tile(key: ValueKey('$page/$fullWidth/$x/$y'),
          load: (visible) => render(page, fullWidth, x * tile, y * tile, tile, visible)),
      ),
    ]));
  });
}
class _Tile extends StatefulWidget {
  const _Tile({super.key, required this.load});
  final Future<Uint8List?> Function(bool Function()) load;
  @override
  State<_Tile> createState() => _TileState();
}
class _TileState extends State<_Tile> {
  Uint8List? bytes;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try { final value = await widget.load(() => mounted); if(mounted) setState(() => bytes = value); }
    on PlatformException { /* The base page remains visible if a tile fails. */ }
  }
  @override
  Widget build(BuildContext context) => bytes == null ? const SizedBox.expand() : Image.memory(bytes!, fit: BoxFit.fill, filterQuality: FilterQuality.low, excludeFromSemantics: true);
  @override
  void dispose() { if(bytes != null) PaintingBinding.instance.imageCache.evict(MemoryImage(bytes!)); super.dispose(); }
}
