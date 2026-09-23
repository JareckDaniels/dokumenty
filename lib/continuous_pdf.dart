import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'highlighter.dart';
import 'pdf_tiles.dart';
import 'pdf_selection.dart';

/// One continuous document. Zoom changes the layout, so vertical scrolling
/// continues to work at every zoom level instead of panning a single page.
class ContinuousPdf extends StatefulWidget {
  const ContinuousPdf({
    super.key,
    required this.documentId,
    required this.pageSizes,
    required this.onPageChanged,
    this.initialView = const {},
    this.onViewChanged,
    this.onTap,
    this.paper = 'original',
    this.highlights = const {},
    this.marks = const [],
    this.marking = false,
    this.marker = 'yellow',
    this.onMark,
    this.onTextHighlight,
    this.textSelection = false,
  });
  final bool textSelection;
  final Future<bool> Function(int, List<Rect>)? onTextHighlight;
  final int documentId;
  final List<Size> pageSizes;
  final ValueChanged<int> onPageChanged;
  final Map<String, dynamic> initialView;
  final VoidCallback? onViewChanged;
  final VoidCallback? onTap;
  final String paper;
  final Map<int, List<Rect>> highlights;
  final List<PageMark> marks;
  final bool marking;
  final String marker;
  final Future<bool> Function(int page, Rect rect)? onMark;
  @override
  State<ContinuousPdf> createState() => ContinuousPdfState();
}

class ContinuousPdfState extends State<ContinuousPdf> {
  static const _bridge = MethodChannel('dokumenty/files');
  final _vertical = _ZoomScrollController();
  final _horizontal = _ZoomScrollController();
  final _tilesChanged = ValueNotifier<int>(0);
  final Map<int, Offset> _pointers = {};
  Future<void> _renderQueue = Future<void>.value();
  double _zoom = 1;
  double _viewportWidth = 1;
  int _renderWidth = 1200;
  double _startZoom = 1, _startDistance = 1;
  Offset _anchor = Offset.zero;
  Offset _pinchStart = Offset.zero;
  Offset _pinchFocal = Offset.zero;
  double _previewZoom = 1;
  bool _pinching = false;
  List<double> _offsets = [0];
  int _reportedPage = -1;
  int _layoutSerial = 0;
  bool _restored = false;
  Map<String, dynamic>? _pendingView;
  Map<String, dynamic> get view {
    final offset = _vertical.hasClients ? _vertical.offset : 0.0;
    final page = _pageAt(offset.clamp(0.0, double.infinity));
    final extent = _offsets.length > page + 1 ? _offsets[page + 1] - _offsets[page] : 1.0;
    return {'page': page, 'fraction': ((offset - _offsets[page]) / extent).clamp(0.0, 1.0),
      'zoom': _zoom, 'x': _horizontal.hasClients ? _horizontal.offset / math.max(1.0, _viewportWidth * _zoom) : 0.0};
  }
  void _viewChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) { if(mounted) widget.onViewChanged?.call(); });
  }
  void revealMatch(int page, Rect rect) {
    if (!_vertical.hasClients || page < 0 || page >= widget.pageSizes.length) return;
    final width = math.max(1.0, _viewportWidth - 16) * _zoom;
    final height = width * widget.pageSizes[page].height / widget.pageSizes[page].width;
    _vertical.jumpTo((_offsets[page] + 8 * _zoom + rect.top * height - 80).clamp(0.0, _vertical.position.maxScrollExtent));
    if(_horizontal.hasClients) _horizontal.jumpTo((rect.left * width - 24).clamp(0.0, _horizontal.position.maxScrollExtent));
  }

  @override
  void initState() {
    super.initState();
    _vertical.addListener(_reportPage);
    _vertical.addListener(_viewChanged);
    _horizontal.addListener(_viewChanged);
  }

  @override
  void didUpdateWidget(covariant ContinuousPdf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _restored = false;
      _pendingView = null;
      _zoom = 1;
      _reportedPage = -1;
      _pointers.clear();
      _pinching = false;
      _previewZoom = 1;
      _vertical.pendingPixels = 0;
      _horizontal.pendingPixels = 0;
      _layoutSerial++;
      _layout();

    }
  }

  void _layout() {
    final width = math.max(1.0, _viewportWidth - 16) * _zoom;
    _offsets = [0];
    for (final size in widget.pageSizes) {
      _offsets.add(
        _offsets.last + width * size.height / size.width + 16 * _zoom,
      );
    }
  }

  int _pageAt(double offset) {
    int low = 0, high = widget.pageSizes.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_offsets[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  void _reportPage() {
    if (_pinching || !_vertical.hasClients || widget.pageSizes.isEmpty) return;
    final page = _pageAt(_vertical.offset + 24);
    if (page == _reportedPage) return;
    _reportedPage = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPageChanged(_reportedPage);
    });
  }

  void goToPage(int page) {
    if (!_vertical.hasClients || page < 0 || page >= widget.pageSizes.length)
      return;
    _vertical.jumpTo(
      _offsets[page].clamp(0.0, _vertical.position.maxScrollExtent),
    );
    _reportPage();
  }

  void fitWidth() {
    if (!_vertical.hasClients || _pinching) return;
    const focal = Offset(0, 24);
    final anchor = Offset(
      ((_horizontal.hasClients ? _horizontal.offset : 0) + focal.dx) / _zoom,
      (_vertical.offset + focal.dy) / _zoom,
    );
    _commitZoom(1, focal, anchor);
  }

  void _commitZoom(double value, Offset focal, Offset anchor) {
    final zoom = value.clamp(1.0, 12.0);
    final serial = ++_layoutSerial;
    _vertical.pendingPixels = anchor.dy * zoom - focal.dy;
    _horizontal.pendingPixels = anchor.dx * zoom - focal.dx;
    setState(() {
      _zoom = zoom;
      _pinching = false;
      _layout();
    });
    // Scroll positions consume their targets during layout, before the first paint
    // at the new zoom. No visible frame at an intermediate offset.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && serial == _layoutSerial) { _tilesChanged.value++; _reportPage(); _viewChanged(); }
    });
  }

  void _down(PointerDownEvent event) {
    if(widget.marking) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length != 2 || _pinching || !_vertical.hasClients) return;
    final points = _pointers.values.take(2).toList();
    _pinchStart = _pinchFocal = (points[0] + points[1]) / 2;
    _startDistance = math.max(1.0, (points[0] - points[1]).distance);
    _startZoom = _previewZoom = _zoom;
    _anchor = Offset(
      ((_horizontal.hasClients ? _horizontal.offset : 0) + _pinchStart.dx) /
          _zoom,
      (_vertical.offset + _pinchStart.dy) / _zoom,
    );
    _vertical.jumpTo(_vertical.offset);
    if (_horizontal.hasClients) _horizontal.jumpTo(_horizontal.offset);
    setState(() => _pinching = true);
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (!_pinching || _pointers.length < 2) return;
    final points = _pointers.values.take(2).toList();
    setState(() {
      _pinchFocal = (points[0] + points[1]) / 2;
      _previewZoom =
          (_startZoom * (points[0] - points[1]).distance / _startDistance)
              .clamp(1.0, 12.0);
    });
  }

  void _up(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pinching && _pointers.length < 2)
      _commitZoom(_previewZoom, _pinchFocal, _anchor);
  }

  Future<Uint8List?> _render(int index, bool Function() stillVisible) {
    final documentId = widget.documentId;
    final renderWidth = _renderWidth;
    final result = Completer<Uint8List?>();
    _renderQueue = _renderQueue.then((_) async {
      if (!mounted || !stillVisible() || documentId != widget.documentId) {
        result.complete(null);
        return;
      }
      try {
        result.complete(
          await _bridge.invokeMethod<Uint8List>('render', {
            'page': index,
            'width': renderWidth,
            'documentId': documentId,
          }),
        );
      } catch (e, stack) {
        result.completeError(e, stack);
      }
    });
    return result.future;
  }

  Future<Uint8List?> _renderTile(int page, int width, int x, int y, int size, bool Function() visible) {
    final id = widget.documentId;
    final result = Completer<Uint8List?>();
    _renderQueue = _renderQueue.then((_) async {
      if(!mounted || !visible() || id != widget.documentId) { result.complete(null); return; }
      try { result.complete(await _bridge.invokeMethod<Uint8List>('renderTile', {
        'documentId': id, 'page': page, 'fullWidth': width, 'x': x, 'y': y, 'size': size,
      })); } catch(e, stack) { result.completeError(e, stack); }
    });
    return result.future;
  }
  Widget _tiles(int page) => AnimatedBuilder(animation: Listenable.merge([_vertical, _horizontal, _tilesChanged]), builder: (context, _) {
    final width = math.max(1.0, _viewportWidth - 16) * _zoom;
    final height = width * widget.pageSizes[page].height / widget.pageSizes[page].width;
    final x = (_horizontal.hasClients ? _horizontal.offset : 0.0) - 8 * _zoom;
    final y = (_vertical.hasClients ? _vertical.offset : 0.0) - _offsets[page] - 8 * _zoom;
    final viewportHeight = _vertical.hasClients ? _vertical.position.viewportDimension : 0.0;
    final visible = Rect.fromLTWH(x, y, _viewportWidth, viewportHeight).intersect(Rect.fromLTWH(0, 0, width, height));
    final pixels = ((width * MediaQuery.devicePixelRatioOf(context) / 400).ceil() * 400).clamp(800, 50000).toInt();
    return PdfTiles(page: page, fullWidth: pixels, pageSize: widget.pageSizes[page], visible: visible, render: _renderTile);
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!_restored) {
        _pendingView = widget.initialView;
        _zoom = ((widget.initialView['zoom'] as num?)?.toDouble() ?? 1).clamp(1.0, 12.0);
        _restored = true;
      } else if ((_viewportWidth - constraints.maxWidth).abs() > 0.5) {
        _pendingView = view;
      }
      _viewportWidth = constraints.maxWidth;
      _layout();
      _renderWidth = ((_viewportWidth * MediaQuery.devicePixelRatioOf(context) * math.min(_zoom, 1.4) / 400).ceil() * 400).clamp(800, 1600).toInt();
      final restore = _pendingView;
      if (restore != null && widget.pageSizes.isNotEmpty) {
        final page = ((restore['page'] as num?)?.toInt() ?? 0).clamp(0, widget.pageSizes.length - 1).toInt();
        final fraction = ((restore['fraction'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
        _vertical.pendingPixels = _offsets[page] + fraction * (_offsets[page + 1] - _offsets[page]);
        _horizontal.pendingPixels = ((restore['x'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0) * _viewportWidth * _zoom;
        _pendingView = null;
        WidgetsBinding.instance.addPostFrameCallback((_) { if(mounted) { _tilesChanged.value++; _reportPage(); } });
      }
      final pinching = _pinching;
      final preview = Matrix4.identity();
      if (pinching) {
        preview.translateByDouble(_pinchFocal.dx, _pinchFocal.dy, 0, 1);
        preview.scaleByDouble(
          _previewZoom / _startZoom,
          _previewZoom / _startZoom,
          1,
          1,
        );
        preview.translateByDouble(-_pinchStart.dx, -_pinchStart.dy, 0, 1);
      }
      return GestureDetector(
        onTap: widget.marking ? null : widget.onTap,
        child: ColoredBox(
        color: widget.paper == 'dark' ? Colors.black : widget.paper == 'warm' ? const Color(0xff594938) : const Color(0xff333a3b),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: ClipRect(
            child: Transform(
              key: const ValueKey('pinch-preview'),
              transform: preview,
              child: SingleChildScrollView(
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                physics: pinching || widget.marking
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                child: SizedBox(
                  width: _viewportWidth * _zoom,
                  height: constraints.maxHeight,
                  child: Scrollbar(
                    controller: _vertical,
                    child: ListView.builder(
                      key: const ValueKey('continuous-document'),
                      controller: _vertical,
                      physics: pinching || widget.marking
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      cacheExtent: 200,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewPaddingOf(context).bottom + 72,
                      ),
                      itemCount: widget.pageSizes.length,
                      itemExtentBuilder: (index, dimensions) =>
                          _offsets[index + 1] - _offsets[index],
                      itemBuilder: (context, index) => Padding(
                        padding: EdgeInsets.all(8 * _zoom),
                        child: _PdfPage(
                          key: ValueKey('${widget.documentId}/$index/$_renderWidth'),
                          index: index,
                          documentId: widget.documentId,
                          textSelection: widget.textSelection && !pinching,
                          onTextHighlight: widget.onTextHighlight,
                          tiles: _zoom > 1.4 && !pinching ? _tiles(index) : null,
                          render: _render,
                          paper: widget.paper,
                          highlights: widget.highlights[index] ?? const [],
                          marks: widget.marks.where((mark) => mark.page == index).toList(),
                          marking: widget.marking,
                          marker: widget.marker,
                          pageSize: widget.pageSizes[index],
                          onMark: (rect) async => await widget.onMark?.call(index, rect) ?? false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      );
    },
  );

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    _tilesChanged.dispose();
    super.dispose();
  }
}

class _PdfPage extends StatefulWidget {
  const _PdfPage({super.key, required this.index, required this.render, required this.paper, required this.highlights,
    required this.marks, required this.marking, required this.marker, required this.pageSize, required this.onMark, required this.documentId, required this.textSelection, this.onTextHighlight, this.tiles});
  final Widget? tiles;
  final int documentId;
  final bool textSelection;
  final Future<bool> Function(int, List<Rect>)? onTextHighlight;
  final List<PageMark> marks;
  final bool marking;
  final String marker;
  final Size pageSize;
  final Future<bool> Function(Rect) onMark;
  final String paper;
  final List<Rect> highlights;
  final int index;
  final Future<Uint8List?> Function(int, bool Function()) render;
  @override
  State<_PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<_PdfPage> {
  Uint8List? _bytes;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.render(widget.index, () => mounted);
      if (mounted)
        setState(() {
          _bytes = bytes;
          _error = bytes == null ? 'Pusta strona.' : null;
        });
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is PlatformException
              ? e.message
              : 'Nie można wyświetlić strony.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: widget.paper == 'dark' ? Colors.black : widget.paper == 'warm' ? const Color(0xffffdbab) : Colors.white,
    child: _bytes != null
        ? Stack(fit: StackFit.expand, children: [
            ColorFiltered(
              colorFilter: paperFilter(widget.paper),
              child: Stack(fit: StackFit.expand, children: [Image.memory(_bytes!, fit: BoxFit.fill, semanticLabel: 'Strona ${widget.index + 1}'), if(widget.tiles != null) widget.tiles!]),
            ),
            IgnorePointer(child: CustomPaint(painter: MatchPainter(widget.highlights))),
            MarkLayer(marks: widget.marks, enabled: widget.marking, color: widget.marker, pageSize: widget.pageSize, onDraw: widget.onMark),
            if(widget.textSelection && !widget.marking && widget.onTextHighlight != null)
              PdfSelectionLayer(documentId: widget.documentId, page: widget.index, onHighlight: widget.onTextHighlight!),
          ])
        : Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(color: widget.paper == 'dark' ? Colors.white : Colors.black),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _error = null);
                          _load();
                        },
                        child: const Text('Spróbuj ponownie'),
                      ),
                    ],
                  ),
          ),
  );
  @override
  void dispose() {
    // The normal Flutter image cache would otherwise retain decoded off-screen pages.
    if (_bytes != null)
      PaintingBinding.instance.imageCache.evict(MemoryImage(_bytes!));
    super.dispose();
  }
}

class _ZoomScrollController extends ScrollController {
  double? pendingPixels;
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _ZoomScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    owner: this,
  );
}

class _ZoomScrollPosition extends ScrollPositionWithSingleContext {
  _ZoomScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.owner,
  });
  final _ZoomScrollController owner;
  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final target = owner.pendingPixels;
    if (target != null) {
      owner.pendingPixels = null;
      final bounded = target.clamp(minScrollExtent, maxScrollExtent);
      if ((pixels - bounded).abs() > 0.01) {
        correctPixels(bounded);
        return false;
      }
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}

// View-only filters: never applied to exported or shared bytes.
ColorFilter paperFilter(String paper) {
  if (paper == 'dark') return const ColorFilter.matrix([
    -1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0,
  ]);
  if (paper == 'warm') return const ColorFilter.matrix([
    1,0,0,0,0, 0,0.86,0,0,0, 0,0,0.67,0,0, 0,0,0,1,0,
  ]);
  return const ColorFilter.matrix([
    1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0,
  ]);
}
class MatchPainter extends CustomPainter {
  MatchPainter(this.rectangles);
  final List<Rect> rectangles;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x88ffb300);
    for (final r in rectangles) {
      canvas.drawRect(Rect.fromLTRB(r.left * size.width, r.top * size.height, r.right * size.width, r.bottom * size.height), paint);
    }
  }
  @override
  bool shouldRepaint(MatchPainter oldDelegate) => oldDelegate.rectangles != rectangles;
}
