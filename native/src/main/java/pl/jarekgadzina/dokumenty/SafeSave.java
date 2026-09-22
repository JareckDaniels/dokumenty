package pl.jarekgadzina.dokumenty;

import java.io.*;

/** Stream providers need not support atomic rename; retain a backup until write/close succeeds. */
public final class SafeSave {
    public interface Reader { InputStream open() throws Exception; }
    public interface Writer { OutputStream open() throws Exception; }
    private SafeSave() {}
    public static void replace(File source, File backup, Reader reader, Writer writer) throws Exception {
        // Refuse to truncate a target if its current bytes cannot be backed up first.
        try (InputStream in = reader.open(); OutputStream out = new FileOutputStream(backup)) {
            copy(in, out);
        } catch (Exception e) { backup.delete(); throw e; }
        try (InputStream in = new FileInputStream(source); OutputStream out = writer.open()) {
            copy(in, out);
        } catch (Exception writeError) {
            try (InputStream in = new FileInputStream(backup); OutputStream out = writer.open()) {
                copy(in, out);
            } catch (Exception restoreError) {
                IOException failure = new IOException("Zapis i przywrócenie pliku nie powiodły się. Dokument nadal jest w edytorze — użyj Zapisz jako. Kopia wcześniejszego pliku pozostała w pamięci aplikacji.", writeError);
                failure.addSuppressed(restoreError); throw failure; // Keep backup for recovery.
            }
            backup.delete();
            throw new IOException("Zapis nie powiódł się. Przywrócono poprzednią zawartość pliku; zmiany nadal są w edytorze.", writeError);
        }
        backup.delete();
    }
    private static void copy(InputStream in, OutputStream out) throws IOException {
        if (in == null || out == null) throw new IOException("Brak dostępu do pliku.");
        byte[] buffer = new byte[32768]; int n; long total = 0;
        while ((n = in.read(buffer)) != -1) {
            total += n;
            if (total > 100L * 1024 * 1024) throw new IOException("Limit zapisu to 100 MB.");
            out.write(buffer, 0, n);
        }
        out.flush();
    }
}
