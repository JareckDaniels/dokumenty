import pl.jarekgadzina.dokumenty.*;
import org.json.*;
import java.nio.file.*;
import java.util.*;

public class ReleaseOneTest {
    static void check(boolean ok,String message){if(!ok)throw new AssertionError(message);}
    interface Task{void run()throws Exception;}
    static void rejects(Task task)throws Exception{try{task.run();throw new AssertionError("Invalid input accepted");}catch(java.io.IOException|IllegalArgumentException expected){}}
    static JSONObject empty()throws Exception{return new JSONObject().put("format","plikownik-reader").put("version",1).put("prefs",new JSONObject()).put("positions",new JSONObject()).put("bookmarks",new JSONObject()).put("highlights",new JSONObject());}
    static JSONObject mark(String id,int page)throws Exception{return new JSONObject().put("id",id).put("page",page).put("left",.1).put("top",.2).put("right",.8).put("bottom",.3).put("note","Zażółć\nDrugi wiersz").put("color","yellow");}
    public static void main(String[] args)throws Exception {
        float[] q=AnnotationGeometry.quad(.1f,.2f,.8f,.3f,10,20,200,400,0);
        check(Arrays.equals(q,new float[]{30,340,170,340,30,300,170,300}),"Unrotated crop geometry");
        for(int rotation:new int[]{0,90,180,270,-90,450}){
            q=AnnotationGeometry.quad(.1f,.2f,.8f,.3f,10,20,200,400,rotation);
            for(int i=0;i<8;i+=2){check(q[i]>=10&&q[i]<=210&&q[i+1]>=20&&q[i+1]<=420,"Crop bounds");
                float u=(q[i]-10)/200,v=(q[i+1]-20)/400,x=0,y=0;
                switch((rotation%360+360)%360){case 0:x=u;y=1-v;break;case 90:x=v;y=u;break;case 180:x=1-u;y=v;break;case 270:x=1-v;y=1-u;break;}
                check(Math.abs(x-(i==2||i==6?.8f:.1f))<.00001&&Math.abs(y-(i>=4?.3f:.2f))<.00001,"Rotation inverse preserves display position");
            }
        }
        rejects(()->AnnotationGeometry.quad(0,0,1,1,0,0,100,100,45));
        rejects(()->AnnotationGeometry.quad(Float.NaN,0,1,1,0,0,100,100,0));
        String key="a".repeat(64);JSONObject current=empty(),incoming=empty();
        current.getJSONObject("highlights").put(key,new JSONArray().put(mark("same",0)));
        incoming.getJSONObject("highlights").put(key,new JSONArray().put(mark("same",0).put("note","old")).put(mark("new",1)));
        current.getJSONObject("bookmarks").put(key,"0,4");incoming.getJSONObject("bookmarks").put(key,"2,4");
        incoming.getJSONObject("prefs").put("paper","warm");
        ReaderBackupData.validate(current);ReaderBackupData.validate(incoming);
        JSONObject merged=ReaderBackupData.merge(current,incoming);ReaderBackupData.validate(merged);
        check(merged.getJSONObject("highlights").getJSONArray(key).length()==2,"Union and deduplication");
        check(merged.getJSONObject("highlights").getJSONArray(key).getJSONObject(0).getString("note").startsWith("Zażółć"),"Current note wins");
        check(merged.getJSONObject("bookmarks").getString(key).equals("0,2,4"),"Bookmark union");
        check(merged.getJSONObject("prefs").getString("paper").equals("warm"),"Imported preferences");
        check(current.getJSONObject("highlights").getJSONArray(key).length()==1,"No mutation of current snapshot");
        check(ReaderBackupData.merge(merged,incoming).toString().equals(merged.toString()),"Repeated restore idempotent");
        JSONObject bad=empty();bad.getJSONObject("highlights").put("../escape",new JSONArray());rejects(()->ReaderBackupData.validate(bad));
        JSONObject broken=empty();broken.getJSONObject("highlights").put(key,new JSONArray().put(mark("x",0).put("left",-1)));rejects(()->ReaderBackupData.validate(broken));
        JSONObject version=empty().put("version",2);rejects(()->ReaderBackupData.validate(version));
        Path root=Files.createTempDirectory("release-one");java.io.File file=root.resolve("marks.json").toFile();
        try {
            JSONObject batch=new JSONObject().put("marks",new JSONArray().put(mark("a",0)).put(mark("b",1)));
            JSONArray saved=PageHighlights.change(file,2,"addBatch",batch);check(saved.length()==2,"Batch persisted");
            byte[] before=Files.readAllBytes(file.toPath());
            batch.getJSONArray("marks").put(mark("bad",2));rejects(()->PageHighlights.change(file,2,"addBatch",batch));
            check(Arrays.equals(before,Files.readAllBytes(file.toPath())),"Invalid row cannot partially save batch");
        }finally{Files.deleteIfExists(file.toPath());Files.delete(root);}
        Path transaction=Files.createTempDirectory("backup-transaction");java.io.File journal=transaction.resolve("journal.json").toFile();
        JSONObject[] live={current};
        try {
            byte[] original=current.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8);
            try {ReaderBackupTransaction.restore(journal,original,merged,data -> {
                live[0]=data;
                if(data==merged)throw new java.io.IOException("Disk failure halfway through restore");
            });throw new AssertionError("Failure swallowed");}catch(java.io.IOException expected){}
            check(live[0].toString().equals(current.toString())&&!journal.exists(),"Failed restore rolls back old snapshot");
            Files.write(journal.toPath(),original);live[0]=merged;
            ReaderBackupTransaction.recover(journal,data -> live[0]=data);
            check(live[0].toString().equals(current.toString()),"Interrupted process restored from journal");
            Files.write(journal.toPath(),original);
            try {ReaderBackupTransaction.recover(journal,data -> {throw new java.io.IOException("Disk still full");});}catch(java.io.IOException expected){}
            check(journal.exists(),"Failed rollback retains recovery evidence");
            ReaderBackupTransaction.recover(journal,data -> live[0]=data);
            ReaderBackupTransaction.restore(journal,original,merged,data -> live[0]=data);
            check(live[0]==merged&&!journal.exists(),"Successful restore commits and removes journal");
        }finally{Files.deleteIfExists(journal.toPath());Files.delete(transaction);}
        System.out.println("1.0: rotated/cropped PDF coordinates, backup validation/merge/idempotency, atomic text highlight batch OK");
    }
}
