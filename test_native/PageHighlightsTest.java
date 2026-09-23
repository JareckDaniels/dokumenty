import pl.jarekgadzina.dokumenty.PageHighlights;
import java.io.*;
import java.nio.file.*;
import java.util.*;
import org.json.*;

public class PageHighlightsTest {
    static void check(boolean value,String reason){if(!value)throw new AssertionError(reason);}
    static JSONObject mark()throws Exception {
        return new JSONObject().put("page",2).put("left",0.1).put("top",0.2).put("right",0.7).put("bottom",0.23).put("color","yellow");
    }
    public static void main(String[] args)throws Exception {
        Path root=Files.createTempDirectory("page-highlights");
        try {
            File file=root.resolve("private/abc.json").toFile();
            check(PageHighlights.read(file).length()==0,"New document has no highlights");
            JSONArray added=PageHighlights.change(file,10,"add",mark());
            String id=added.getJSONObject(0).getString("id");
            UUID.fromString(id);
            check(PageHighlights.read(file).getJSONObject(0).getDouble("left")==0.1,"Coordinates survive reload");
            JSONObject edit=new JSONObject().put("id",id).put("note","Zażółć gęślą\nDrugi wiersz").put("color","pink");
            PageHighlights.change(file,10,"edit",edit);
            check(PageHighlights.read(file).getJSONObject(0).getString("note").equals("Zażółć gęślą\nDrugi wiersz"),"Notes survive reload");
            check(PageHighlights.read(file).getJSONObject(0).getString("color").equals("pink"),"Changed color persists");
            byte[] before=Files.readAllBytes(file.toPath());
            for(JSONObject bad:new JSONObject[]{mark().put("left",-0.1),mark().put("right",0.05),mark().put("page",10),mark().put("color","blue"),mark().put("note","x".repeat(1001))}) {
                try {PageHighlights.change(file,10,"add",bad);throw new AssertionError("Bad mark accepted");}
                catch(IOException expected){}
                check(Arrays.equals(before,Files.readAllBytes(file.toPath())),"Failed update preserves previous data");
            }
            try {PageHighlights.change(file,10,"delete",new JSONObject().put("id","missing"));throw new AssertionError("Missing mark");}
            catch(IOException expected){}
            PageHighlights.change(file,10,"delete",new JSONObject().put("id",id));
            check(!file.exists(),"Last deletion removes sidecar");
            JSONArray full=new JSONArray();
            for(int i=0;i<500;i++)full.put(mark().put("id","id-"+i).put("note",""));
            Files.writeString(file.toPath(),full.toString());
            try {PageHighlights.change(file,10,"add",mark());throw new AssertionError("Limit");}
            catch(IOException expected){}
            check(PageHighlights.read(file).length()==500,"Limit preserves all old marks");
            File blocked=root.resolve("blocked.json").toFile();blocked.mkdir();
            Files.writeString(blocked.toPath().resolve("keep"),"original");
            try {PageHighlights.change(blocked,10,"add",mark());throw new AssertionError("Replace nonempty directory");}
            catch(IOException expected){}
            check(Files.readString(blocked.toPath().resolve("keep")).equals("original"),"Failed move preserves destination");
            try(var paths=Files.list(root)){check(paths.noneMatch(p -> p.toString().endsWith(".tmp")),"No abandoned temporary files");}
            System.out.println("PageHighlights: persistence, Unicode notes, colors, bounds, limits, deletion and failed writes OK");
        }finally{
            try(var paths=Files.walk(root)){for(Path path:paths.sorted(Comparator.reverseOrder()).toList())Files.deleteIfExists(path);}
        }
    }
}
