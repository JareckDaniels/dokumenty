package pl.jarekgadzina.dokumenty;

import android.content.Context;
import android.content.SharedPreferences;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import org.json.*;

/** Reader metadata only. A recovery journal makes an interrupted restore reversible. */
final class ReaderBackup {
    static final int MAX_BYTES=25*1024*1024;
    static JSONObject snapshot(Context context) throws Exception {
        JSONObject result=new JSONObject().put("format","plikownik-reader").put("version",1);
        SharedPreferences prefs=context.getSharedPreferences("reader",Context.MODE_PRIVATE);
        result.put("prefs",new JSONObject(prefs.getString("prefs","{}")));
        result.put("positions",new JSONObject(prefs.getString("positions","{}")));
        JSONObject bookmarks=new JSONObject();
        for(Map.Entry<String,?> entry:context.getSharedPreferences("page-bookmarks",Context.MODE_PRIVATE).getAll().entrySet())
            if(entry.getValue() instanceof String)bookmarks.put(entry.getKey(),entry.getValue());
        result.put("bookmarks",bookmarks);
        JSONObject highlights=new JSONObject();
        File[] files=new File(context.getFilesDir(),"page-highlights").listFiles((dir,name)->name.endsWith(".json"));
        if(files!=null)for(File file:files)highlights.put(file.getName().replaceFirst("\\.json$",""),PageHighlights.read(file));
        result.put("highlights",highlights);
        ReaderBackupData.validate(result);
        return result;
    }
    static byte[] bytes(JSONObject data) throws IOException {
        byte[] bytes=data.toString().getBytes(StandardCharsets.UTF_8);
        if(bytes.length>MAX_BYTES)throw new IOException("Kopia przekracza limit 25 MB.");
        return bytes;
    }
    static void recover(Context context) throws Exception {
        File journal=new File(context.getFilesDir(),"reader-restore.json");
        ReaderBackupTransaction.recover(journal,data -> apply(context,data));
    }
    static void restore(Context context,JSONObject incoming) throws Exception {
        ReaderBackupData.validate(incoming);
        JSONObject before=snapshot(context);
        JSONObject merged=ReaderBackupData.merge(before,incoming);
        ReaderBackupData.validate(merged);bytes(merged);
        File journal=new File(context.getFilesDir(),"reader-restore.json");
        ReaderBackupTransaction.restore(journal,bytes(before),merged,data -> apply(context,data));
    }
    private static void apply(Context context,JSONObject data) throws Exception {
        File root=new File(context.getFilesDir(),"page-highlights");
        if(!root.exists()&&!root.mkdirs())throw new IOException("Nie można odtworzyć notatek.");
        JSONObject highlights=data.getJSONObject("highlights");
        Iterator<String> keys=highlights.keys();
        while(keys.hasNext()){String key=keys.next();ReaderBackupTransaction.atomic(new File(root,key+".json"),highlights.getJSONArray(key).toString().getBytes(StandardCharsets.UTF_8));}
        File[] stored=root.listFiles((dir,name)->name.endsWith(".json"));
        if(stored!=null)for(File file:stored)if(!highlights.has(file.getName().replaceFirst("\\.json$","")))Files.delete(file.toPath());
        SharedPreferences.Editor marks=context.getSharedPreferences("page-bookmarks",Context.MODE_PRIVATE).edit().clear();
        JSONObject bookmarks=data.getJSONObject("bookmarks");keys=bookmarks.keys();
        while(keys.hasNext()){String key=keys.next();marks.putString(key,bookmarks.getString(key));}
        if(!marks.commit())throw new IOException("Nie udało się odtworzyć zakładek.");
        if(!context.getSharedPreferences("reader",Context.MODE_PRIVATE).edit().putString("prefs",data.getJSONObject("prefs").toString())
            .putString("positions",data.getJSONObject("positions").toString()).commit())throw new IOException("Nie udało się odtworzyć ustawień.");
    }
}
