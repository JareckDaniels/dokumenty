import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DocumentEditor extends StatefulWidget {
  const DocumentEditor({super.key, required this.format, this.document});
  final String format;
  final Map<String, dynamic>? document;
  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  static const _bridge = MethodChannel('dokumenty/files');
  late final TextEditingController _text;
  late final TextEditingController _name;
  bool _dirty = false, _saving = false, _allowPop = false, _asking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final originalName = widget.document?['name'] as String?;
    _name = TextEditingController(
      text: originalName == null
          ? 'Nowy dokument.${widget.format}'
          : '${originalName.replaceFirst(RegExp(r'\.[^.]+$'), '')}-edycja.${widget.format}',
    );
    _text = TextEditingController(
      text: widget.format == 'txt'
          ? (widget.document?['text'] as String? ?? '')
          : '',
    );
    _name.addListener(_changed);
    _text.addListener(_changed);
  }

  void _changed() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  Future<void> _leave() async {
    if (_saving || _asking) return;
    _asking = true;
    bool leave = true;
    if (_dirty) {
      leave =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Odrzucić niezapisane zmiany?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Pisz dalej'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Odrzuć'),
                ),
              ],
            ),
          ) ??
          false;
    }
    _asking = false;
    if (!mounted || !leave) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_text.text.length > 200000) {
      setState(() => _error = 'Limit edytora to 200 000 znaków.');
      return;
    }
    String name = _name.text.trim();
    if (name.isEmpty || name.contains('/') || name.contains('\\')) {
      setState(() => _error = 'Podaj nazwę pliku bez ścieżki folderu.');
      return;
    }
    if (!name.toLowerCase().endsWith('.${widget.format}'))
      name += '.${widget.format}';
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uri = await _bridge.invokeMethod<String>('saveEdited', {
        'format': widget.format,
        'filename': name,
        'text': _text.text,
        'createNew': widget.document == null,
        'documentId': widget.document?['documentId'],
      });
      if (uri != null && mounted) {
        setState(() {
          _allowPop = true;
          _dirty = false;
          _saving = false;
        });
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, uri);
      }
    } on PlatformException catch (e) {
      if (mounted)
        setState(
          () => _error = e.message ?? 'Nie udało się zapisać dokumentu.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _saving ? null : _leave,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.document == null ? 'Nowy dokument TXT' : 'Edytuj TXT',
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_as_outlined),
            label: const Text('Zapisz jako'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_saving) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _name,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Nazwa nowego pliku',
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Zacznij pisać…',
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: TextField(
                  key: const ValueKey('editor-text'),
                  controller: _text,
                  enabled: !_saving,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(
                    fontSize: widget.format == 'txt'
                        ? 17
                        : _fontSize.toDouble(),
                    fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
                  ),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: _append
                        ? 'Wpisz tekst do dopisania…'
                        : 'Zacznij pisać…',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _text.dispose();
    _name.dispose();
    super.dispose();
  }
}
