import pl.jarekgadzina.dokumenty.ShareFiles;
import java.io.*;
import java.nio.file.*;
import java.util.*;

public class ShareFilesTest {
    static void check(boolean value,String message) {
        if(!value)throw new AssertionError(message);
    }
    public static void main(String[] args)throws Exception {
        Path root=Files.createTempDirectory("share-files-test");
        try {
            File source=root.resolve("source.docx").toFile();
            byte[] original={0,1,2,3,(byte)255,64};
            Files.write(source.toPath(),original);
            File first=ShareFiles.snapshot(root.toFile(),source,"Zażółć gęślą.docx","docx");
            check(first.getName().equals("Zażółć gęślą.docx"),"Polish name preserved");
            check(Arrays.equals(original,Files.readAllBytes(first.toPath())),"Exact attachment bytes");
            File second=ShareFiles.snapshot(root.toFile(),source,"Zażółć gęślą.docx","docx");
            check(!first.equals(second),"Each share isolated");
            Files.write(source.toPath(),new byte[]{99});
            check(Arrays.equals(original,Files.readAllBytes(first.toPath())),"Source changes do not modify attachment");
            File safe=ShareFiles.snapshot(root.toFile(),source,"../../escape\n/file.docx","docx");
            check(safe.getCanonicalFile().getParentFile().getParentFile().equals(root.resolve("outgoing").toFile().getCanonicalFile()),"Filename cannot escape share directory");
            check(!safe.getName().contains("\n"),"Control characters removed");
            check(ShareFiles.filename("RAPORT.PDF","pdf").equals("RAPORT.pdf"),"No duplicate extension");
            check(ShareFiles.mime("PDF").equals("application/pdf"),"PDF MIME");
            check(ShareFiles.mime("docx").endsWith("wordprocessingml.document"),"DOCX MIME");
            for(String ext:new String[]{"pdf","txt","csv","doc","docx","odt","xls","xlsx","ods","rtf"})
                check(!ShareFiles.mime(ext).isEmpty(),"Supported format "+ext);
            try {ShareFiles.mime("exe");throw new AssertionError("Unsupported format");}
            catch(IllegalArgumentException expected){}
            // Multiple files exercise directory timestamp changes during cleanup.
            Files.write(first.getParentFile().toPath().resolve("other.pdf"),original);
            check(first.getParentFile().setLastModified(System.currentTimeMillis()-49L*60*60*1000),"Set age");
            ShareFiles.snapshot(root.toFile(),source,"fresh.docx","docx");
            check(!first.getParentFile().exists(),"Expired attachment directory fully removed");
            check(second.isFile(),"Recent attachments survive cleanup");
            check(Files.readAllBytes(source.toPath())[0]==99,"Source never changed by sharing");
            try {ShareFiles.snapshot(root.toFile(),root.resolve("missing").toFile(),"x.pdf","pdf");throw new AssertionError("Missing file");}
            catch(IOException expected){}
            System.out.println("ShareFiles: bytes, isolation, names, MIME and cleanup OK");
        } finally {
            try(var files=Files.walk(root)) {
                for(Path file:files.sorted(Comparator.reverseOrder()).toList())Files.deleteIfExists(file);
            }
        }
    }
}
