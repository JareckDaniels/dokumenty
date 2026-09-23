package pl.jarekgadzina.dokumenty;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import org.json.JSONObject;

/** Write-ahead snapshot: an unfinished restore always rolls back on next startup. */
public final class ReaderBackupTransaction {
    private ReaderBackupTransaction() {}
    public interface Apply { void run(JSONObject data) throws Exception; }
    public static void recover(File journal,Apply apply) throws Exception {
        if(!journal.exists())return;
        if(journal.length()>25*1024*1024)throw new IOException("Nieprawidłowy dziennik przywracania.");
        JSONObject before=new JSONObject(new String(Files.readAllBytes(journal.toPath()),StandardCharsets.UTF_8));
        ReaderBackupData.validate(before);apply.run(before);Files.delete(journal.toPath());
    }
    public static void restore(File journal,byte[] before,JSONObject merged,Apply apply) throws Exception {
        atomic(journal,before);
        try {apply.run(merged);Files.delete(journal.toPath());}
        catch(Exception e){try{recover(journal,apply);}catch(Exception rollback){e.addSuppressed(rollback);}throw e;}
    }
    static void atomic(File file,byte[] bytes) throws IOException {
        Path temp=Files.createTempFile(file.getParentFile().toPath(),"restore-",".tmp");
        try {try(FileOutputStream out=new FileOutputStream(temp.toFile())){out.write(bytes);out.getFD().sync();}
            Files.move(temp,file.toPath(),StandardCopyOption.ATOMIC_MOVE,StandardCopyOption.REPLACE_EXISTING);
        }finally{Files.deleteIfExists(temp);}
    }
}
