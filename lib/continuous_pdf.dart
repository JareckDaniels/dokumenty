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
  final _vertical = _ZoomScrollController();
  final _horizontal = _ZoomScrollController();
  final Map<int, Offset> _pointers = {};
  Future<void> _renderQueue = Future<void>.value();
  double _zoom = 1;
  double _viewportWidth = 1;
  double _startZoom = 1, _startDistance = 1;
  Offset _anchor = Offset.zero;
  Offset _pinchStart = Offset.zero;
  Offset _pinchFocal = Offset.zero;
  double _previewZoom = 1;
  bool _pinching = false;
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
      _pinching = false;
      _previewZoom = 1;
      _vertical.pendingPixels = 0;
      _horizontal.pendingPixels = 0;
      _layoutSerial++;
      _layout();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_vertical.hasClients) _vertical.jumpTo(0);
        if (_horizontal.hasClients) _horizontal.jumpTo(0);
      });
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
    final zoom = value.clamp(1.0, 4.0);
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
      if (mounted && serial == _layoutSerial) _reportPage();
    });
  }

  void _down(PointerDownEvent event) {
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
              .clamp(1.0, 4.0);
    });
  }

  void _up(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pinching && _pointers.length < 2)
      _commitZoom(_previewZoom, _pinchFocal, _anchor);
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
      return ColoredBox(
        color: const Color(0xff333a3b),
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
                        padding: EdgeInsets.all(8 * _zoom),
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
