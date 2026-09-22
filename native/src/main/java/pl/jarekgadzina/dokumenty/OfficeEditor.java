package pl.jarekgadzina.dokumenty;

import android.app.Dialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.*;
import android.net.Uri;
import android.text.InputType;
import android.view.*;
import android.view.inputmethod.*;
import android.widget.*;
import io.flutter.plugin.common.MethodChannel;
import org.libreoffice.kit.Document;
import org.json.JSONObject;
import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;

/** A live Writer canvas. Every LOK call runs on MainActivity.WORKER. */
final class OfficeEditor {
    private final MainActivity activity;
    private final File source;
    private final String extension, filename;
    private final MethodChannel.Result result;
    private final Runnable onClosed;
    private Dialog dialog;
    private PageView page;
    private TextView status;
    private LinearLayout controls, searchPanel, toolbarArea, tabRow;
    private Button saveButton, sizeButton;
    private EditorUi.Sheet popup;
    private String savedUri;
    private final java.util.Map<String, Boolean> formatStates = new java.util.HashMap<>();
    private EditText searchText, replaceText;
    private CheckBox matchCase;
    private boolean searchPending, searchMiss;
    private int searchMode;
    private Document document; // worker thread only
    private volatile boolean closed;
    private boolean dirty, busy = true, saving, rendering, rerender;
    private double docWidth = 12000, docHeight = 16800;
    private RectF cursor;
    private final List<RectF> selection = new ArrayList<>();
    private final java.util.Map<String, Button> toggles = new java.util.HashMap<>();

    OfficeEditor(MainActivity activity, File source, String extension, String filename, String initialSaveUri,
                 MethodChannel.Result result, Runnable onClosed) {
        this.activity = activity; this.source = source; this.extension = extension;
        this.filename = filename; this.savedUri = initialSaveUri; this.result = result; this.onClosed = onClosed;
    }

    void show() {
        dialog = new Dialog(activity, android.R.style.Theme_Material_Light_NoActionBar) {
            @Override public void cancel() { leave(); }
        };
        LinearLayout root = new LinearLayout(activity); root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(EditorUi.BG);
        // Respect status/navigation bars, including Android 15 edge-to-edge enforcement.
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            v.setPadding(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(),
                insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            return insets;
        });
        LinearLayout header = new LinearLayout(activity); header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dp(8),dp(4),dp(12),dp(4));
        Button back = EditorUi.button(activity,"‹",this::leave,false);
        back.setTextSize(26); back.setContentDescription("Wróć do podglądu"); header.addView(back,new LinearLayout.LayoutParams(dp(48),dp(48)));
        LinearLayout heading = new LinearLayout(activity); heading.setOrientation(LinearLayout.VERTICAL);
        heading.setPadding(dp(8),0,dp(8),0);
        TextView title = EditorUi.label(activity,filename,16,EditorUi.INK);
        title.setSingleLine(true); title.setEllipsize(android.text.TextUtils.TruncateAt.END);
        title.setTypeface(Typeface.create("sans-serif-medium",0));
        heading.addView(title); heading.addView(EditorUi.label(activity,"PLIKOWNIK · EDYCJA",10,EditorUi.MUTED));
        header.addView(heading,new LinearLayout.LayoutParams(0,-2,1));
        saveButton = EditorUi.button(activity,"Zapisz",() -> save(false,false,false),true);
        header.addView(saveButton,new LinearLayout.LayoutParams(-2,dp(48))); root.addView(header);
        toolbarArea = new LinearLayout(activity); toolbarArea.setOrientation(LinearLayout.VERTICAL);
        HorizontalScrollView tabs = new HorizontalScrollView(activity); tabs.setHorizontalScrollBarEnabled(false);
        tabRow = new LinearLayout(activity); tabRow.setPadding(dp(8),0,dp(8),0); tabs.addView(tabRow); toolbarArea.addView(tabs);
        for (String name : new String[]{"Tekst", "Akapit", "Narzędzia", "Plik"}) {
            Button tab = EditorUi.button(activity,name,() -> showTab(name),false); tab.setTag(name);
            tabRow.addView(tab,new LinearLayout.LayoutParams(-2,dp(44)));
        }
        HorizontalScrollView toolbar = new HorizontalScrollView(activity); toolbar.setHorizontalScrollBarEnabled(false);
        controls = new LinearLayout(activity); controls.setPadding(dp(8),dp(4),dp(8),dp(4)); toolbar.addView(controls);
        toolbarArea.addView(toolbar); root.addView(toolbarArea); showTab("Tekst");
        buildSearchPanel(root);
        status = EditorUi.label(activity,"",12,EditorUi.MUTED); status.setPadding(dp(16),dp(4),dp(16),dp(6)); status.setMaxLines(2); status.setEllipsize(android.text.TextUtils.TruncateAt.END);
        status.setText("Otwieranie edytora…"); root.addView(status);
        page = new PageView(); root.addView(page, new LinearLayout.LayoutParams(-1, 0, 1));
        dialog.setContentView(root);
        dialog.setOnKeyListener((d, code, event) -> {
            if (code == KeyEvent.KEYCODE_BACK && event.getAction() == KeyEvent.ACTION_UP) { leave(); return true; }
            return code == KeyEvent.KEYCODE_BACK;
        });
        dialog.setCancelable(true); dialog.setCanceledOnTouchOutside(false); dialog.show();
        dialog.getWindow().setLayout(-1, -1);
        dialog.getWindow().setStatusBarColor(EditorUi.BG);
        dialog.getWindow().setNavigationBarColor(EditorUi.BG);
        dialog.getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        dialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        setBusy(true);
        MainActivity.WORKER.execute(() -> {
            try {
                if (closed) return;
                document = MainActivity.office.documentLoad(Uri.fromFile(source).toString());
                if (document == null) throw new IOException("Silnik nie otworzył dokumentu do edycji.");
                document.setMessageCallback((signal, payload) -> activity.runOnUiThread(() -> callback(signal, payload)));
                document.initializeForRendering();
                if (document.getDocumentType() != Document.DOCTYPE_TEXT)
                    throw new IOException("Ten edytor obsługuje obecnie dokumenty tekstowe.");
                final double w = document.getDocumentWidth(), h = document.getDocumentHeight();
                activity.runOnUiThread(() -> {
                    if (closed) return;
                    docWidth = Math.max(1, w); docHeight = Math.max(1, h); setBusy(false);
                    status.setText("Dotknij tekstu, aby pisać. Przytrzymaj, aby zaznaczyć słowo.");
                    page.clamp(); requestRender();
                });
            } catch (Exception | LinkageError e) { activity.runOnUiThread(() -> {
                if (!closed) { status.setText("Nie można uruchomić edycji: " + e.getMessage()); setBusy(true); }
            }); }
        });
    }

    private int dp(int value) { return EditorUi.dp(activity,value); }
    private void showTab(String tab) {
        controls.removeAllViews(); toggles.clear();
        for (int i=0;i<tabRow.getChildCount();i++) {
            Button b=(Button)tabRow.getChildAt(i); EditorUi.style(b,false,tab.equals(b.getTag()));
        }
        switch (tab) {
            case "Tekst":
                toggle("B", "Bold"); toggle("I", "Italic"); toggle("U", "Underline");
                addButton(controls,"Rozmiar ▾",this::chooseSize);
                sizeButton = (Button) controls.getChildAt(controls.getChildCount()-1);
                sizeButton.setContentDescription("Zmień rozmiar czcionki");
                break;
            case "Akapit":
                toggle("• Lista", "DefaultBullet"); toggle("1. Lista", "DefaultNumbering");
                addButton(controls,"Do lewej",() -> command("LeftPara",null));
                addButton(controls,"Środek",() -> command("CenterPara",null));
                addButton(controls,"Do prawej",() -> command("RightPara",null));
                break;
            case "Narzędzia":
                addButton(controls,"↶ Cofnij",() -> command("Undo",null));
                addButton(controls,"↷ Ponów",() -> command("Redo",null));
                addButton(controls,"Szukaj / zamień",this::toggleSearch);
                addButton(controls,"Kopiuj",() -> clipboard(false));
                addButton(controls,"Wytnij",() -> clipboard(true));
                addButton(controls,"Wklej",this::pasteClipboard);
                addButton(controls,"Zaznacz wszystko",() -> command("SelectAll",null));
                break;
            case "Plik":
                addButton(controls,"Zapisz jako…",() -> save(false,true,false));
                addButton(controls,"Eksport PDF",() -> save(true,true,false));
                break;
        }
        enableSearch(controls,!busy);
    }
    private void addButton(LinearLayout row, String label, Runnable action) {
        Button button = EditorUi.button(activity,label,action,false);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-2,dp(48)); lp.rightMargin=dp(4);
        row.addView(button,lp);
    }
    private void toggle(String label, String command) {
        addButton(controls, label, () -> command(command, null));
        Button button = (Button) controls.getChildAt(controls.getChildCount() - 1);
        toggles.put(".uno:" + command, button);
        EditorUi.style(button,false,Boolean.TRUE.equals(formatStates.get(".uno:"+command)));
        if (command.equals("Bold")) button.setTypeface(Typeface.DEFAULT,Typeface.BOLD);
        if (command.equals("Italic")) button.setTypeface(Typeface.DEFAULT,Typeface.ITALIC);
        if (command.equals("Underline")) button.setPaintFlags(button.getPaintFlags()|Paint.UNDERLINE_TEXT_FLAG);
    }
    private void setBusy(boolean value) {
        busy = value;
        enableSearch(controls,!value); enableSearch(tabRow,!value); saveButton.setEnabled(!value);
        enableSearch(searchPanel, !value);
    }
    private void enableSearch(View view, boolean enabled) {
        if (view == null) return;
        view.setEnabled(enabled);
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int i = 0; i < group.getChildCount(); i++) enableSearch(group.getChildAt(i), enabled);
        }
    }
    private void buildSearchPanel(LinearLayout root) {
        searchPanel = new LinearLayout(activity); searchPanel.setOrientation(LinearLayout.VERTICAL);
        searchPanel.setPadding(dp(12), 0, dp(12), 0); searchPanel.setVisibility(View.GONE);
        LinearLayout fields = new LinearLayout(activity);
        searchText = new EditText(activity); searchText.setSingleLine(true); searchText.setHint("Znajdź tekst");
        searchText.setContentDescription("Szukany tekst");
        replaceText = new EditText(activity); replaceText.setSingleLine(true); replaceText.setHint("Zamień na…");
        replaceText.setContentDescription("Tekst zastępujący; puste pole usuwa znaleziony tekst");
        searchText.setFilters(new android.text.InputFilter[]{new android.text.InputFilter.LengthFilter(1000)});
        replaceText.setFilters(new android.text.InputFilter[]{new android.text.InputFilter.LengthFilter(1000)});
        EditorUi.field(searchText); EditorUi.field(replaceText);
        fields.addView(searchText, new LinearLayout.LayoutParams(0, -2, 1));
        fields.addView(replaceText, new LinearLayout.LayoutParams(0, -2, 1));
        searchPanel.addView(fields);
        matchCase = new CheckBox(activity); matchCase.setText("Rozróżniaj wielkość liter"); matchCase.setTextSize(13); matchCase.setTextColor(EditorUi.INK); matchCase.setButtonTintList(android.content.res.ColorStateList.valueOf(EditorUi.GREEN)); searchPanel.addView(matchCase);
        HorizontalScrollView scroll = new HorizontalScrollView(activity);
        LinearLayout actions = new LinearLayout(activity); scroll.addView(actions);
        addButton(actions, "Poprzedni", () -> search(OfficeSearch.FIND, true));
        addButton(actions, "Następny", () -> search(OfficeSearch.FIND, false));
        addButton(actions, "Zamień", () -> search(OfficeSearch.REPLACE, false));
        addButton(actions, "Zamień wszystkie", () -> {
            if (searchText.length() == 0) { searchText.setError("Wpisz szukany tekst"); return; }
            EditorUi.Sheet sheet = sheet("Zamienić wszystkie wystąpienia?", "Zmiana obejmie cały dokument. Możesz ją cofnąć w zakładce Narzędzia.");
            sheet.action("Zamień wszystkie",true,() -> search(OfficeSearch.REPLACE_ALL,false));
            sheet.action("Anuluj",false,() -> {}); sheet.show();
        });
        addButton(actions, "Zamknij", this::toggleSearch);
        searchPanel.addView(scroll); root.addView(searchPanel);
        searchText.setImeOptions(EditorInfo.IME_ACTION_SEARCH);
        searchText.setOnEditorActionListener((v, action, event) -> {
            if (action == EditorInfo.IME_ACTION_SEARCH) { search(OfficeSearch.FIND, false); return true; }
            return false;
        });
    }
    private void toggleSearch() {
        if (closed || busy) return;
        boolean show = searchPanel.getVisibility() != View.VISIBLE;
        page.resetInput(); searchPanel.setVisibility(show ? View.VISIBLE : View.GONE);
        toolbarArea.setVisibility(show ? View.GONE : View.VISIBLE);
        if (show) {
            searchText.requestFocus();
            status.setText("Znajdź fragment, a następnie użyj Zamień. Puste pole zamiany usuwa tekst.");
        } else {
            ((InputMethodManager) activity.getSystemService(Context.INPUT_METHOD_SERVICE))
                .hideSoftInputFromWindow(searchText.getWindowToken(), 0);
            page.requestFocus(); status.setText("Dotknij dokumentu, aby kontynuować edycję.");
        }
        requestRender();
    }
    private void search(int mode, boolean backward) {
        if (closed || busy || searchPending) return;
        final String args;
        try { args = OfficeSearch.arguments(searchText.getText().toString(), replaceText.getText().toString(), backward, matchCase.isChecked(), mode); }
        catch (Exception e) { searchText.setError(e.getMessage()); return; }
        searchText.setError(null); page.resetInput(); page.followCursor = true;
        ((InputMethodManager) activity.getSystemService(Context.INPUT_METHOD_SERVICE))
            .hideSoftInputFromWindow(searchText.getWindowToken(), 0);
        searchPending = true; searchMiss = false; searchMode = mode;
        enableSearch(searchPanel, false);
        status.setText(mode == OfficeSearch.FIND ? "Wyszukiwanie…" : "Zamiana tekstu…");
        edit(doc -> {
            try { AppDiagnostics.mark(activity,"Wyszukiwanie: tryb "+mode); doc.postUnoCommand(".uno:ExecuteSearch", args, true); }
            catch (Exception e) {
                activity.runOnUiThread(() -> {
                    searchPending = false;
                    if (!closed) { enableSearch(searchPanel, !busy); status.setText("Nie udało się wyszukać lub zamienić tekstu."); }
                });
                throw e;
            }
        }, mode != OfficeSearch.FIND);
    }
    private EditorUi.Sheet sheet(String title, String description) {
        if (popup != null) popup.dialog.dismiss();
        popup = new EditorUi.Sheet(activity,title,description); return popup;
    }
    private void chooseSize() {
        if (busy || closed) return;
        page.resetInput();
        MainActivity.WORKER.execute(() -> AppDiagnostics.mark(activity,"Wybór rozmiaru czcionki"));
        EditorUi.Sheet sheet = sheet("Rozmiar czcionki", "Zaznaczony tekst lub tekst wpisywany od kursora.");
        final int[] sizes = {8,10,11,12,14,16,18,20,24,28,32,36,48,72};
        LinearLayout row = null;
        for (int i=0;i<sizes.length;i++) {
            if (i%4 == 0) { row=new LinearLayout(activity); sheet.body.addView(row); }
            final int points = sizes[i];
            Button b = EditorUi.button(activity,points+"",() -> {
                sheet.dialog.dismiss();
                // Let the popup window detach before restarting IME and sending a native edit.
                page.post(() -> {
                    if (closed || busy) return;
                    command("FontHeight",OfficeFormatting.fontSize(points));
                    if (sizeButton != null) sizeButton.setText(points+" pkt ▾");
                });
            },false);
            LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(0,dp(48),1); lp.setMargins(dp(2),dp(2),dp(2),dp(2)); row.addView(b,lp);
        }
        sheet.action("Anuluj",false,() -> {}); sheet.show();
    }
    private interface Edit { void run(Document doc) throws Exception; }
    private void edit(Edit action, boolean changes) {
        if (closed || busy) return;
        if (changes) dirty = true;
        MainActivity.WORKER.execute(() -> {
            if (closed || document == null) return;
            try { action.run(document); }
            catch (Exception e) { activity.runOnUiThread(() -> error(e.getMessage())); }
            activity.runOnUiThread(this::requestRender);
        });
    }
    private void command(String command, String args) {
        page.resetInput();
        edit(doc -> {
            AppDiagnostics.mark(activity,"Polecenie .uno:"+command);
            doc.postUnoCommand(".uno:" + command,args,false);
        }, !command.equals("SelectAll"));
    }
    private void key(Document doc, int character, int code) {
        doc.postKeyEvent(Document.KEY_EVENT_PRESS, character, code);
        doc.postKeyEvent(Document.KEY_EVENT_RELEASE, character, code);
    }
    private void type(String text, int erase) {
        if (text.length() > 20000 || erase > 20000) { error("Jednorazowo wpisz maksymalnie 20 000 znaków."); return; }
        edit(doc -> {
            for (int i = 0; i < erase; i++) key(doc, 8, 1283); // com.sun.star.awt.Key.BACKSPACE
            for (int i = 0; i < text.length(); i++) {
                char c = text.charAt(i);
                if (c == '\r') continue;
                key(doc, c, c == '\n' ? 1280 : c == '\t' ? 1282 : 0);
            }
        }, true);
    }
    private void clipboard(boolean cut) {
        page.resetInput();
        edit(doc -> {
            String text = doc.getTextSelection("text/plain;charset=utf-8");
            if (text == null || text.isEmpty()) return;
            activity.runOnUiThread(() -> {
                if (!closed) ((ClipboardManager) activity.getSystemService(Context.CLIPBOARD_SERVICE))
                    .setPrimaryClip(ClipData.newPlainText("Tekst", text));
            });
            if (cut) key(doc, 8, 1283);
        }, cut);
    }
    private void pasteClipboard() {
        ClipboardManager clipboard = (ClipboardManager) activity.getSystemService(Context.CLIPBOARD_SERVICE);
        ClipData clip = clipboard.getPrimaryClip();
        if (clip == null || clip.getItemCount() == 0) return;
        CharSequence text = clip.getItemAt(0).coerceToText(activity);
        if (text == null) return;
        if (text.length() > 20000) { error("Jednorazowo wklej maksymalnie 20 000 znaków."); return; }
        page.resetInput(); type(text.toString(), 0);
    }
    private void error(String message) {
        if (closed) return;
        EditorUi.Sheet sheet=sheet("Nie udało się wykonać operacji",message == null ? "Spróbuj ponownie." : message);
        sheet.action("Rozumiem",true,() -> {}); sheet.show();
    }
    private void leave() {
        if (saving) return;
        if (!dirty) { finish(savedUri); return; }
        EditorUi.Sheet sheet=sheet("Zapisać zmiany?", "W dokumencie są niezapisane zmiany. Wybierz, co zrobić przed powrotem do podglądu.");
        sheet.action("Zapisz i wyjdź",true,() -> save(false,false,true));
        sheet.action("Odrzuć zmiany",false,() -> finish(savedUri));
        sheet.action("Edytuj dalej",false,() -> {}); sheet.show();
    }
    private void finish(String uri) {
        if (closed) return;
        dispose(); result.success(uri);
    }
    void dispose() {
        if (closed) return;
        closed = true;
        if (page != null) { page.finishComposition(); page.removeCallbacks(renderTask); }
        if (popup != null) popup.dialog.dismiss();
        if (dialog != null) dialog.dismiss();
        MainActivity.WORKER.execute(() -> {
            if (document != null) { document.setMessageCallback(null); document.destroy(); document = null; }
        });
        onClosed.run();
    }
    private void save(boolean pdf, boolean chooseNew, boolean leaveAfter) {
        if (busy || closed) return;
        page.resetInput(); saving = true; setBusy(true); status.setText("Przygotowywanie pliku…");
        String ext = pdf ? "pdf" : extension;
        MainActivity.WORKER.execute(() -> {
            File output = null;
            try {
                if (closed || document == null) return;
                output = File.createTempFile("office-save-", "." + ext, activity.getCacheDir());
                if (document.saveAs(Uri.fromFile(output).toString(), ext, "") == 0 || output.length() == 0)
                    throw new IOException("Silnik nie zapisał dokumentu. " + MainActivity.office.getError());
                File ready = output;
                activity.runOnUiThread(() -> {
                    if (closed) { ready.delete(); return; }
                    String name = filename.replaceFirst("\\.[^.]+$", "") + (pdf ? "" : "-edycja") + "." + ext;
                    MethodChannel.Result completion = new MethodChannel.Result() {
                        public void success(Object value) {
                            if (closed) return;
                            saving = false; setBusy(false);
                            status.setText(value == null ? "Anulowano zapis. Zmiany są nadal w edytorze." : "Zapisano plik.");
                            if (value instanceof String && !pdf) {
                                savedUri = (String) value; dirty = false;
                                if (leaveAfter) finish(savedUri);
                                else { status.setText("Zapisano. Możesz kontynuować edycję."); requestRender(); }
                            }
                        }
                        public void error(String code, String message, Object details) {
                            ready.delete(); if (!closed) { saving = false; setBusy(false); OfficeEditor.this.error(message); }
                        }
                        public void notImplemented() { error("SAVE", "Zapis jest niedostępny.", null); }
                    };
                    if (!pdf && !chooseNew && savedUri != null) activity.overwriteEdited(ready,savedUri,completion);
                    else activity.beginEditSave(ready, name, ext, completion);
                });
            } catch (Exception e) {
                if (output != null) output.delete();
                activity.runOnUiThread(() -> { if (!closed) { saving = false; setBusy(false); error(e.getMessage()); } });
            }
        });
    }

    private static RectF rectangle(String data) {
        try {
            String[] v = data.trim().split(",\\s*");
            float x = Float.parseFloat(v[0]), y = Float.parseFloat(v[1]);
            return new RectF(x, y, x + Float.parseFloat(v[2]), y + Float.parseFloat(v[3]));
        } catch (Exception ignored) { return null; }
    }
    private void callback(int signal, String payload) {
        if (closed) return;
        if (signal == Document.CALLBACK_INVALIDATE_VISIBLE_CURSOR) {
            String rect = payload;
            if (payload != null && payload.startsWith("{")) {
                try { rect = new JSONObject(payload).optString("rectangle"); } catch (Exception ignored) { rect = ""; }
            }
            cursor = rect == null ? null : rectangle(rect);
            if (page.followCursor && cursor != null) page.reveal(cursor);
            page.invalidate();
        } else if (signal == Document.CALLBACK_TEXT_SELECTION) {
            selection.clear();
            if (payload != null) for (String item : payload.split(";")) {
                RectF r = rectangle(item); if (r != null) selection.add(r);
            }
            if (searchPending && !selection.isEmpty()) page.reveal(selection.get(0));
            page.invalidate();
        } else if (signal == Document.CALLBACK_SEARCH_RESULT_SELECTION) {
            try {
                org.json.JSONArray hits = new JSONObject(payload).optJSONArray("searchResultSelection");
                if (hits != null && hits.length() > 0) {
                    String rectangles = hits.getJSONObject(0).optString("rectangles");
                    RectF first = rectangle(rectangles.split(";")[0]);
                    if (first != null) { page.reveal(first); page.invalidate(); }
                }
            } catch (Exception ignored) { /* The regular selection callback still paints the highlight. */ }
        } else if (signal == Document.CALLBACK_SEARCH_NOT_FOUND) {
            searchMiss = true; status.setText("Nie znaleziono takiego tekstu.");
        } else if (signal == Document.CALLBACK_UNO_COMMAND_RESULT && searchPending) {
            try {
                JSONObject event = new JSONObject(payload);
                if (".uno:ExecuteSearch".equals(event.optString("commandName"))) {
                    searchPending = false; enableSearch(searchPanel, !busy);
                    if (!searchMiss) status.setText(!event.optBoolean("success", true)
                        ? "Operacja nie powiodła się. Spróbuj ponownie."
                        : searchMode == OfficeSearch.FIND ? "Wynik zaznaczony w dokumencie."
                        : "Zakończono zamianę. Możesz użyć Cofnij.");
                    requestRender();
                }
            } catch (Exception ignored) { /* Other engine notifications are not search results. */ }
        } else if (signal == Document.CALLBACK_INVALIDATE_TILES || signal == Document.CALLBACK_DOCUMENT_SIZE_CHANGED) {
            requestRender();
        } else if (signal == Document.CALLBACK_STATE_CHANGED && payload != null) {
            int split = payload.indexOf('=');
            if (split > 0) {
                formatStates.put(payload.substring(0,split),payload.substring(split+1).equals("true"));
                Button button = toggles.get(payload.substring(0, split));
                if (button != null) EditorUi.style(button,false,payload.substring(split + 1).equals("true"));
            }
        }
    }
    private final Runnable renderTask = this::render;
    private void requestRender() {
        if (closed || page == null) return;
        page.removeCallbacks(renderTask); page.postDelayed(renderTask, 32);
    }
    private void render() {
        if (closed || busy || page.getWidth() == 0 || page.getHeight() == 0) return;
        if (rendering) { rerender = true; return; }
        rendering = true;
        final double left = page.left, top = page.top, scale = page.scale();
        final int width = Math.min(1440, page.getWidth());
        final int height = Math.max(1, (int) ((double) page.getHeight() * width / page.getWidth()));
        final int tw = Math.max(1, (int) Math.ceil(page.getWidth() / scale));
        final int th = Math.max(1, (int) Math.ceil(page.getHeight() / scale));
        MainActivity.WORKER.execute(() -> {
            Bitmap bitmap = null;
            try {
                if (closed || document == null) return;
                ByteBuffer buffer = ByteBuffer.allocateDirect(width * height * 4);
                document.setClientZoom(width, height, tw, th);
                document.paintTile(buffer, width, height, (int) left, (int) top, tw, th);
                bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
                buffer.rewind(); bitmap.copyPixelsFromBuffer(buffer);
                final Bitmap ready = bitmap;
                final double w = document.getDocumentWidth(), h = document.getDocumentHeight();
                activity.runOnUiThread(() -> {
                    if (closed) { ready.recycle(); return; }
                    docWidth = Math.max(1, w); docHeight = Math.max(1, h);
                    page.image = ready; page.imageBounds = new RectF((int) left, (int) top, (int) left + tw, (int) top + th);
                    page.clamp(); page.invalidate();
                });
            } catch (Exception | OutOfMemoryError e) {
                if (bitmap != null) bitmap.recycle();
                activity.runOnUiThread(() -> { if (!closed) status.setText("Nie udało się odświeżyć widoku. Przesuń dokument, aby ponowić."); });
            } finally {
                activity.runOnUiThread(() -> {
                    rendering = false;
                    if (rerender && !closed) { rerender = false; requestRender(); }
                });
            }
        });
    }

    private final class PageView extends View {
        double left, top, zoom = 1;
        Bitmap image;
        RectF imageBounds;
        final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
        final GestureDetector gestures;
        final ScaleGestureDetector scaling;
        int dragging = -1;
        boolean followCursor, pinching;
        String composing = "";
        PageView() {
            super(activity); setFocusable(true); setFocusableInTouchMode(true);
            setContentDescription("Edytowalny dokument. Dotknij tekstu; przytrzymaj słowo, aby zaznaczyć.");
            scaling = new ScaleGestureDetector(activity, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
                @Override public boolean onScale(ScaleGestureDetector detector) {
                    followCursor = false;
                    double old = scale(), x = left + detector.getFocusX() / old, y = top + detector.getFocusY() / old;
                    zoom = Math.max(1, Math.min(5, zoom * detector.getScaleFactor()));
                    left = x - detector.getFocusX() / scale(); top = y - detector.getFocusY() / scale();
                    clamp(); invalidate(); return true;
                }
                @Override public void onScaleEnd(ScaleGestureDetector detector) { requestRender(); }
            });
            gestures = new GestureDetector(activity, new GestureDetector.SimpleOnGestureListener() {
                @Override public boolean onDown(android.view.MotionEvent e) { return true; }
                @Override public boolean onSingleTapUp(android.view.MotionEvent e) { click(e, 1); return true; }
                @Override public void onLongPress(android.view.MotionEvent e) { click(e, 2); dragging = Document.SET_TEXT_SELECTION_END; }
                @Override public boolean onScroll(android.view.MotionEvent a, android.view.MotionEvent b, float dx, float dy) {
                    if (scaling.isInProgress() || dragging >= 0) return true;
                    followCursor = false; left += dx / scale(); top += dy / scale(); clamp(); invalidate(); requestRender(); return true;
                }
            });
        }
        double scale() { return Math.max(0.001, getWidth() / docWidth * zoom); }
        void clamp() {
            left = Math.max(0, Math.min(left, docWidth - getWidth() / scale()));
            top = Math.max(0, Math.min(top, docHeight - getHeight() / scale()));
        }
        void reveal(RectF r) {
            double before = top, beforeLeft = left;
            if (r.bottom > top + getHeight() / scale() - 80) top = r.bottom - getHeight() / scale() + 160;
            if (r.top < top) top = Math.max(0, r.top - 160);
            if (r.left < left) left = r.left;
            if (r.right > left + getWidth() / scale()) left = r.right - getWidth() / scale() + 100;
            clamp(); if (before != top || beforeLeft != left) requestRender();
        }
        RectF screen(RectF r) { return new RectF((float)((r.left-left)*scale()), (float)((r.top-top)*scale()), (float)((r.right-left)*scale()), (float)((r.bottom-top)*scale())); }
        @Override protected void onDraw(Canvas canvas) {
            canvas.drawColor(Color.rgb(240, 240, 240));
            if (image != null && imageBounds != null) canvas.drawBitmap(image, null, screen(imageBounds), paint);
            paint.setColor(0x55448AFF);
            for (RectF r : selection) canvas.drawRect(screen(r), paint);
            if (cursor != null && selection.isEmpty()) {
                paint.setColor(Color.rgb(0, 80, 180)); RectF r = screen(cursor); r.right = Math.max(r.right, r.left + 2); canvas.drawRect(r, paint);
            }
            if (!selection.isEmpty()) {
                paint.setColor(Color.rgb(0, 80, 180));
                RectF first = screen(selection.get(0)), last = screen(selection.get(selection.size()-1));
                canvas.drawCircle(first.left, first.bottom, 9 * getResources().getDisplayMetrics().density, paint);
                canvas.drawCircle(last.right, last.bottom, 9 * getResources().getDisplayMetrics().density, paint);
            }
        }
        void finishComposition() { composing = ""; }
        void resetInput() {
            finishComposition();
            ((InputMethodManager) activity.getSystemService(Context.INPUT_METHOD_SERVICE)).restartInput(this);
        }
        void click(android.view.MotionEvent e, int count) {
            if (busy) return;
            finishComposition(); followCursor = true; requestFocus();
            int x = (int)(left + e.getX()/scale()), y = (int)(top + e.getY()/scale());
            edit(doc -> {
                doc.postMouseEvent(Document.MOUSE_EVENT_BUTTON_DOWN, x, y, count, Document.MOUSE_BUTTON_LEFT, 0);
                doc.postMouseEvent(Document.MOUSE_EVENT_BUTTON_UP, x, y, count, Document.MOUSE_BUTTON_LEFT, 0);
            }, false);
            ((InputMethodManager)activity.getSystemService(Context.INPUT_METHOD_SERVICE)).restartInput(this);
            ((InputMethodManager)activity.getSystemService(Context.INPUT_METHOD_SERVICE)).showSoftInput(this, InputMethodManager.SHOW_IMPLICIT);
        }
        @Override public boolean onTouchEvent(android.view.MotionEvent e) {
            if (busy) return true;
            if (e.getActionMasked() == android.view.MotionEvent.ACTION_DOWN && !selection.isEmpty()) {
                RectF first = screen(selection.get(0)), last = screen(selection.get(selection.size()-1));
                double radius = 26 * getResources().getDisplayMetrics().density;
                if (Math.hypot(e.getX()-first.left, e.getY()-first.bottom) < radius) dragging = 0;
                else if (Math.hypot(e.getX()-last.right, e.getY()-last.bottom) < radius) dragging = 1;
            }
            if (e.getActionMasked() == android.view.MotionEvent.ACTION_DOWN) pinching = false;
            if (e.getPointerCount() > 1 && !pinching) {
                pinching = true;
                android.view.MotionEvent cancel = android.view.MotionEvent.obtain(e);
                cancel.setAction(android.view.MotionEvent.ACTION_CANCEL); gestures.onTouchEvent(cancel); cancel.recycle();
            }
            scaling.onTouchEvent(e);
            if (pinching) { dragging = -1; requestRender(); return true; }
            if (dragging >= 0 && e.getActionMasked() == android.view.MotionEvent.ACTION_MOVE) {
                int type = dragging, x = (int)(left + e.getX()/scale()), y = (int)(top + e.getY()/scale());
                edit(doc -> doc.setTextSelection(type, x, y), false); return true;
            }
            if (dragging < 0 && !scaling.isInProgress()) gestures.onTouchEvent(e);
            if (e.getActionMasked() == android.view.MotionEvent.ACTION_UP || e.getActionMasked() == android.view.MotionEvent.ACTION_CANCEL) { dragging = -1; requestRender(); }
            return true;
        }
        @Override protected void onSizeChanged(int w, int h, int oldw, int oldh) {
            clamp(); if (followCursor && cursor != null) reveal(cursor); requestRender();
        }
        @Override public boolean onCheckIsTextEditor() { return true; }
        @Override public InputConnection onCreateInputConnection(EditorInfo info) {
            info.inputType = InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS;
            info.imeOptions = EditorInfo.IME_FLAG_NO_EXTRACT_UI | EditorInfo.IME_FLAG_NO_FULLSCREEN;
            info.initialSelStart = info.initialSelEnd = 0;
            return new BaseInputConnection(this, false) {
                @Override public boolean commitText(CharSequence text, int position) {
                    followCursor = true; type(text.toString(), composing.length()); composing = ""; return true;
                }
                @Override public boolean setComposingText(CharSequence text, int position) {
                    followCursor = true; type(text.toString(), composing.length()); composing = text.toString(); return true;
                }
                @Override public boolean finishComposingText() { finishComposition(); return true; }
                @Override public CharSequence getTextBeforeCursor(int n, int flags) { return composing.substring(Math.max(0, composing.length()-n)); }
                @Override public CharSequence getTextAfterCursor(int n, int flags) { return ""; }
                @Override public CharSequence getSelectedText(int flags) { return ""; }
                @Override public boolean deleteSurroundingText(int before, int after) {
                    followCursor = true; finishComposition();
                    edit(doc -> {
                        for (int i=0; i<Math.min(before, 20000); i++) key(doc, 8, 1283);
                        for (int i=0; i<Math.min(after, 20000); i++) key(doc, 0, 1286);
                    }, true); return true;
                }
                @Override public boolean deleteSurroundingTextInCodePoints(int before, int after) { return deleteSurroundingText(before, after); }
                @Override public boolean sendKeyEvent(KeyEvent event) {
                    if (event.getAction() != KeyEvent.ACTION_DOWN) return true;
                    if (event.getKeyCode() == KeyEvent.KEYCODE_DEL) return deleteSurroundingText(1, 0);
                    if (event.getKeyCode() == KeyEvent.KEYCODE_ENTER) return commitText("\n", 1);
                    int c = event.getUnicodeChar();
                    if (c != 0) return commitText(new String(Character.toChars(c)), 1);
                    return false;
                }
                @Override public boolean performContextMenuAction(int id) {
                    if (id == android.R.id.copy) clipboard(false);
                    else if (id == android.R.id.cut) clipboard(true);
                    else if (id == android.R.id.paste) pasteClipboard();
                    else if (id == android.R.id.selectAll) command("SelectAll", null);
                    else return false;
                    return true;
                }
            };
        }
    }
}
