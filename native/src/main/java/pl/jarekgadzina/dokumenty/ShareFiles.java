package pl.jarekgadzina.dokumenty;

import java.io.*;
import java.nio.file.Files;
import java.util.Locale;
import java.util.UUID;

/** Immutable, isolated outgoing attachments; source files are never shared directly. */
public final class ShareFiles {
    private static final long MAX_FILE=100L*1024*1024, MAX_CACHE=500L*1024*1024;
    private static final long RETAIN_MS=48L*60*60*1000;
    private ShareFiles() {}
    public static String mime(String extension) {
        switch(extension.toLowerCase(Locale.ROOT)) {
            case "pdf":return "application/pdf";
            case "txt":return "text/plain";
            case "csv":return "text/csv";
            case "doc":return "application/msword";
            case "docx":return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
            case "odt":return "application/vnd.oasis.opendocument.text";
            case "xls":return "application/vnd.ms-excel";
            case "xlsx":return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            case "ods":return "application/vnd.oasis.opendocument.spreadsheet";
            case "rtf":return "application/rtf";
            default:throw new IllegalArgumentException("Nieobsługiwany format załącznika.");
        }
    }
    public static String filename(String name,String extension) {
        mime(extension);
        String suffix="."+extension.toLowerCase(Locale.ROOT);
        String safe=(name==null?"Dokument":name).replaceAll("[\\\\/\\p{Cntrl}]","_").trim();
        if(safe.toLowerCase(Locale.ROOT).endsWith(suffix)) safe=safe.substring(0,safe.length()-suffix.length());
        safe=safe.replaceFirst("^\\.+","");
        if(safe.isEmpty())safe="Dokument";
        if(safe.length()>120) {
            safe=safe.substring(0,120);
            if(Character.isHighSurrogate(safe.charAt(safe.length()-1)))safe=safe.substring(0,safe.length()-1);
        }
        return safe+suffix;
    }
    public static File snapshot(File cache,File source,String name,String extension) throws IOException {
        String leaf=filename(name,extension);
        if(!source.isFile() || source.length()>MAX_FILE)throw new IOException("Nie można przygotować załącznika (limit 100 MB).");
        File root=new File(cache,"outgoing");
        if(!root.exists()&&!root.mkdirs())throw new IOException("Brak miejsca na załącznik.");
        long total=0,now=System.currentTimeMillis();
        File[] dirs=root.listFiles();
        if(dirs!=null)for(File dir:dirs) {
            if(!dir.getName().matches("[a-f0-9-]{36}") || !dir.isDirectory())continue;
            boolean expired=now-dir.lastModified()>RETAIN_MS;
            File[] files=dir.listFiles();
            if(files!=null)for(File file:files) {
                if(file.isFile() && expired) file.delete();
                if(file.isFile())total+=file.length();
            }
            if(expired)dir.delete();
        }
        if(total+source.length()>MAX_CACHE)throw new IOException("Pamięć tymczasowych załączników jest pełna. Spróbuj później lub wyczyść pamięć podręczną aplikacji w ustawieniach Androida.");
        File folder=new File(root,UUID.randomUUID().toString());
        if(!folder.mkdir())throw new IOException("Nie można przygotować załącznika.");
        File target=new File(folder,leaf);
        try {
            Files.copy(source.toPath(),target.toPath());
            if(target.length()>MAX_FILE)throw new IOException("Załącznik przekracza 100 MB.");
            return target;
        }catch(IOException e){target.delete();folder.delete();throw e;}
    }
}
