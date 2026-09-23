import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'continuous_pdf.dart';
import 'document_editor.dart';
import 'reading_tools.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DokumentyApp());
}

class DokumentyApp extends StatelessWidget {
  const DokumentyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Plikownik',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff246b64)),
      scaffoldBackgroundColor: const Color(0xfff5f6f2),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xfff5f6f2)),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff96ccc0),
        brightness: Brightness.dark,
      ),
    ),
    home: const ReaderHome(),
  );
}

class ReaderHome extends StatefulWidget {
  const ReaderHome({super.key});
  @override
  State<ReaderHome> createState() => _ReaderHomeState();
}

class _ReaderHomeState extends State<ReaderHome> with WidgetsBindingObserver {
  static const _bridge = MethodChannel('dokumenty/files');
  final _pdfKey = GlobalKey<ContinuousPdfState>();
  final _textScroll = ScrollController();
  Map<String, dynamic>? _document;
  bool _busy = false;
  bool _externalMode = false;
  bool _editing = false;
  bool _queuedExternal = false;
  bool _starting = true;
  List<Map<String, dynamic>> _recent = [];
  bool _choosing = false;
  bool _sharing = false;
  String _recentQuery = '';
  String _recentSort = 'recent';
  bool _bookmarkBusy = false;
  String _paper = 'original';
  bool _reading = false, _controlsVisible = true, _keepAwake = false, _pdfSearch = false;
  Map<int, List<Rect>> _highlights = {};
  DateTime _lastViewSave = DateTime.fromMillisecondsSinceEpoch(0);
  String? _openedUri;
  int _page = 0;
  double _fontSize = 17;
  String? _error;
  String? _queuedUri;
  String _query = '';
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bridge.setMethodCallHandler((call) async {
      if (call.method == 'incomingFile' && call.arguments is String) {
        await _open(call.arguments as String, external: true);
      }
    });
    _initial();
  }

  Future<void> _initial() async {
    try {
      try {
        final prefs = jsonDecode(await _bridge.invokeMethod<String>('readerPrefs') ?? '{}') as Map;
        _paper = ['original', 'dark', 'warm'].contains(prefs['paper']) ? prefs['paper'] as String : 'original';
        _keepAwake = prefs['awake'] == true;
        _recentSort = ['recent', 'oldest', 'name', 'nameDesc'].contains(prefs['sort']) ? prefs['sort'] as String : 'recent';
      } on PlatformException { /* Defaults remain usable. */ }
        on FormatException { /* Invalid stored preferences use defaults. */ }
      final uri = await _bridge.invokeMethod<String>('initialUri');
      if (uri != null && mounted)
        await _open(uri, external: true);
      else
        await _refreshRecent();
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) unawaited(_saveReading());
    if (state == AppLifecycleState.resumed) unawaited(_readerWindow());
  }

  Map<String, dynamic> _initialView() {
    try { return Map<String, dynamic>.from(jsonDecode(_document?['readingState'] as String? ?? '{}') as Map); }
    on FormatException { return {}; }
  }
  void _scheduleReadingSave() {
    final now = DateTime.now();
    if (now.difference(_lastViewSave).inMilliseconds < 900) return;
    _lastViewSave = now;
    unawaited(_saveReading());
  }
  Future<void> _saveReading() async {
    final state = _pdfKey.currentState;
    final id = _document?['documentId'];
    if (state == null || id == null) return;
    try { await _bridge.invokeMethod<void>('saveReading', {'documentId': id, 'view': jsonEncode(state.view)}); }
    on PlatformException { /* A failed bookmark must not interrupt reading. */ }
  }
  Future<void> _readerWindow() async {
    try {
      await _bridge.invokeMethod<void>('readerWindow', {
        'fullscreen': _reading && !_controlsVisible && !_editing,
        'awake': _document?['kind'] == 'pdf' && _keepAwake && !_editing,
      });
    } on PlatformException { if(mounted) _message('Nie udało się zmienić ustawień ekranu.'); }
  }
  void _toggleControls() {
    if (!_reading) return;
    setState(() => _controlsVisible = !_controlsVisible);
    unawaited(_readerWindow());
  }
  Future<void> _readingOptions() async {
    final documentId = _document?['documentId'];
    final fullscreen = await showModalBottomSheet<bool>(
      context: context, showDragHandle: true, isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, update) => SafeArea(
        child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Tryb czytania', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            for(final option in [('original', 'Oryginał'), ('dark', 'Ciemny'), ('warm', 'Ciepły')])
              ChoiceChip(label: Text(option.$2), selected: _paper == option.$1,
                onSelected: (_) { setState(() => _paper = option.$1); update(() {}); }),
          ]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Kolory dotyczą tylko podglądu. Tryb ciemny odwraca także zdjęcia i wykresy.')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Nie wygaszaj ekranu'), value: _keepAwake,
            onChanged: (value) { setState(() => _keepAwake = value); update(() {}); unawaited(_readerWindow()); }),
          const Text('Pełny ekran: dotknij dokumentu, aby pokazać lub schować przyciski. Wstecz kończy tryb pełnoekranowy.'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.fullscreen), label: const Text('Czytaj na pełnym ekranie')),
        ]))),
      )),
    );
    if(!mounted) return;
    if(fullscreen == true && _document?['documentId'] == documentId && _document?['kind'] == 'pdf') setState(() { _reading = true; _controlsVisible = false; _pdfSearch = false; _highlights = {}; });
    await _readerWindow();
    await _saveReaderPrefs();
  }
  Future<void> _saveReaderPrefs() async {
    try { await _bridge.invokeMethod<String>('readerPrefs', {'value': jsonEncode({'paper': _paper, 'awake': _keepAwake, 'sort': _recentSort})}); }
    on PlatformException { if(mounted) _message('Nie udało się zapamiętać ustawień.'); }
  }
  List<int> get _bookmarks => (_document?['bookmarks'] as List? ?? const []).map((page) => (page as num).toInt()).toList();
  Future<bool> _changeBookmark(int page, bool add, int documentId) async {
    if(_bookmarkBusy || _document?['documentId'] != documentId) return false;
    setState(() => _bookmarkBusy = true);
    try {
      final marks = await _bridge.invokeListMethod<dynamic>('bookmark', {'documentId': documentId, 'page': page, 'add': add});
      if(!mounted || _document?['documentId'] != documentId || marks == null) return false;
      setState(() => _document!['bookmarks'] = marks);
      return true;
    } on PlatformException catch(e) {
      if(mounted) _message(e.message ?? 'Nie udało się zapisać zakładki.');
      return false;
    } finally {
      if(mounted) setState(() => _bookmarkBusy = false);
      _drain();
    }
  }
  Future<void> _showBookmarks() async {
    final doc = _document!;
    final id = doc['documentId'] as int;
    final marks = _bookmarks;
    final names = (doc['sheetNames'] as List?)?.cast<String>() ?? const <String>[];
    bool deleting = false;
    final target = await showModalBottomSheet<int>(context: context, showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, update) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(children: [
          Text('Zakładki', style: Theme.of(context).textTheme.titleLarge),
          const Padding(padding: EdgeInsets.all(12), child: Text('Zapisane strony w tym podglądzie. Dodawaj je przyciskiem obok numeru strony.')),
          Expanded(child: marks.isEmpty ? const Center(child: Text('Nie masz jeszcze zakładek.')) : ListView.builder(
            itemCount: marks.length,
            itemBuilder: (context, index) {
              final page = marks[index];
              return ListTile(
                leading: const Icon(Icons.bookmark),
                title: Text(names.length == doc['pages'] ? names[page] : 'Strona ${page + 1}', maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: names.length == doc['pages'] ? Text('Strona ${page + 1}') : null,
                onTap: deleting ? null : () => Navigator.pop(context, page),
                trailing: IconButton(tooltip: 'Usuń zakładkę strony ${page + 1}', icon: const Icon(Icons.bookmark_remove_outlined),
                  onPressed: deleting ? null : () async {
                    update(() => deleting = true);
                    final removed = await _changeBookmark(page, false, id);
                    if(context.mounted) update(() { if(removed) marks.remove(page); deleting = false; });
                  }),
              );
            },
          )),
        ]),
      ))),
    );
    if(target != null && mounted && _document?['documentId'] == id) _pdfKey.currentState?.goToPage(target);
  }
  String _fileSize(dynamic bytes) {
    if(bytes is! num) return '—';
    if(bytes < 1024) return '${bytes.toInt()} B';
    final value = bytes < 1024 * 1024 ? bytes / 1024 : bytes / (1024 * 1024);
    return '${value.toStringAsFixed(1).replaceAll('.', ',')} ${bytes < 1024 * 1024 ? 'KB' : 'MB'}';
  }
  Future<void> _fileInfo() async {
    final doc = _document!;
    final details = <String>[
      doc['name'] as String,
      'Format: ${doc['extension'].toString().toUpperCase()}',
      'Rozmiar pliku: ${_fileSize(doc['sizeBytes'])}',
      if(doc['kind'] == 'pdf') 'Strony podglądu: ${doc['pages']}',
      if(doc['kind'] == 'pdf') 'Zakładki: ${_bookmarks.length}',
      if(doc['wholeSheets'] == true) 'Widok całych arkuszy, także ukrytych.',
      if(doc['converted'] == true && doc['wholeSheets'] != true) 'Podgląd wydruku dokumentu Office.',
    ];
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Informacje o pliku'),
      content: SingleChildScrollView(child: SelectableText(details.join('\n\n'))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zamknij'))],
    ));
  }
  Widget _recentDetails(Map<String, dynamic> entry) {
    final pages = (entry['pages'] as num?)?.toInt() ?? 0;
    final last = (entry['lastPage'] as num?)?.toInt();
    final subtitle = '${(entry['extension'] as String).toUpperCase()}${entry['sizeBytes'] == null ? '' : ' · ${_fileSize(entry['sizeBytes'])}'}';
    if(pages <= 0 || last == null) return Text(subtitle);
    final current = last.clamp(0, pages - 1).toInt() + 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(subtitle),
      Text('Ostatnio: strona $current z $pages'),
      const SizedBox(height: 4),
      LinearProgressIndicator(value: current / pages, minHeight: 3),
    ]);
  }

  Future<void> _thumbnails() async {
    final doc = _document!;
    final page = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => PageThumbnails(
      documentId: doc['documentId'] as int,
      sizes: (doc['pageSizes'] as List).map((p) => Size((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList(),
      current: _page, paper: _paper,
      names: (doc['sheetNames'] as List?)?.cast<String>() ?? const [],
    )));
    if(page != null && mounted && _document?['documentId'] == doc['documentId']) _pdfKey.currentState?.goToPage(page);
  }
  Future<void> _switchSheets() async {
    final documentId = _document?['documentId'];
    final uri = _openedUri;
    final whole = _document?['wholeSheets'] != true;
    if(whole) {
      final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Widok całych arkuszy'),
        content: const Text('Każda zakładka będzie jedną dużą stroną, także zakładki ukryte. Udostępniany podgląd PDF również będzie je zawierał. Oryginał pozostaje bez zmian.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Otwórz arkusze'))],
      ));
      if(yes != true || !mounted) return;
    }
    if(uri != null && _document?['documentId'] == documentId) await _open(uri, external: _externalMode, wholeSheets: whole);
  }

  Future<void> _refreshRecent() async {
    try {
      final rows = await _bridge.invokeListMethod<dynamic>('recent');
      if (mounted)
        setState(
          () => _recent = (rows ?? [])
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList(),
        );
    } on PlatformException catch (e) {
      if (mounted)
        _message(e.message ?? 'Nie można odczytać ostatnich dokumentów.');
    }
  }

  List<Map<String, dynamic>> get _visibleRecent {
    final query = _recentQuery.trim().toLowerCase();
    final rows = _recent.where((entry) =>
      (entry['name'] as String).toLowerCase().contains(query) ||
      (entry['extension'] as String).toLowerCase().contains(query)).toList();
    rows.sort((a, b) {
      final pinOrder = (b['pinned'] == true ? 1 : 0) - (a['pinned'] == true ? 1 : 0);
      if (pinOrder != 0) return pinOrder;
      if (_recentSort == 'name' || _recentSort == 'nameDesc') {
        final names = (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
        if (names != 0) return _recentSort == 'name' ? names : -names;
      }
      if (_recentSort == 'oldest') return ((a['openedAt'] as num?) ?? 0).compareTo((b['openedAt'] as num?) ?? 0);
      return ((b['openedAt'] as num?) ?? 0).compareTo((a['openedAt'] as num?) ?? 0);
    });
    return rows;
  }

  Future<void> _pinRecent(Map<String, dynamic> entry) async {
    try {
      await _bridge.invokeMethod<void>('pinRecent', {
        'id': entry['id'], 'pinned': entry['pinned'] != true,
      });
      await _refreshRecent();
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Nie udało się zmienić przypięcia.');
    }
  }

  Future<void> _shareDocument() async {
    final document = _document;
    if (document == null || _busy || _sharing || _editing) return;
    setState(() => _sharing = true);
    try {
      bool pdf = false;
      if (document['kind'] == 'pdf' && document['extension'] != 'pdf') {
        final choice = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text('Plik ${document['extension'].toString().toUpperCase()}'),
                subtitle: const Text('Oryginalny format i zawartość pliku'),
                onTap: () => Navigator.pop(context, false),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Podgląd PDF'),
                subtitle: const Text('Wygląd stron widoczny w podglądzie'),
                onTap: () => Navigator.pop(context, true),
              ),
            ]),
          ),
        );
        if (choice == null || !mounted) return;
        pdf = choice;
      }
      await _bridge.invokeMethod<void>('share', {
        'documentId': document['documentId'], 'pdf': pdf,
      });
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Nie udało się udostępnić dokumentu.');
    } finally {
      if (mounted) setState(() => _sharing = false);
      _drain();
    }
  }

  Future<void> _clearRecent() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wyczyścić ostatnie dokumenty?'),
        content: const Text(
          'Usunie nieprzypięte pozycje i ich lokalne kopie. Przypięte dokumenty oraz pliki źródłowe pozostaną.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wyczyść'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await _bridge.invokeMethod<void>('clearRecent');
      await _refreshRecent();
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Nie można wyczyścić listy.');
    }
  }

  Future<void> _pick() async {
    if (_busy || _choosing) return;
    setState(() => _choosing = true);
    try {
      final uri = await _bridge.invokeMethod<String>('pick');
      if (uri != null && mounted) await _open(uri, external: _externalMode);
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Nie można wybrać pliku.');
    } finally {
      if (mounted) setState(() => _choosing = false);
      _drain();
    }
  }

  Future<void> _open(String uri, {bool external = false, bool wholeSheets = false}) async {
    if (_busy || _editing || _sharing || _bookmarkBusy) {
      _queuedUri = uri;
      _queuedExternal = external;
      return;
    }
    final savePosition = _saveReading();
    setState(() {
      _busy = true;
      _externalMode = external;
      _error = null;
      _document = null;
      _reading = false; _controlsVisible = true; _pdfSearch = false; _highlights = {};
      _page = 0;
      _query = '';
      _elapsed = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    try {
      await savePosition;
      await _readerWindow();
      final data = await _bridge.invokeMapMethod<String, dynamic>('open', {
        'uri': uri, 'wholeSheets': wholeSheets,
      });
      if (!mounted) return;
      if (data == null) throw const FormatException('Brak danych dokumentu.');
      setState(() { _document = data; _openedUri = uri; });
      await _readerWindow();
      if (data['recentWarning'] is String)
        _message(data['recentWarning'] as String);
      await _refreshRecent();
    } catch (e) {
      if (mounted) {
        setState(() {
          _document = null;
          _error = e is PlatformException
              ? e.message
              : 'Nie udało się odczytać dokumentu.';
        });
      }
    } finally {
      _timer?.cancel();
      if (mounted) setState(() => _busy = false);
      _drain();
    }
  }

  void _drain() {
    if (mounted && !_busy && !_editing && !_choosing && !_sharing && !_bookmarkBusy && _queuedUri != null) {
      final uri = _queuedUri!;
      final external = _queuedExternal;
      _queuedUri = null;
      unawaited(_open(uri, external: external));
    }
  }

  Future<void> _editDocument({String? newFormat}) async {
    if (_busy || _editing) return;
    final source = newFormat == null ? _document : null;
    final format = newFormat ?? source?['extension'] as String?;
    if (format == null ||
        !['docx', 'odt', 'doc', 'rtf', 'txt'].contains(format))
      return;
    if (format == 'txt' &&
        ((source?['text'] as String?)?.length ?? 0) > 200000) {
      _message(
        'Ten plik jest za duży do edycji. Limit edytora to 200 000 znaków.',
      );
      return;
    }
    await _saveReading();
    _editing = true;
    await _readerWindow();
    final external = _externalMode;
    try {
      final uri = format == 'txt'
          ? await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) =>
                    DocumentEditor(format: format, document: source),
              ),
            )
          : await _bridge.invokeMethod<String>('openEditor', {
              'documentId': source?['documentId'],
              'createNew': source == null,
            });
      _editing = false;
      if (uri != null && mounted) {
        await _open(uri, external: external);
        if (mounted) _message('Zapisano dokument.');
      }
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Nie udało się otworzyć edytora.');
    } finally {
      _editing = false;
      unawaited(_readerWindow());
      _drain();
    }
  }

  Future<void> _newDocument() async {
    final format = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Nowy dokument'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'docx'),
            child: const Text('Dokument Word (.docx)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'txt'),
            child: const Text('Plik tekstowy (.txt)'),
          ),
        ],
      ),
    );
    if (format != null && mounted) await _editDocument(newFormat: format);
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final saved = await _bridge.invokeMethod<bool>('export');
      if (saved == true && mounted) _message('Zapisano kopię PDF.');
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Nie udało się zapisać pliku.');
    } finally {
      if (mounted) setState(() => _busy = false);
      _drain();
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _close() async {
    if (_sharing || _bookmarkBusy) return;
    if (_reading) {
      setState(() { _reading = false; _controlsVisible = true; });
      await _readerWindow();
      return;
    }
    await _saveReading();
    if (_externalMode) {
      _queuedUri = null;
      // Keep the document on screen until Android closes the activity: no home-screen flash.
      try {
        await _bridge.invokeMethod<void>('readerWindow', {'fullscreen': false, 'awake': false});
        await _bridge.invokeMethod<void>('finishExternal');
      } on PlatformException catch (e) {
        if (mounted) _message(e.message ?? 'Nie można zamknąć podglądu.');
      }
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _bridge.invokeMethod<void>('close');
      await _refreshRecent();
      if (mounted)
        setState(() {
          _document = null;
          _openedUri = null;
          _error = null;
          _recentQuery = '';
        });
      await _readerWindow();
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Nie udało się zamknąć podglądu.');
    } finally {
      if (mounted) setState(() => _busy = false);
      _drain();
    }
  }

  Future<void> _goToPage() async {
    final controller = TextEditingController(text: '${_page + 1}');
    final count = _document!['pages'] as int;
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Przejdź do strony'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: 'Numer od 1 do $count'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              final number = int.tryParse(controller.text);
              if (number != null && number >= 1 && number <= count)
                Navigator.pop(context, number - 1);
            },
            child: const Text('Przejdź'),
          ),
        ],
      ),
    );
    // Keep the controller alive until the dialog's closing animation finishes.
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
    if (target != null && mounted && !_busy)
      _pdfKey.currentState?.goToPage(target);
  }

  Future<void> _about() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plikownik · 0.10.1'),
        content: const SingleChildScrollView(
          child: Text(
            'Wersja testowa. Pliki otwierają się lokalnie, bez internetu.\n\n'
            'Dokumenty Office otrzymują podgląd PDF zgodny z ustawieniami wydruku. '
            'Sam podgląd nie zmienia pliku. Brakujące czcionki mogą zmienić układ.\n\n'
            'Edycja DOCX, ODT, DOC i RTF w dokumencie oraz edycja TXT. „Zapisz” aktualizuje plik, gdy aplikacja ma prawo zapisu; „Zapisz jako” tworzy kopię. Brak obsługi haseł. Wyszukiwanie PDF od Androida 15, bez OCR. '
            'CSV jest wyświetlany jako tekst. Limit pliku: 100 MB; tekstu: 2 MB.\n\n'
            'Do renderowania użyto silnika LibreOffice 26.2.6.3. '
            'To niezależna aplikacja, nie oficjalny produkt The Document Foundation.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _diagnostics();
            },
            child: const Text('Kopiuj diagnostykę'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _licenses();
            },
            child: const Text('Licencje'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Rozumiem'),
          ),
        ],
      ),
    );
  }

  Future<void> _diagnostics() async {
    try {
      final text = await _bridge.invokeMethod<String>('diagnostics');
      await Clipboard.setData(ClipboardData(text: text ?? 'Brak danych diagnostycznych.'));
      if (mounted) _message('Skopiowano diagnostykę. Możesz wkleić ją do wiadomości.');
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Nie udało się odczytać diagnostyki.');
    }
  }

  Future<void> _licenses() async {
    try {
      final notice = await _bridge.invokeMethod<String>('licenses');
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Licencje i źródła')),
            body: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.viewPaddingOf(context).bottom + 72,
              ),
              child: SelectableText(notice ?? 'Brak informacji o licencjach.'),
            ),
          ),
        ),
      );
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Nie można odczytać licencji.');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _bridge.setMethodCallHandler(null);
    _textScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final isPdf = document?['kind'] == 'pdf';
    final locked = _busy || _choosing || _sharing || _bookmarkBusy;
    return PopScope(
      canPop: document == null && !_busy && !_externalMode && !_starting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && (_externalMode || !locked)) _close();
      },
      child: Scaffold(
        appBar: _reading && !_controlsVisible ? null : AppBar(
          leading: document != null || _externalMode
              ? IconButton(
                  onPressed: locked ? null : _close,
                  tooltip: 'Zamknij dokument',
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null,
          title: Text(
            document?['name'] as String? ?? 'Plikownik',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (isPdf)
              IconButton(onPressed: locked ? null : _readingOptions, tooltip: 'Tryb czytania', icon: const Icon(Icons.chrome_reader_mode_outlined)),
            if (document != null &&
                [
                  'docx',
                  'odt',
                  'doc',
                  'rtf',
                  'txt',
                ].contains(document['extension']))
              IconButton(
                onPressed: locked ? null : () => _editDocument(),
                tooltip: 'Edytuj dokument',
                icon: const Icon(Icons.edit_outlined),
              ),
            if (document != null)
              IconButton(
                onPressed: locked ? null : _shareDocument,
                tooltip: 'Udostępnij dokument',
                icon: const Icon(Icons.share_outlined),
              ),
            if (document != null)
              PopupMenuButton<String>(
                tooltip: 'Więcej',
                enabled: !locked,
                onSelected: (value) {
                  if (value == 'open') _pick();
                  if (value == 'pdf') _export();
                  if (value == 'reading') _readingOptions();
                  if (value == 'pages') _thumbnails();
                  if (value == 'bookmarks') _showBookmarks();
                  if (value == 'info') _fileInfo();
                  if (value == 'search') setState(() { _pdfSearch = !_pdfSearch; _highlights = {}; });
                  if (value == 'sheets') _switchSheets();
                },
                itemBuilder: (_) => [
                  if (isPdf) const PopupMenuItem(value: 'pages', child: Text('Miniatury / arkusze')),
                  if (isPdf) PopupMenuItem(value: 'bookmarks', child: Text('Zakładki (${_bookmarks.length})')),
                  const PopupMenuItem(value: 'info', child: Text('Informacje o pliku')),
                  if (isPdf && document['searchAvailable'] == true) const PopupMenuItem(value: 'search', child: Text('Szukaj w dokumencie')),
                  if (['xls', 'xlsx', 'ods'].contains(document['extension']))
                    PopupMenuItem(value: 'sheets', child: Text(document['wholeSheets'] == true ? 'Podgląd wydruku' : 'Widok całych arkuszy')),
                  const PopupMenuItem(value: 'open', child: Text('Otwórz inny plik')),
                  if (isPdf) const PopupMenuItem(value: 'pdf', child: Text('Zapisz kopię PDF')),
                ],
              ),
            if (document == null)
              IconButton(
                onPressed: _about,
                tooltip: 'O aplikacji',
                icon: const Icon(Icons.info_outline_rounded),
              ),
          ],
        ),
        body: _starting || (_busy && document == null)
            ? _loading()
            : document == null
            ? (_externalMode
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error ?? 'Nie można otworzyć dokumentu.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _close,
                              child: const Text('Wróć'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _home())
            : isPdf
            ? _pdfView()
            : _textView(),
        bottomNavigationBar: isPdf && (!_reading || _controlsVisible) ? _pageBar(locked) : null,
      ),
    );
  }

  Widget _loading() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Przygotowuję dokument',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Wszystko odbywa się na telefonie.\nPierwsze otwarcie pliku Office może potrwać dłużej.\n\n${_elapsed}s',
            textAlign: TextAlign.center,
          ),
          if (_elapsed > 90)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Ten plik wymaga więcej czasu. Jeśli aplikacja długo nie odpowiada, zamknij ją i spróbuj mniejszego dokumentu.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    ),
  );

  Widget _home() => ListView(
    padding: EdgeInsets.fromLTRB(
      24,
      28,
      24,
      MediaQuery.viewPaddingOf(context).bottom + 72,
    ),
    children: [
      if (_recent.isEmpty) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Twoje pliki.\nPo prostu otwórz.',
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Text(
          'Czytaj dokumenty na telefonie.\nBez konta i bez internetu.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 28),
      ] else ...[
        Text(
          'Twoje dokumenty',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
      ],
      FilledButton.icon(
        onPressed: _choosing ? null : _pick,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        icon: const Icon(Icons.folder_open_rounded),
        label: const Text('Otwórz plik'),
      ),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: _choosing ? null : _newDocument,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Nowy dokument'),
      ),
      if (_error != null)
        Padding(padding: const EdgeInsets.only(top: 18), child: _errorCard()),
      const SizedBox(height: 24),
      if (_recent.isNotEmpty) ...[
        Row(
          children: [
            Expanded(
              child: Text(
                'Ostatnio otwierane',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Sortuj dokumenty', icon: const Icon(Icons.sort),
              onSelected: (value) { setState(() => _recentSort = value); unawaited(_saveReaderPrefs()); },
              itemBuilder: (_) => [
                for (final option in [('recent', 'Ostatnio otwierane'), ('oldest', 'Najdawniej otwierane'), ('name', 'Nazwa A–Z'), ('nameDesc', 'Nazwa Z–A')])
                  CheckedPopupMenuItem(value: option.$1, checked: _recentSort == option.$1, child: Text(option.$2)),
              ],
            ),
            IconButton(
              onPressed: _clearRecent,
              tooltip: 'Wyczyść ostatnie dokumenty',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const Text(
          'Do 10 lokalnych kopii, w tym do 5 przypiętych. Przypięte są na górze.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('recent-search'),
          onChanged: (text) => setState(() => _recentQuery = text),
          decoration: const InputDecoration(
            hintText: 'Szukaj po nazwie lub formacie',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (_visibleRecent.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('Brak pasujących dokumentów.')),
        for (final entry in _visibleRecent)
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(
                entry['name'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _recentDetails(entry),
              trailing: IconButton(
                tooltip: entry['pinned'] == true ? 'Odepnij dokument' : 'Przypnij dokument',
                icon: Icon(entry['pinned'] == true ? Icons.push_pin : Icons.push_pin_outlined),
                onPressed: entry['id'] == null ? null : () => _pinRecent(entry),
              ),
              onTap: () => _open(entry['uri'] as String, wholeSheets: entry['wholeSheets'] == true),
            ),
          ),
        const SizedBox(height: 24),
      ],
      _formatTile(
        Icons.picture_as_pdf_outlined,
        'Dokumenty PDF',
        'Oryginalne strony i powiększanie',
      ),
      _formatTile(
        Icons.article_outlined,
        'Word i LibreOffice Writer',
        'DOCX · ODT · DOC · RTF',
      ),
      _formatTile(
        Icons.table_chart_outlined,
        'Excel i LibreOffice Calc',
        'XLSX · ODS · XLS — podgląd wydruku',
      ),
      _formatTile(
        Icons.notes_rounded,
        'Pliki tekstowe',
        'TXT · CSV — czytelny tekst',
      ),
      const SizedBox(height: 24),
      const Text(
        'Możesz też otworzyć załącznik z poczty lub pobrany plik i wybrać aplikację Plikownik. Jeśli Android pokaże opcję „Zawsze”, możesz ustawić ją jako domyślną.',
      ),
    ],
  );

  Widget _formatTile(IconData icon, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    ),
  );

  Widget _errorCard() => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        _error ?? '',
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    ),
  );

  Widget _pdfView() => Column(
    children: [
      if (_document?['converted'] == true && !_reading)
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          child: Text(
            _document?['wholeSheets'] == true ? 'Całe arkusze · obejmuje także ukryte zakładki' : 'Podgląd wydruku · oryginał pozostaje bez zmian',
            style: TextStyle(fontSize: 12),
          ),
        ),
      if (_error != null) _errorCard(),
      if (_pdfSearch && (!_reading || _controlsVisible)) PdfSearchBar(
        key: ValueKey('search-${_document!['documentId']}'),
        documentId: _document!['documentId'] as int, pages: _document!['pages'] as int,
        onClose: () => setState(() { _pdfSearch = false; _highlights = {}; }),
        onResult: (page, bounds) {
          setState(() => _highlights = page < 0 ? {} : {page: bounds});
          if(bounds.isNotEmpty) _pdfKey.currentState?.revealMatch(page, bounds.first);
        },
      ),
      Expanded(
        child: ContinuousPdf(
          key: _pdfKey,
          paper: _paper,
          initialView: _initialView(),
          onViewChanged: _scheduleReadingSave,
          onTap: _toggleControls,
          highlights: _highlights,
          documentId: _document!['documentId'] as int,
          pageSizes: (_document!['pageSizes'] as List)
              .map(
                (p) => Size((p[0] as num).toDouble(), (p[1] as num).toDouble()),
              )
              .toList(),
          onPageChanged: (page) {
            if (mounted && _page != page) setState(() => _page = page);
          },
        ),
      ),
    ],
  );

  Widget _pageBar(bool locked) {
    final pages = _document!['pages'] as int;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: locked || _page == 0
                ? null
                : () => _pdfKey.currentState?.goToPage(_page - 1),
            tooltip: 'Poprzednia strona',
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(child: TextButton(
            onPressed: locked ? null : _goToPage,
            child: FittedBox(child: Text('${_page + 1} / $pages')),
          )),
          IconButton(
            onPressed: locked ? null : () => _changeBookmark(_page, !_bookmarks.contains(_page), _document!['documentId'] as int),
            tooltip: _bookmarks.contains(_page) ? 'Usuń zakładkę' : 'Dodaj zakładkę',
            icon: Icon(_bookmarks.contains(_page) ? Icons.bookmark : Icons.bookmark_add_outlined),
          ),
          IconButton(
            onPressed: locked ? null : () => _pdfKey.currentState?.fitWidth(),
            tooltip: 'Dopasuj stronę',
            icon: const Icon(Icons.fit_screen_rounded),
          ),
          IconButton(
            onPressed: locked || _page + 1 >= pages
                ? null
                : () => _pdfKey.currentState?.goToPage(_page + 1),
            tooltip: 'Następna strona',
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _textView() {
    final text = _document!['text'] as String;
    final matches = _query.isEmpty
        ? <RegExpMatch>[]
        : RegExp(
            RegExp.escape(_query),
            caseSensitive: false,
          ).allMatches(text).take(2000).toList();
    final spans = <TextSpan>[];
    int end = 0;
    for (final match in matches) {
      spans.add(TextSpan(text: text.substring(end, match.start)));
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(
            backgroundColor: Color(0xffffd875),
            color: Colors.black,
          ),
        ),
      );
      end = match.end;
    }
    spans.add(TextSpan(text: text.substring(end)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Szukaj w tekście',
                    suffixText: _query.isEmpty
                        ? null
                        : '${matches.length}${matches.length == 2000 ? '+' : ''}',
                  ),
                ),
              ),
              IconButton(
                onPressed: _fontSize <= 12
                    ? null
                    : () => setState(() => _fontSize -= 2),
                tooltip: 'Mniejszy tekst w podglądzie',
                icon: const Icon(Icons.text_decrease),
              ),
              IconButton(
                onPressed: _fontSize >= 28
                    ? null
                    : () => setState(() => _fontSize += 2),
                tooltip: 'Większy tekst w podglądzie',
                icon: const Icon(Icons.text_increase),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _textScroll,
            child: SingleChildScrollView(
              controller: _textScroll,
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.viewPaddingOf(context).bottom + 72,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SelectableText.rich(
                  TextSpan(children: spans),
                  style: TextStyle(fontSize: _fontSize, height: 1.6),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
