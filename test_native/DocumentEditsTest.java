import pl.jarekgadzina.dokumenty.DocumentEdits;
import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.zip.*;
import javax.xml.parsers.DocumentBuilderFactory;
import org.w3c.dom.*;

public class DocumentEditsTest {
    static final String W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
    static void check(boolean condition, String message) { if (!condition) throw new AssertionError(message); }
    static Map<String, byte[]> entries(File file) throws Exception {
        Map<String, byte[]> result = new LinkedHashMap<>();
        try (ZipFile zip = new ZipFile(file)) {
            Enumeration<? extends ZipEntry> all = zip.entries();
            while (all.hasMoreElements()) {
                ZipEntry entry = all.nextElement();
                try (InputStream in = zip.getInputStream(entry)) { result.put(entry.getName(), in.readAllBytes()); }
            }
        }
        return result;
    }
    static Document xml(byte[] bytes) throws Exception {
        DocumentBuilderFactory f = DocumentBuilderFactory.newInstance(); f.setNamespaceAware(true);
        return f.newDocumentBuilder().parse(new ByteArrayInputStream(bytes));
    }
    public static void main(String[] args) throws Exception {
        Path temp = Files.createTempDirectory("document-edits-test");
        File source = temp.resolve("source.docx").toFile();
        File result = temp.resolve("edited.docx").toFile();
        DocumentEdits.writeDocx(null, source, "Oryginał", 12, false, false);
        byte[] originalFile = Files.readAllBytes(source.toPath());
        Map<String, byte[]> before = entries(source);
        DocumentEdits.writeDocx(source, result, "Zażółć gęślą jaźń 😀 & < >\nDrugi\takapit", 18, true, true);
        Map<String, byte[]> after = entries(result);
        check(Arrays.equals(originalFile, Files.readAllBytes(source.toPath())), "Original overwritten");
        check(before.keySet().equals(after.keySet()), "ZIP entries lost");
        for (String name : before.keySet()) if (!name.equals("word/document.xml"))
            check(Arrays.equals(before.get(name), after.get(name)), "Changed entry: " + name);
        Document old = xml(before.get("word/document.xml")), edited = xml(after.get("word/document.xml"));
        NodeList paragraphs = edited.getElementsByTagNameNS(W, "p");
        check(paragraphs.getLength() == 3, "Wrong paragraph count");
        check(old.getElementsByTagNameNS(W, "p").item(0).isEqualNode(paragraphs.item(0)), "Original paragraph changed");
        check(paragraphs.item(1).getTextContent().equals("Zażółć gęślą jaźń 😀 & < >"), "Unicode lost");
        check(((Element) edited.getElementsByTagNameNS(W, "sz").item(1)).getAttributeNS(W, "val").equals("36"), "Font size lost");
        check(edited.getElementsByTagNameNS(W, "tab").getLength() == 1, "Tab lost");
        boolean rejected = false;
        try { DocumentEdits.writeDocx(source, source, "overwrite", 12, false, false); } catch (IOException expected) { rejected = true; }
        check(rejected, "In-place overwrite was allowed");
        System.out.println("DOCX creation, append, Unicode, formatting and source preservation: PASS");
    }
}
