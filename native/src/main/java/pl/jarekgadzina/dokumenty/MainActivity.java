package pl.jarekgadzina.dokumenty;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.pdf.PdfRenderer;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import org.libreoffice.kit.Document;
import org.libreoffice.kit.LibreOfficeKit;
import org.libreoffice.kit.Office;
import java.io.*;
import java.nio.ByteBuffer;
import java.nio.charset.*;
import java.nio.file.Files;
import java.util.*;
import java.util.concurrent.*;
import java.security.MessageDigest;
import java.nio.file.StandardCopyOption;
import org.json.JSONArray;
import org.json.JSONObject;

/** Native file access and serialized, offline LibreOffice/PDF work. */
public class MainActivity extends FlutterActivity {
    private static final int PICK = 41, EXPORT = 42;
    private static final long MAX_FILE = 100L * 1024 * 1024;
    // LOK calls must always run on one and the same thread, including across activity recreation.
    static final ExecutorService WORKER = Executors.newSingleThreadExecutor();
    static Office office;
    private OfficeEditor officeEditor;
    private MethodChannel channel;
    private MethodChannel.Result pickerResult, exportResult;
    private String initialUri;
    private boolean flutterReady;
    private PdfRenderer pdf;
    private ParcelFileDescriptor descriptor;
    private File displayedPdf, exportSource;
    private File currentSource;
    private String currentExtension;
    private boolean editSave;
    private String currentName;
    private Uri currentUri;
    private long documentId = 0;
    private static final Set<String> SUPPORTED = new HashSet<>(Arrays.asList(
        "pdf", "txt", "csv", "doc", "docx", "odt", "xls", "xlsx", "ods", "rtf"));
    private static final String[] TYPES = {
        "application/pdf", "text/plain", "text/csv", "application/msword", "application/rtf",
        "text/rtf", "application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/vnd.oasis.opendocument.text", "application/vnd.oasis.opendocument.spreadsheet"
    };

    @Override public void configureFlutterEngine(@NonNull FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        AppDiagnostics.install(this);
        channel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "dokumenty/files");
        initialUri = intentUri(getIntent());
        channel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "initialUri":
                    flutterReady = true; result.success(initialUri); initialUri = null; break;
                case "pick":
                    if (pickerResult != null) { result.error("BUSY", "Wybór pliku jest już otwarty.", null); break; }
                    Intent pick = new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE);
                    pick.setType("*/*"); pick.putExtra(Intent.EXTRA_MIME_TYPES, TYPES);
                    pickerResult = result;
                    try { startActivityForResult(pick, PICK); }
                    catch (Exception e) { pickerResult = null; fail(result, e); }
                    break;
                case "open":
                    String uri = call.argument("uri");
                    submit(result, () -> open(Uri.parse(Objects.requireNonNull(uri)))); break;
                case "render":
                    Number index = call.argument("page"); Number width = call.argument("width");
                    Number requestedDocument = call.argument("documentId");
                    submit(result, () -> {
                        if (requestedDocument == null || requestedDocument.longValue() != documentId)
                            throw new IOException("Podgląd dokumentu został zamknięty.");
                        return render(index.intValue(), width.intValue());
                    }); break;
                case "share":
                    Number shareId=call.argument("documentId");
                    boolean sharePdf=Boolean.TRUE.equals(call.argument("pdf"));
                    WORKER.execute(() -> {
                        try {
                            if(shareId==null || shareId.longValue()!=documentId || currentSource==null)
                                throw new IOException("Otwórz ponownie dokument przed udostępnieniem.");
                            File source=sharePdf?displayedPdf:currentSource;
                            if(source==null)throw new IOException("Ten dokument nie ma podglądu PDF.");
                            String ext=sharePdf?"pdf":currentExtension;
                            String name=sharePdf?currentName.replaceFirst("\\.[^.]+$", "")+".pdf":currentName;
                            File attachment=ShareFiles.snapshot(getCacheDir(),source,name,ext);
                            String mime=ShareFiles.mime(ext);
                            runOnUiThread(() -> {
                                try {
                                    if(isFinishing() || isDestroyed())throw new IOException("Podgląd został zamknięty.");
                                    Uri content=androidx.core.content.FileProvider.getUriForFile(this,getPackageName()+".sharedfiles",attachment);
                                    Intent send=new Intent(Intent.ACTION_SEND).setType(mime);
                                    send.putExtra(Intent.EXTRA_STREAM,content);
                                    send.setClipData(android.content.ClipData.newUri(getContentResolver(),attachment.getName(),content));
                                    send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                    Intent chooser=Intent.createChooser(send,"Udostępnij dokument");
                                    chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                    startActivity(chooser); result.success(null);
                                }catch(Exception e){fail(result,e);}
                            });
                        }catch(Exception e){runOnUiThread(() -> fail(result,e));}
                    });
                    break;
                case "pinRecent":
                    String pinId=call.argument("id");
                    boolean pinned=Boolean.TRUE.equals(call.argument("pinned"));
                    submit(result,() -> {pinRecent(pinId,pinned);return null;}); break;
                case "export":
                    if (displayedPdf == null) { result.error("NO_PDF", "Najpierw otwórz dokument.", null); break; }
                    if (exportResult != null) { result.error("BUSY", "Zapisywanie jest już otwarte.", null); break; }
                    exportSource = displayedPdf; exportResult = result;
                    Intent save = new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE);
                    save.setType("application/pdf");
                    save.putExtra(Intent.EXTRA_TITLE, currentName.replaceFirst("\\.[^.]+$", "") + "-podglad.pdf");
                    try { startActivityForResult(save, EXPORT); }
                    catch (Exception e) { exportResult = null; exportSource = null; fail(result, e); }
                    break;
                case "openEditor":
                    Number editId = call.argument("documentId");
                    boolean newOffice = Boolean.TRUE.equals(call.argument("createNew"));
                    if (officeEditor != null) { result.error("BUSY", "Edytor jest już otwarty.", null); break; }
                    WORKER.execute(() -> {
                        try {
                            if (!newOffice && (editId == null || editId.longValue() != documentId || currentSource == null ||
                                !Arrays.asList("docx", "odt", "doc", "rtf").contains(currentExtension)))
                                throw new IOException("Otwórz ponownie dokument do edycji.");
                            ensureOffice();
                            File source = currentSource;
                            String ext = currentExtension, name = currentName;
                            if (newOffice) {
                                source = File.createTempFile("new-document-", ".docx", getCacheDir());
                                DocumentEdits.writeDocx(null, source, "", 12, false, false);
                                ext = "docx"; name = "Nowy dokument.docx";
                            }
                            final File editSource = source;
                            final String editExt = ext, editName = name;
                            final String initialSaveUri = !newOffice && currentUri != null && "content".equals(currentUri.getScheme())
                                && checkUriPermission(currentUri, android.os.Process.myPid(), android.os.Process.myUid(), Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                                    == android.content.pm.PackageManager.PERMISSION_GRANTED ? currentUri.toString() : null;
                            runOnUiThread(() -> {
                                if (isFinishing() || isDestroyed()) { result.error("CLOSED", "Aplikacja została zamknięta.", null); return; }
                                officeEditor = new OfficeEditor(this, editSource, editExt, editName, initialSaveUri, result, () -> officeEditor = null);
                                officeEditor.show();
                            });
                        } catch (Exception | LinkageError e) { runOnUiThread(() -> fail(result, e)); }
                    });
                    break;
                case "saveEdited":
                    String editText = call.argument("text");
                    String format = call.argument("format");
                    String filename = call.argument("filename");
                    Number sourceId = call.argument("documentId");
                    boolean createNew = Boolean.TRUE.equals(call.argument("createNew"));
                    WORKER.execute(() -> {
                        try {
                            if (!"txt".equals(format)) throw new IOException("Ten format nie ma jeszcze edycji.");
                            if (!createNew && (sourceId == null || sourceId.longValue() != documentId || currentSource == null || !format.equals(currentExtension)))
                                throw new IOException("Dokument źródłowy zmienił się. Otwórz edycję ponownie.");
                            if (editText == null || editText.length() > 200000) throw new IOException("Limit edytora to 200 000 znaków.");
                            File output = File.createTempFile("edited-", "." + format, getCacheDir());
                            Files.write(output.toPath(), editText.getBytes(StandardCharsets.UTF_8));
                            runOnUiThread(() -> beginEditSave(output, filename, format, result));
                        } catch (Exception e) { runOnUiThread(() -> fail(result, e)); }
                    });
                    break;
                case "close": submit(result, () -> { closePdf(); return null; }); break;
                case "finishExternal":
                    result.success(null);
                    finish();
                    break;
                case "recent": submit(result, this::recentFiles); break;
                case "clearRecent": submit(result, () -> {
                    clearUnpinned();
                    return null;
                }); break;
                case "diagnostics": submit(result, () -> AppDiagnostics.read(this)); break;
                case "licenses":
                    submit(result, () -> {
                        try (InputStream in = getAssets().open("third_party/NOTICE.txt")) {
                            return new String(readLimited(in, 4 * 1024 * 1024), StandardCharsets.UTF_8);
                        }
                    }); break;
                default: result.notImplemented();
            }
        });
    }

    @SuppressWarnings("deprecation")
    private String intentUri(Intent intent) {
        if (intent == null) return null;
        Uri uri = null;
        if (Intent.ACTION_VIEW.equals(intent.getAction())) uri = intent.getData();
        if (Intent.ACTION_SEND.equals(intent.getAction())) uri = intent.getParcelableExtra(Intent.EXTRA_STREAM);
        return uri == null ? null : uri.toString();
    }

    @Override protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent); setIntent(intent);
        String uri = intentUri(intent);
        if (uri != null) {
            if (flutterReady && channel != null) channel.invokeMethod("incomingFile", uri);
            else initialUri = uri;
        }
    }

    @Override protected void onActivityResult(int request, int code, Intent data) {
        super.onActivityResult(request, code, data);
        if (request == PICK && pickerResult != null) {
            MethodChannel.Result r = pickerResult; pickerResult = null;
            r.success(code == Activity.RESULT_OK && data != null && data.getData() != null
                ? data.getData().toString() : null);
        }
        if (request == EXPORT && exportResult != null) {
            MethodChannel.Result r = exportResult; exportResult = null;
            File source = exportSource; exportSource = null;
            boolean edited = editSave; editSave = false;
            if (code != Activity.RESULT_OK || data == null || data.getData() == null) {
                if (edited && source != null) source.delete();
                r.success(edited ? null : false); return;
            }
            Uri target = data.getData();
            submit(r, () -> {
                try (InputStream in = new FileInputStream(source);
                     OutputStream out = getContentResolver().openOutputStream(target, "wt")) {
                    if (out == null) throw new IOException("Nie można zapisać pliku w wybranym miejscu.");
                    copy(in, out, Long.MAX_VALUE);
                } finally { if (edited) source.delete(); }
                return edited ? target.toString() : true;
            });
        }
    }

    void overwriteEdited(File output, String targetUri, MethodChannel.Result result) {
        submit(result, () -> {
            File backup = File.createTempFile("save-backup-", "." + currentExtension, getFilesDir());
            try {
                Uri target = Uri.parse(targetUri);
                SafeSave.replace(output, backup,
                    () -> getContentResolver().openInputStream(target),
                    () -> getContentResolver().openOutputStream(target, "wt"));
                return targetUri;
            } finally { output.delete(); }
        });
    }

    void beginEditSave(File output, String filename, String format, MethodChannel.Result result) {
        if (isFinishing() || isDestroyed()) { result.error("CLOSED", "Edytor został zamknięty.", null); return; }
        if (exportResult != null) { result.error("BUSY", "Okno zapisu jest już otwarte.", null); return; }
        exportSource = output; exportResult = result; editSave = true;
        Intent save = new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE);
        switch (format) {
            case "docx": save.setType("application/vnd.openxmlformats-officedocument.wordprocessingml.document"); break;
            case "odt": save.setType("application/vnd.oasis.opendocument.text"); break;
            case "doc": save.setType("application/msword"); break;
            case "rtf": save.setType("application/rtf"); break;
            case "pdf": save.setType("application/pdf"); break;
            default: save.setType("text/plain");
        }
        save.putExtra(Intent.EXTRA_TITLE, filename == null || filename.trim().isEmpty() ? "Nowy dokument." + format : filename);
        try { startActivityForResult(save, EXPORT); }
        catch (Exception e) { exportSource = null; exportResult = null; editSave = false; fail(result, e); }
    }

    private void submit(MethodChannel.Result result, Callable<Object> task) {
        WORKER.execute(() -> {
            try { Object value = task.call(); runOnUiThread(() -> result.success(value)); }
            catch (Exception | LinkageError e) { runOnUiThread(() -> fail(result, e)); }
        });
    }
    private void fail(MethodChannel.Result result, Throwable e) {
        String message = e.getMessage();
        if (e instanceof SecurityException) message = "Plik jest zaszyfrowany albo aplikacja nie ma dostępu. Wybierz go przyciskiem Otwórz plik.";
        if (e instanceof LinkageError) message = "Nie udało się uruchomić silnika dokumentów. Ta wersja wymaga Androida ARM64.";
        result.error("DOCUMENT_ERROR", message == null ? "Nie udało się otworzyć dokumentu." : message, null);
    }

    private Map<String, Object> open(Uri uri) throws Exception {
        String scheme = uri.getScheme();
        if (!"content".equals(scheme) && !"file".equals(scheme)) throw new IOException("Obsługiwane są pliki lokalne. Pobierz dokument na telefon.");
        closePdf();
        String name = null;
        if ("content".equals(scheme)) {
            try (Cursor c = getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
                if (c != null && c.moveToFirst()) name = c.getString(0);
            }
        } else name = new File(Objects.requireNonNull(uri.getPath())).getName();
        String rememberedName = recentName(uri);
        if (rememberedName != null) name = rememberedName;
        if (name == null || name.trim().isEmpty()) name = "Dokument";
        String extension = name.contains(".") ? name.substring(name.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT) : "";
        if (!SUPPORTED.contains(extension)) {
            extension = extensionForMime(getContentResolver().getType(uri));
            if (extension == null) throw new IOException("Nieobsługiwany format. Wybierz PDF, TXT, CSV, DOC/DOCX, ODT, XLS/XLSX, ODS lub RTF.");
        }
        File cacheRoot = new File(getCacheDir(), "documents");
        if (!cacheRoot.exists() && !cacheRoot.mkdirs()) throw new IOException("Brak miejsca na podgląd.");
        File[] stale = cacheRoot.listFiles();
        if (stale != null) for (File f : stale) if (f.lastModified() < System.currentTimeMillis() - 86400000L) removeTree(f);
        File dir = new File(cacheRoot, UUID.randomUUID().toString());
        if (!dir.mkdirs()) throw new IOException("Nie można przygotować pliku.");
        File input = new File(dir, "source." + extension);
        try (InputStream in = getContentResolver().openInputStream(uri); OutputStream out = new FileOutputStream(input)) {
            if (in == null) throw new IOException("Nie można odczytać pliku.");
            copy(in, out, MAX_FILE);
        }
        currentName = name;
        Map<String, Object> info = new HashMap<>();
        info.put("name", name); info.put("extension", extension);
        info.put("documentId", documentId);
        if (extension.equals("txt") || extension.equals("csv")) {
            if (input.length() > 2 * 1024 * 1024) throw new IOException("Podgląd tekstu obsługuje pliki do 2 MB.");
            info.put("kind", "text"); info.put("text", decodeText(Files.readAllBytes(input.toPath())));
            rememberSafely(uri, input, name, extension, info);
            currentSource = input; currentExtension = extension; currentUri = uri;
            return info;
        }
        File preview = input;
        if (!extension.equals("pdf")) {
            ensureOffice();
            Document document = office.documentLoad(Uri.fromFile(input).toString());
            if (document == null) throw new IOException("Silnik nie otworzył dokumentu. Plik może być uszkodzony lub zabezpieczony hasłem.");
            try {
                preview = new File(dir, "preview.pdf");
                document.saveAs(Uri.fromFile(preview).toString(), "pdf", "");
                if (!preview.isFile() || preview.length() < 5) throw new IOException("Nie udało się przygotować podglądu PDF.");
            } finally { document.destroy(); }
        }
        try {
            descriptor = ParcelFileDescriptor.open(preview, ParcelFileDescriptor.MODE_READ_ONLY);
            pdf = new PdfRenderer(descriptor);
            if (pdf.getPageCount() == 0) throw new IOException("Dokument nie ma stron do wyświetlenia.");
            displayedPdf = preview;
            info.put("kind", "pdf"); info.put("pages", pdf.getPageCount());
            info.put("documentId", documentId);
            List<List<Integer>> sizes = new ArrayList<>();
            for (int i = 0; i < pdf.getPageCount(); i++) {
                try (PdfRenderer.Page page = pdf.openPage(i)) {
                    sizes.add(Arrays.asList(page.getWidth(), page.getHeight()));
                }
            }
            info.put("pageSizes", sizes);
            info.put("converted", !extension.equals("pdf"));
            rememberSafely(uri, input, name, extension, info);
            currentSource = input; currentExtension = extension; currentUri = uri;
            return info;
        } catch (Exception e) { closePdf(); throw e; }
    }

    private void ensureOffice() throws Exception {
        if (office != null) return;
        File marker = new File(getFilesDir(), "engine-26.2.6.3-ready");
        if (!marker.exists()) {
            unpack("unpack", new File(getApplicationInfo().dataDir));
            if (!marker.createNewFile()) throw new IOException("Nie można zapisać konfiguracji silnika.");
        }
        LibreOfficeKit.putenv("SAL_LOG=-WARN-INFO");
        LibreOfficeKit.init(this);
        ByteBuffer handle = LibreOfficeKit.getLibreOfficeKitHandle();
        if (handle == null) throw new IOException("Silnik LibreOffice nie uruchomił się.");
        office = new Office(handle);
        // Do not enable password callbacks without a complete password UI: they block LOK.
        office.setOptionalFeatures(0);
    }
    private void unpack(String asset, File target) throws IOException {
        String[] children = getAssets().list(asset);
        if (children != null && children.length > 0) {
            if (!target.exists() && !target.mkdirs()) throw new IOException("Brak miejsca na pliki silnika.");
            for (String child : children) unpack(asset + "/" + child, new File(target, child));
        } else {
            try (InputStream in = getAssets().open(asset); OutputStream out = new FileOutputStream(target)) {
                copy(in, out, MAX_FILE);
            }
        }
    }

    private byte[] render(int index, int requestedWidth) throws IOException {
        if (pdf == null || index < 0 || index >= pdf.getPageCount()) throw new IOException("Nieprawidłowy numer strony.");
        try (PdfRenderer.Page page = pdf.openPage(index)) {
            double scale = Math.min(Math.max(720, Math.min(requestedWidth, 2400)) / (double) page.getWidth(), 3500.0 / page.getHeight());
            Bitmap bitmap = Bitmap.createBitmap(Math.max(1, (int) (page.getWidth() * scale)), Math.max(1, (int) (page.getHeight() * scale)), Bitmap.Config.ARGB_8888);
            try {
                bitmap.eraseColor(Color.WHITE);
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
                return out.toByteArray();
            } finally { bitmap.recycle(); }
        }
    }
    private void closePdf() throws IOException {
        documentId++;
        if (pdf != null) { pdf.close(); pdf = null; }
        if (descriptor != null) { descriptor.close(); descriptor = null; }
        displayedPdf = null;
        currentSource = null; currentExtension = null; currentUri = null;
    }
    private static void copy(InputStream in, OutputStream out, long limit) throws IOException {
        byte[] buffer = new byte[65536]; long total = 0; int n;
        while ((n = in.read(buffer)) != -1) {
            total += n;
            if (total > limit) throw new IOException("Plik jest zbyt duży. Limit wynosi " + (limit / 1024 / 1024) + " MB.");
            out.write(buffer, 0, n);
        }
    }
    private static byte[] readLimited(InputStream in, long limit) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream(); copy(in, out, limit); return out.toByteArray();
    }
    private static String decodeText(byte[] bytes) {
        if (bytes.length >= 2 && ((bytes[0] == (byte)0xff && bytes[1] == (byte)0xfe) || (bytes[0] == (byte)0xfe && bytes[1] == (byte)0xff))) return new String(bytes, StandardCharsets.UTF_16);
        try {
            return StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString().replaceFirst("^\uFEFF", "");
        } catch (CharacterCodingException e) { return new String(bytes, Charset.forName("windows-1250")); }
    }
    private static String extensionForMime(String mime) {
        if (mime == null) return null;
        switch (mime) {
            case "application/pdf": return "pdf";
            case "text/plain": return "txt";
            case "text/csv": return "csv";
            case "application/msword": return "doc";
            case "application/vnd.ms-excel": return "xls";
            case "application/vnd.openxmlformats-officedocument.wordprocessingml.document": return "docx";
            case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": return "xlsx";
            case "application/vnd.oasis.opendocument.text": return "odt";
            case "application/vnd.oasis.opendocument.spreadsheet": return "ods";
            case "application/rtf": case "text/rtf": return "rtf";
            default: return null;
        }
    }

    // Recent entries are bounded private snapshots; they do not rely on temporary
    // URI permissions granted by mail/messenger applications.
    private File recentRoot() { return new File(getFilesDir(), "recent-documents"); }

    private JSONArray readRecentIndex() throws Exception {
        File index = new File(recentRoot(), "index.json");
        if (!index.isFile()) return new JSONArray();
        return new JSONArray(new String(Files.readAllBytes(index.toPath()), StandardCharsets.UTF_8));
    }

    private File recentEntryFile(JSONObject entry) throws Exception {
        String filename = entry.getString("file");
        if (!filename.matches("[a-f0-9]{64}\\.(pdf|txt|csv|doc|docx|odt|xls|xlsx|ods|rtf)"))
            throw new IOException("Nieprawidłowy wpis historii.");
        return new File(recentRoot(), filename);
    }

    private String recentName(Uri uri) {
        if (!"file".equals(uri.getScheme()) || uri.getPath() == null) return null;
        try {
            File source = new File(uri.getPath()).getCanonicalFile();
            JSONArray entries = readRecentIndex();
            for (int i = 0; i < entries.length(); i++) {
                JSONObject entry = entries.getJSONObject(i);
                if (recentEntryFile(entry).getCanonicalFile().equals(source)) return entry.getString("name");
            }
        } catch (Exception ignored) { }
        return null;
    }

    private Object recentFiles() throws Exception {
        List<Map<String, Object>> result = new ArrayList<>();
        JSONArray entries = readRecentIndex();
        for (int i = 0; i < entries.length(); i++) {
            JSONObject entry = entries.getJSONObject(i);
            File file = recentEntryFile(entry);
            if (!file.isFile()) continue;
            Map<String, Object> row = new HashMap<>();
            row.put("id",entry.getString("id"));
            row.put("pinned",entry.optBoolean("pinned",false));
            row.put("name", entry.getString("name"));
            row.put("extension", entry.getString("extension"));
            row.put("uri", Uri.fromFile(file).toString());
            row.put("openedAt", entry.getLong("openedAt"));
            result.add(row);
        }
        return result;
    }

    private void writeRecentIndex(JSONArray entries) throws Exception {
        File root=recentRoot();
        if(!root.exists()&&!root.mkdirs())throw new IOException("Nie można zapisać listy.");
        File temp=new File(root,"index.tmp");
        Files.write(temp.toPath(),entries.toString().getBytes(StandardCharsets.UTF_8));
        Files.move(temp.toPath(),new File(root,"index.json").toPath(),StandardCopyOption.REPLACE_EXISTING);
    }
    private void pinRecent(String id,boolean pinned) throws Exception {
        JSONArray entries=readRecentIndex(); JSONObject target=null; int count=0;
        for(int i=0;i<entries.length();i++) {
            JSONObject entry=entries.getJSONObject(i);
            if(entry.optBoolean("pinned",false))count++;
            if(entry.getString("id").equals(id))target=entry;
        }
        if(target==null)throw new IOException("Pliku nie ma już na liście.");
        if(pinned && !target.optBoolean("pinned",false) && count>=5)throw new IOException("Możesz przypiąć maksymalnie 5 dokumentów.");
        target.put("pinned",pinned); writeRecentIndex(entries);
    }
    private void clearUnpinned() throws Exception {
        JSONArray before=readRecentIndex(),after=new JSONArray();
        for(int i=0;i<before.length();i++)if(before.getJSONObject(i).optBoolean("pinned",false))after.put(before.getJSONObject(i));
        writeRecentIndex(after);
        for(int i=0;i<before.length();i++)if(!before.getJSONObject(i).optBoolean("pinned",false))recentEntryFile(before.getJSONObject(i)).delete();
    }

    private void rememberSafely(Uri uri, File input, String name, String extension, Map<String, Object> info) {
        try { remember(uri, input, name, extension); }
        catch (Exception e) { info.put("recentWarning", "Plik otwarto, ale nie udało się dodać go do ostatnich dokumentów."); }
    }

    private void remember(Uri uri, File input, String name, String extension) throws Exception {
        File root = recentRoot();
        if (!root.exists() && !root.mkdirs()) throw new IOException("Nie można zapisać historii.");
        JSONArray previous = readRecentIndex();
        List<JSONObject> ordered=new ArrayList<>();
        for(int i=0;i<previous.length();i++)ordered.add(previous.getJSONObject(i));
        ordered.sort((a,b) -> Long.compare(b.optLong("openedAt",0),a.optLong("openedAt",0)));
        previous=new JSONArray(ordered);
        String id = null;
        if ("file".equals(uri.getScheme()) && uri.getPath() != null) {
            File source = new File(uri.getPath()).getCanonicalFile();
            for (int i = 0; i < previous.length(); i++) {
                JSONObject entry = previous.getJSONObject(i);
                if (recentEntryFile(entry).getCanonicalFile().equals(source)) id = entry.getString("id");
            }
        }
        if (id == null) {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(uri.toString().getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder();
            for (byte b : digest) hex.append(String.format(Locale.ROOT, "%02x", b & 0xff));
            id = hex.toString();
        }
        boolean pinned=false;
        long pinnedBytes=0;
        for(int i=0;i<previous.length();i++) {
            JSONObject e=previous.getJSONObject(i);
            if(e.getString("id").equals(id))pinned=e.optBoolean("pinned",false);
            else if(e.optBoolean("pinned",false))pinnedBytes+=recentEntryFile(e).length();
        }
        if(input.length()+pinnedBytes>200L*1024*1024)throw new IOException("Przypięte dokumenty zajmują dostępną pamięć historii.");
        File target = new File(root, id + "." + extension);
        File temporary = new File(root, "copy.tmp");
        Files.copy(input.toPath(), temporary.toPath(), StandardCopyOption.REPLACE_EXISTING);
        Files.move(temporary.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
        JSONArray next = new JSONArray();
        JSONObject newest = new JSONObject();
        newest.put("id", id); newest.put("file", target.getName()); newest.put("name", name);
        newest.put("extension", extension); newest.put("openedAt", System.currentTimeMillis()); newest.put("pinned",pinned);
        next.put(newest);
        long total = target.length();
        Set<String> retained = new HashSet<>(); retained.add(target.getName());
        for(boolean pinsFirst:new boolean[]{true,false})for(int i=0;i<previous.length();i++) {
            JSONObject entry=previous.getJSONObject(i); File file=recentEntryFile(entry);
            if(entry.getString("id").equals(id) || !file.isFile() || entry.optBoolean("pinned",false)!=pinsFirst)continue;
            if(next.length()>=10 || total+file.length()>200L*1024*1024)continue;
            next.put(entry);total+=file.length();retained.add(file.getName());
        }
        File indexTemp = new File(root, "index.tmp");
        Files.write(indexTemp.toPath(), next.toString().getBytes(StandardCharsets.UTF_8));
        Files.move(indexTemp.toPath(), new File(root, "index.json").toPath(), StandardCopyOption.REPLACE_EXISTING);
        File[] files = root.listFiles();
        if (files != null) for (File file : files) {
            if (!file.getName().equals("index.json") && !retained.contains(file.getName())) file.delete();
        }
    }
    private static void removeTree(File f) {
        File[] children = f.listFiles();
        if (children != null) for (File child : children) removeTree(child);
        f.delete();
    }
    @Override protected void onDestroy() {
        if (officeEditor != null) officeEditor.dispose();
        WORKER.execute(() -> { try { closePdf(); } catch (IOException ignored) {} });
        super.onDestroy();
    }
}
