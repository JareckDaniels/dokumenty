import pl.jarekgadzina.dokumenty.SafeSave;
import java.io.*;
import java.nio.file.*;
import java.util.Arrays;

public class SafeSaveTest {
    static void check(boolean ok,String message) {if(!ok)throw new AssertionError(message);}
    public static void main(String[] args) throws Exception {
        File dir=Files.createTempDirectory("save-test-").toFile();
        File target=new File(dir,"target.docx"), source=new File(dir,"source.docx"), backup=new File(dir,"backup.docx");
        byte[] old="Oryginalna treść".getBytes(java.nio.charset.StandardCharsets.UTF_8);
        byte[] updated="Nowa treść — zażółć 😀".getBytes(java.nio.charset.StandardCharsets.UTF_8);
        try {
            Files.write(target.toPath(),old);Files.write(source.toPath(),updated);
            SafeSave.replace(source,backup,() -> new FileInputStream(target),() -> new FileOutputStream(target));
            check(Arrays.equals(Files.readAllBytes(target.toPath()),updated),"Success must save all bytes");
            check(!backup.exists(),"Successful backup should be removed");
            Files.write(target.toPath(),old); int[] opens={0};
            try {
                SafeSave.replace(source,backup,() -> new FileInputStream(target),() -> {
                    FileOutputStream out=new FileOutputStream(target);
                    if(++opens[0]>1)return out;
                    return new FilterOutputStream(out) {
                        @Override public void write(byte[] b,int off,int len) throws IOException {
                            out.write(b,off,Math.min(3,len));throw new IOException("Injected full disk");
                        }
                    };
                });throw new AssertionError("Expected failed write");
            }catch(IOException expected) {}
            check(Arrays.equals(Files.readAllBytes(target.toPath()),old),"Failed partial write must restore old bytes");
            check(!backup.exists(),"Restored backup should be removed");
            opens[0]=0;
            try {
                SafeSave.replace(source,backup,() -> {throw new IOException("Read denied");},() -> {opens[0]++;return new FileOutputStream(target);});
                throw new AssertionError("Expected read failure");
            }catch(IOException expected) {}
            check(opens[0]==0,"Never truncate without backup");
            check(Arrays.equals(Files.readAllBytes(target.toPath()),old),"Read failure must leave target untouched");
            try {
                SafeSave.replace(source,backup,() -> new FileInputStream(target),() -> {throw new IOException("Write denied");});
                throw new AssertionError("Expected rollback failure");
            }catch(IOException expected) {}
            check(backup.isFile() && Arrays.equals(Files.readAllBytes(backup.toPath()),old),"Keep backup if restoration fails");
            check(Arrays.equals(Files.readAllBytes(source.toPath()),updated),"Always preserve newly generated document");
            System.out.println("SafeSave success, partial-write rollback, read denial and retained recovery backup: PASS");
        }finally {target.delete();source.delete();backup.delete();dir.delete();}
    }
}
