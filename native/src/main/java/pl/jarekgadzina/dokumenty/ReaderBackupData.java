package pl.jarekgadzina.dokumenty;

import java.io.IOException;
import java.util.*;
import org.json.*;

public final class ReaderBackupData {
    private ReaderBackupData() {}
    static void require(boolean ok) throws IOException {if(!ok)throw new IOException("Nieprawidłowa kopia Plikownika lub przekroczony limit danych.");}
    public static void validate(JSONObject data) throws Exception {
        require("plikownik-reader".equals(data.getString("format"))&&data.getInt("version")==1);
        JSONObject prefs=data.getJSONObject("prefs");
        require(Arrays.asList("original","dark","warm").contains(prefs.optString("paper","original")));
        require(Arrays.asList("recent","oldest","name","nameDesc").contains(prefs.optString("sort","recent")));
        if(prefs.has("awake"))require(prefs.get("awake") instanceof Boolean);
        JSONObject marks=data.getJSONObject("highlights"),bookmarks=data.getJSONObject("bookmarks"),positions=data.getJSONObject("positions");
        require(marks.length()<=200&&bookmarks.length()<=200&&positions.length()<=100);
        for(JSONObject group:Arrays.asList(marks,bookmarks,positions)) {
            Iterator<String> keys=group.keys();
            while(keys.hasNext())require(keys.next().matches("[a-f0-9]{64}(-sheets)?"));
        }
        Iterator<String> keys=marks.keys();
        while(keys.hasNext()) {
            JSONArray list=marks.getJSONArray(keys.next());require(list.length()<=500&&list.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8).length<=2*1024*1024);
            Set<String> ids=new HashSet<>();
            for(int i=0;i<list.length();i++) {
                JSONObject m=list.getJSONObject(i);String id=m.getString("id");
                require(id.length()<=100&&!id.isEmpty()&&ids.add(id));
                require(m.getInt("page")>=0&&m.getInt("page")<1000000);
                double l=m.getDouble("left"),t=m.getDouble("top"),r=m.getDouble("right"),b=m.getDouble("bottom");
                require(Double.isFinite(l+t+r+b)&&l>=0&&t>=0&&r<=1&&b<=1&&r>l&&b>t);
                require(Arrays.asList("yellow","green","pink").contains(m.getString("color"))&&m.getString("note").length()<=1000);
            }
        }
        keys=bookmarks.keys();
        while(keys.hasNext()) {String value=bookmarks.getString(keys.next());require(value.matches("[0-9,]*")&&value.length()<500);
            List<Integer> pages=ReadingBookmarks.read(value,1000000);require(pages.size()<=50);
            if(!value.isEmpty())for(String part:value.split(",",-1))require(!part.isEmpty()&&Long.parseLong(part)<1000000);
        }
        keys=positions.keys();while(keys.hasNext()) {
            JSONObject p=positions.getJSONObject(keys.next());
            require(p.getInt("page")>=0&&p.getInt("page")<1000000);
            for(String field:Arrays.asList("fraction","x","zoom")){double n=p.getDouble(field);require(Double.isFinite(n)&&n>=0&&n<=(field.equals("zoom")?12:1));}
            require(p.getDouble("zoom")>=1);
        }
    }
    /** Union annotations/bookmarks; current entries win ID conflicts, imported preferences win. */
    public static JSONObject merge(JSONObject current,JSONObject incoming) throws Exception {
        JSONObject merged=new JSONObject(current.toString());merged.put("prefs",incoming.getJSONObject("prefs"));
        for(String group:Arrays.asList("highlights","bookmarks","positions")) {
            JSONObject target=merged.getJSONObject(group),source=incoming.getJSONObject(group);Iterator<String> keys=source.keys();
            while(keys.hasNext()) {
                String key=keys.next();
                if(!target.has(key)){target.put(key,source.get(key));continue;}
                if(group.equals("highlights")) {
                    JSONArray list=target.getJSONArray(key),add=source.getJSONArray(key);Set<String> ids=new HashSet<>();
                    for(int i=0;i<list.length();i++)ids.add(list.getJSONObject(i).getString("id"));
                    for(int i=0;i<add.length();i++)if(ids.add(add.getJSONObject(i).getString("id")))list.put(add.getJSONObject(i));
                }else if(group.equals("bookmarks")) {
                    String value=target.getString(key);
                    for(int page:ReadingBookmarks.read(source.getString(key),1000000))value=ReadingBookmarks.update(value,page,1000000,true);
                    target.put(key,value);
                }
            }
        }
        return merged;
    }
}
