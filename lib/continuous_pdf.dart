import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One continuous document. Zoom changes the layout, so vertical scrolling
/// continues to work at every zoom level instead of panning a single page.
class ContinuousPdf extends StatefulWidget {
  const ContinuousPdf({
    super.key,
    required this.documentId,
    required this.pageSizes,
    required this.onPageChanged,
  });
  final int documentId;
  final List<Size> pageSizes;
  final ValueChanged<int> onPageChanged;
  @override
  State<ContinuousPdf> createState() => ContinuousPdfState();
}

class ContinuousPdfState extends State<ContinuousPdf> {
  static const _bridge = MethodChannel('dokumenty/files');
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final Map<int, Offset> _pointers = {};
  Future<void> _renderQueue = Future<void>.value();
  double _zoom = 1;
  double _viewportWidth = 1;
  double _startZoom = 1, _startDistance = 1;
  Offset _anchor = Offset.zero;
  List<double> _offsets = [0];
  int _reportedPage = -1;
  int _layoutSerial = 0;

  @override
  void initState() {
    super.initState();
    _vertical.addListener(_reportPage);
  }

  @override
  void didUpdateWidget(covariant ContinuousPdf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _zoom = 1;
      _reportedPage = -1;
      _pointers.clear();
      _layout();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_vertical.hasClients) _vertical.jumpTo(0);
        if (_horizontal.hasClients) _horizontal.jumpTo(0);
      });
    }
  }

  void _layout() {
    final width = math.max(1.0, _viewportWidth * _zoom - 16);
    _offsets = [0];
    for (final size in widget.pageSizes) {
      _offsets.add(_offsets.last + width * size.height / size.width + 16);
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
    if (!_vertical.hasClients || widget.pageSizes.isEmpty) return;
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

  void fitWidth() => _changeZoom(1, const Offset(0, 24));

  void _changeZoom(double value, Offset focal, {Offset? anchor}) {
    if (!_vertical.hasClients) return;
    final oldWidth = math.max(1.0, _viewportWidth * _zoom - 16);
    final documentAnchor =
        anchor ??
        Offset(
          ((_horizontal.hasClients ? _horizontal.offset : 0) + focal.dx) /
              oldWidth,
          (_vertical.offset +
                  focal.dy -
                  16 * _pageAt(_vertical.offset + focal.dy)) /
              oldWidth,
        );
    final anchorPage = _pageAt(_vertical.offset + focal.dy);
    setState(() {
      _zoom = value.clamp(1.0, 4.0);
      _layout();
    });
    final width = math.max(1.0, _viewportWidth * _zoom - 16);
    final serial = ++_layoutSerial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || serial != _layoutSerial || !_vertical.hasClients) return;
      _vertical.jumpTo(
        (documentAnchor.dy * width + 16 * anchorPage - focal.dy).clamp(
          0.0,
          _vertical.position.maxScrollExtent,
        ),
      );
      if (_horizontal.hasClients) {
        _horizontal.jumpTo(
          (documentAnchor.dx * width - focal.dx).clamp(
            0.0,
            _horizontal.position.maxScrollExtent,
          ),
        );
      }
      _reportPage();
    });
  }

  void _down(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      final points = _pointers.values.toList();
      final focal = (points[0] + points[1]) / 2;
      _startDistance = math.max(1.0, (points[0] - points[1]).distance);
      _startZoom = _zoom;
      final width = math.max(1.0, _viewportWidth * _zoom - 16);
      _anchor = Offset(
        ((_horizontal.hasClients ? _horizontal.offset : 0) + focal.dx) / width,
        ((_vertical.hasClients ? _vertical.offset : 0) +
                focal.dy -
                16 *
                    _pageAt(
                      (_vertical.hasClients ? _vertical.offset : 0) + focal.dy,
                    )) /
            width,
      );
      // Stop any fling when the second finger starts a pinch.
      if (_vertical.hasClients) _vertical.jumpTo(_vertical.offset);
      if (_horizontal.hasClients) _horizontal.jumpTo(_horizontal.offset);
      setState(() {});
    }
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length != 2) return;
    final points = _pointers.values.toList();
    final scale = (points[0] - points[1]).distance / _startDistance;
    _changeZoom(
      _startZoom * scale,
      (points[0] + points[1]) / 2,
      anchor: _anchor,
    );
  }

  void _up(PointerEvent event) {
    final wasPinching = _pointers.length >= 2;
    _pointers.remove(event.pointer);
    if (wasPinching && mounted) setState(() {});
  }

  Future<Uint8List?> _render(int index, bool Function() stillVisible) {
    final documentId = widget.documentId;
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
            'width': 1800,
            'documentId': documentId,
          }),
        );
      } catch (e, stack) {
        result.completeError(e, stack);
      }
    });
    return result.future;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _viewportWidth = constraints.maxWidth;
      _layout();
      final pinching = _pointers.length >= 2;
      return ColoredBox(
        color: const Color(0xff333a3b),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            physics: pinching
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
                  physics: pinching
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
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: _PdfPage(
                      key: ValueKey('${widget.documentId}/$index'),
                      index: index,
                      render: _render,
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
    super.dispose();
  }
}

class _PdfPage extends StatefulWidget {
  const _PdfPage({super.key, required this.index, required this.render});
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
    color: Colors.white,
    child: _bytes != null
        ? Image.memory(
            _bytes!,
            fit: BoxFit.fill,
            semanticLabel: 'Strona ${widget.index + 1}',
          )
        : Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.black),
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
