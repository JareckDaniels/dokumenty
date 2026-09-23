package pl.jarekgadzina.dokumenty;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import org.json.*;

/** Private sidecar annotations, independent of original document bytes. */
public final class PageHighlights {
    private PageHighlights() {}
    public static JSONArray read(File file) throws Exception {
        if(!file.isFile())return new JSONArray();
        if(file.length()>2*1024*1024)throw new IOException("Plik zaznaczeń jest zbyt duży.");
        return new JSONArray(new String(Files.readAllBytes(file.toPath()),StandardCharsets.UTF_8));
    }
    public static JSONArray change(File file,int pages,String action,JSONObject input) throws Exception {
        JSONArray before=read(file), after=new JSONArray();
        if(action.equals("add")) {
            if(before.length()>=500)throw new IOException("Limit to 500 zaznaczeń w dokumencie.");
            File[] stored=file.getParentFile().listFiles((dir,name) -> name.endsWith(".json"));
            if(!file.exists() && stored!=null && stored.length>=200)throw new IOException("Limit to 200 dokumentów z zaznaczeniami.");
            int page=input.getInt("page");
            double left=input.getDouble("left"),top=input.getDouble("top"),right=input.getDouble("right"),bottom=input.getDouble("bottom");
            if(page<0 || page>=pages || !Double.isFinite(left+top+right+bottom) || left<0 || top<0 || right>1 || bottom>1 || right<=left || bottom<=top)
                throw new IOException("Nieprawidłowy obszar zaznaczenia.");
            JSONObject mark=new JSONObject();
            mark.put("id",UUID.randomUUID().toString());mark.put("page",page);
            mark.put("left",left);mark.put("top",top);mark.put("right",right);mark.put("bottom",bottom);
            mark.put("color",color(input.optString("color","yellow")));mark.put("note",note(input.optString("note","")));
            for(int i=0;i<before.length();i++)after.put(before.getJSONObject(i));
            after.put(mark);
        } else if(action.equals("edit") || action.equals("delete")) {
            String id=input.getString("id"); boolean found=false;
            for(int i=0;i<before.length();i++) {
                JSONObject mark=before.getJSONObject(i);
                if(mark.getString("id").equals(id)) {
                    found=true;
                    if(action.equals("delete"))continue;
                    mark.put("color",color(input.getString("color")));mark.put("note",note(input.getString("note")));
                }
                after.put(mark);
            }
            if(!found)throw new IOException("Zaznaczenie nie istnieje. Otwórz ponownie listę.");
        } else throw new IOException("Nieznana operacja zaznaczenia.");
        if(after.length()==0) { Files.deleteIfExists(file.toPath()); return after; }
        File root=file.getParentFile();
        if(!root.exists()&&!root.mkdirs())throw new IOException("Nie można zapisać zaznaczeń.");
        byte[] bytes=after.toString().getBytes(StandardCharsets.UTF_8);
        if(bytes.length>2*1024*1024)throw new IOException("Zaznaczenia i notatki przekraczają limit 2 MB.");
        Path temp=Files.createTempFile(root.toPath(),"mark-",".tmp");
        try {
            Files.write(temp,bytes);
            try { Files.move(temp,file.toPath(),StandardCopyOption.ATOMIC_MOVE,StandardCopyOption.REPLACE_EXISTING); }
            catch(AtomicMoveNotSupportedException e){ Files.move(temp,file.toPath(),StandardCopyOption.REPLACE_EXISTING); }
        } finally { Files.deleteIfExists(temp); }
        return after;
    }
    public static String report(String title,JSONArray marks,boolean wholeSheets) throws Exception {
        if(marks.length()==0)throw new IOException("Brak zaznaczeń do udostępnienia.");
        List<JSONObject> sorted=new ArrayList<>();
        for(int i=0;i<marks.length();i++)sorted.add(marks.getJSONObject(i));
        sorted.sort(Comparator.comparingInt((JSONObject m) -> m.optInt("page",0)).thenComparingDouble(m -> m.optDouble("top",0)));
        StringBuilder out=new StringBuilder("Notatki z Plikownika\nDokument: ").append(title).append("\n");
        if(wholeSheets)out.append("Numery stron dotyczą widoku całych arkuszy, także ukrytych.\n");
        out.append("Zestawienie zawiera komentarze i numery stron. Nie zawiera tekstu ani obrazu zakreślonych fragmentów.\n\n");
        for(JSONObject mark:sorted) {
            String c=mark.optString("color","yellow");
            String label=c.equals("green")?"Zielony":c.equals("pink")?"Różowy":"Żółty";
            out.append("Strona ").append(mark.getInt("page")+1).append(" | ").append(label).append("\n");
            String comment=mark.optString("note","");
            out.append(comment.trim().isEmpty()?"Zaznaczony fragment bez notatki.":comment).append("\n\n");
        }
        return out.toString();
    }
    private static String color(String value) throws IOException {
        if(!Arrays.asList("yellow","green","pink").contains(value))throw new IOException("Nieprawidłowy kolor.");
        return value;
    }
    private static String note(String value) throws IOException {
        if(value.length()>1000)throw new IOException("Notatka może mieć do 1000 znaków.");
        return value;
    }
}
