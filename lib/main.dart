import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DokumentyApp());
}

class DokumentyApp extends StatelessWidget {
  const DokumentyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dokumenty',
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

class _ReaderHomeState extends State<ReaderHome> {
  static const _bridge = MethodChannel('dokumenty/files');
  final _transform = TransformationController();
  final _textScroll = ScrollController();
  Map<String, dynamic>? _document;
  Uint8List? _pageImage;
  bool _busy = false;
  bool _rendering = false;
  bool _choosing = false;
  int _page = 0;
  double _fontSize = 17;
  String? _error;
  String? _queuedUri;
  int _epoch = 0;
  String _query = '';
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bridge.setMethodCallHandler((call) async {
      if (call.method == 'incomingFile' && call.arguments is String) {
        await _open(call.arguments as String);
      }
    });
    _initial();
  }

  Future<void> _initial() async {
    try {
      final uri = await _bridge.invokeMethod<String>('initialUri');
      if (uri != null && mounted) await _open(uri);
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pick() async {
    if (_busy || _choosing || _rendering) return;
    setState(() => _choosing = true);
    try {
      final uri = await _bridge.invokeMethod<String>('pick');
      if (uri != null && mounted) await _open(uri);
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Nie można wybrać pliku.');
    } finally {
      if (mounted) setState(() => _choosing = false);
      _drain();
    }
  }

  Future<void> _open(String uri) async {
    if (_busy || _rendering) {
      _queuedUri = uri;
      return;
    }
    _epoch++;
    setState(() {
      _busy = true;
      _error = null;
      _document = null;
      _pageImage = null;
      _page = 0;
      _query = '';
      _elapsed = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    try {
      final data = await _bridge.invokeMapMethod<String, dynamic>('open', {
        'uri': uri,
      });
      if (!mounted) return;
      if (data == null) throw const FormatException('Brak danych dokumentu.');
      setState(() => _document = data);
      if (data['kind'] == 'pdf') await _loadPage(0);
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
    if (mounted && !_busy && !_rendering && !_choosing && _queuedUri != null) {
      final uri = _queuedUri!;
      _queuedUri = null;
      unawaited(_open(uri));
    }
  }

  Future<void> _loadPage(int index) async {
    final token = _epoch;
    setState(() => _rendering = true);
    try {
      final bytes = await _bridge.invokeMethod<Uint8List>('render', {
        'page': index,
        'width': 2000,
      });
      if (!mounted || token != _epoch) return;
      if (bytes == null) throw const FormatException('Pusta strona.');
      _transform.value = Matrix4.identity();
      setState(() {
        _pageImage = bytes;
        _page = index;
        _error = null;
      });
    } catch (e) {
      if (mounted && token == _epoch) {
        setState(
          () => _error = e is PlatformException
              ? e.message
              : 'Nie można wyświetlić strony.',
        );
      }
    } finally {
      if (mounted && token == _epoch) setState(() => _rendering = false);
      _drain();
    }
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
    if (_busy || _rendering) return;
    _epoch++;
    setState(() {
      _document = null;
      _pageImage = null;
      _error = null;
    });
    try {
      await _bridge.invokeMethod<void>('close');
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Nie udało się zamknąć podglądu.');
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
    if (target != null && mounted && !_busy && !_rendering)
      await _loadPage(target);
  }

  Future<void> _about() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dokumenty · 0.1.0'),
        content: const SingleChildScrollView(
          child: Text(
            'Wersja testowa. Pliki otwierają się lokalnie, bez internetu.\n\n'
            'Dokumenty Office otrzymują podgląd PDF zgodny z ustawieniami wydruku. '
            'Oryginały nie są zmieniane. Brakujące czcionki mogą zmienić układ.\n\n'
            'Na tym etapie: bez edycji, obsługi haseł i wyszukiwania w PDF. '
            'CSV jest wyświetlany jako tekst. Limit pliku: 100 MB; tekstu: 2 MB.\n\n'
            'Do renderowania użyto silnika LibreOffice 26.2.6.3. '
            'To niezależna aplikacja, nie oficjalny produkt The Document Foundation.',
          ),
        ),
        actions: [
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
    _bridge.setMethodCallHandler(null);
    _transform.dispose();
    _textScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final isPdf = document?['kind'] == 'pdf';
    final locked = _busy || _rendering || _choosing;
    return PopScope(
      canPop: document == null && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !locked) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: document != null
              ? IconButton(
                  onPressed: locked ? null : _close,
                  tooltip: 'Zamknij dokument',
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null,
          title: Text(
            document?['name'] as String? ?? 'Dokumenty',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (document != null)
              IconButton(
                onPressed: locked ? null : _pick,
                tooltip: 'Otwórz inny plik',
                icon: const Icon(Icons.folder_open_rounded),
              ),
            if (isPdf)
              IconButton(
                onPressed: locked ? null : _export,
                tooltip: 'Zapisz kopię PDF',
                icon: const Icon(Icons.save_alt_rounded),
              ),
            if (document == null)
              IconButton(
                onPressed: _about,
                tooltip: 'O aplikacji',
                icon: const Icon(Icons.info_outline_rounded),
              ),
          ],
        ),
        body: _busy && document == null
            ? _loading()
            : document == null
            ? _home()
            : isPdf
            ? _pdfView()
            : _textView(),
        bottomNavigationBar: isPdf ? _pageBar(locked) : null,
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
      FilledButton.icon(
        onPressed: _choosing ? null : _pick,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        icon: const Icon(Icons.folder_open_rounded),
        label: const Text('Otwórz plik'),
      ),
      if (_error != null)
        Padding(padding: const EdgeInsets.only(top: 18), child: _errorCard()),
      const SizedBox(height: 32),
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
        'Możesz też otworzyć załącznik z poczty lub pobrany plik i wybrać aplikację Dokumenty. Jeśli Android pokaże opcję „Zawsze”, możesz ustawić ją jako domyślną.',
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
      if (_document?['converted'] == true)
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          child: const Text(
            'Podgląd wydruku · oryginał pozostaje bez zmian',
            style: TextStyle(fontSize: 12),
          ),
        ),
      if (_error != null) _errorCard(),
      Expanded(
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xff333a3b),
                child: _pageImage == null
                    ? const Center(child: CircularProgressIndicator())
                    : InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: 6,
                        boundaryMargin: const EdgeInsets.all(20),
                        child: Center(
                          child: Image.memory(
                            _pageImage!,
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                            semanticLabel: 'Strona ${_page + 1} dokumentu',
                          ),
                        ),
                      ),
              ),
            ),
            if (_rendering)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
          ],
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
            onPressed: locked || _page == 0 ? null : () => _loadPage(_page - 1),
            tooltip: 'Poprzednia strona',
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          TextButton(
            onPressed: locked ? null : _goToPage,
            child: Text('${_page + 1} / $pages'),
          ),
          IconButton(
            onPressed: locked
                ? null
                : () => _transform.value = Matrix4.identity(),
            tooltip: 'Dopasuj stronę',
            icon: const Icon(Icons.fit_screen_rounded),
          ),
          IconButton(
            onPressed: locked || _page + 1 >= pages
                ? null
                : () => _loadPage(_page + 1),
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
