package pl.jarekgadzina.dokumenty;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.zip.*;
import javax.xml.parsers.*;
import javax.xml.transform.*;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import org.w3c.dom.*;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;

/** Deliberately narrow DOCX edits: add new paragraphs, preserve existing content. */
public final class DocumentEdits {
    private static final String W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
    private DocumentEdits() {}

    public static void writeDocx(File source, File output, String text, int size, boolean bold, boolean italic) throws Exception {
        if (size < 8 || size > 72) throw new IOException("Wybierz rozmiar czcionki od 8 do 72.");
        if (text == null || text.length() > 200000) throw new IOException("Dopisany tekst może mieć maksymalnie 200 000 znaków.");
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if ((c < 32 && c != '\n' && c != '\r' && c != '\t') || c == '\ufffe' || c == '\uffff')
                throw new IOException("Tekst zawiera nieobsługiwany znak sterujący.");
        }
        if (source != null && source.getCanonicalFile().equals(output.getCanonicalFile()))
            throw new IOException("Zapisz dokument do nowego pliku.");
        Map<String, byte[]> entries = new LinkedHashMap<>();
        if (source != null) {
            try (ZipFile zip = new ZipFile(source)) {
                Enumeration<? extends ZipEntry> all = zip.entries();
                long total = 0;
                while (all.hasMoreElements()) {
                    ZipEntry entry = all.nextElement();
                    String name = entry.getName();
                    if (name.startsWith("_xmlsignatures/")) throw new IOException("Ten dokument jest podpisany cyfrowo. Utwórz niepodpisaną kopię w programie źródłowym.");
                    if (entries.size() >= 20000 || entries.containsKey(name)) throw new IOException("Nieprawidłowa struktura DOCX.");
                    try (InputStream in = zip.getInputStream(entry)) {
                        byte[] data = read(in, 100 * 1024 * 1024);
                        total += data.length;
                        if (total > 300L * 1024 * 1024) throw new IOException("Dokument jest zbyt duży do edycji na telefonie.");
                        entries.put(name, data);
                    }
                }
            }
            if (entries.containsKey("word/settings.xml")) {
                org.w3c.dom.Document settings = parse(entries.get("word/settings.xml"));
                NodeList restrictions = settings.getElementsByTagNameNS(W, "documentProtection");
                for (int i = 0; i < restrictions.getLength(); i++) {
                    String enforced = ((Element) restrictions.item(i)).getAttributeNS(W, "enforcement");
                    if (enforced.equals("1") || enforced.equals("true") || enforced.equals("on"))
                        throw new IOException("Dokument ma włączoną ochronę edycji. Wyłącz ją w programie źródłowym.");
                }
            }
        } else {
            entries.put("[Content_Types].xml", bytes("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>"));
            entries.put("_rels/.rels", bytes("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>"));
            entries.put("word/document.xml", bytes("<w:document xmlns:w=\"" + W + "\"><w:body><w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\"/></w:sectPr></w:body></w:document>"));
        }
        byte[] original = entries.get("word/document.xml");
        if (original == null) throw new IOException("To nie jest obsługiwany dokument DOCX.");
        org.w3c.dom.Document document = parse(original);
        NodeList bodies = document.getElementsByTagNameNS(W, "body");
        if (bodies.getLength() != 1) throw new IOException("Nieprawidłowa struktura dokumentu.");
        Element body = (Element) bodies.item(0);
        Node section = null;
        for (Node node = body.getFirstChild(); node != null; node = node.getNextSibling()) {
            if (W.equals(node.getNamespaceURI()) && "sectPr".equals(node.getLocalName())) section = node;
        }
        for (String line : text.replace("\r\n", "\n").replace('\r', '\n').split("\n", -1)) {
            Element paragraph = element(document, "p");
            Element run = element(document, "r");
            Element properties = element(document, "rPr");
            Element fonts = element(document, "rFonts");
            fonts.setAttributeNS(W, "w:ascii", "Arial"); fonts.setAttributeNS(W, "w:hAnsi", "Arial");
            properties.appendChild(fonts);
            for (String tag : new String[]{"sz", "szCs"}) {
                Element fontSize = element(document, tag); fontSize.setAttributeNS(W, "w:val", String.valueOf(size * 2));
                properties.appendChild(fontSize);
            }
            Element b = element(document, "b"); b.setAttributeNS(W, "w:val", bold ? "1" : "0"); properties.appendChild(b);
            Element it = element(document, "i"); it.setAttributeNS(W, "w:val", italic ? "1" : "0"); properties.appendChild(it);
            run.appendChild(properties);
            String[] tabs = line.split("\t", -1);
            for (int i = 0; i < tabs.length; i++) {
                if (i > 0) run.appendChild(element(document, "tab"));
                Element t = element(document, "t");
                t.setAttributeNS("http://www.w3.org/XML/1998/namespace", "xml:space", "preserve");
                t.setTextContent(tabs[i]); run.appendChild(t);
            }
            paragraph.appendChild(run); body.insertBefore(paragraph, section);
        }
        Transformer transformer = TransformerFactory.newInstance().newTransformer();
        transformer.setOutputProperty(OutputKeys.ENCODING, "UTF-8");
        transformer.setOutputProperty(OutputKeys.INDENT, "no");
        ByteArrayOutputStream xml = new ByteArrayOutputStream();
        transformer.transform(new DOMSource(document), new StreamResult(xml));
        entries.put("word/document.xml", xml.toByteArray());
        try (ZipOutputStream zip = new ZipOutputStream(new FileOutputStream(output))) {
            for (Map.Entry<String, byte[]> entry : entries.entrySet()) {
                zip.putNextEntry(new ZipEntry(entry.getKey())); zip.write(entry.getValue()); zip.closeEntry();
            }
        }
    }

    private static Element element(org.w3c.dom.Document document, String name) { return document.createElementNS(W, "w:" + name); }
    private static byte[] bytes(String value) { return value.getBytes(StandardCharsets.UTF_8); }
    private static byte[] read(InputStream in, int limit) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream(); byte[] buffer = new byte[32768]; int n;
        while ((n = in.read(buffer)) != -1) {
            if (out.size() + n > limit) throw new IOException("Składnik dokumentu jest zbyt duży.");
            out.write(buffer, 0, n);
        }
        return out.toByteArray();
    }
    private static org.w3c.dom.Document parse(byte[] data) throws Exception {
        if (data.length > 8 * 1024 * 1024) throw new IOException("Treść dokumentu jest zbyt duża do edycji.");
        String xml;
        if (data.length >= 2 && ((data[0] & 255) == 255 || (data[0] & 255) == 254)) xml = new String(data, StandardCharsets.UTF_16);
        else if (data.length >= 2 && data[0] == 0) xml = new String(data, StandardCharsets.UTF_16BE);
        else if (data.length >= 2 && data[1] == 0) xml = new String(data, StandardCharsets.UTF_16LE);
        else xml = new String(data, StandardCharsets.UTF_8);
        xml = xml.replaceFirst("^\uFEFF", "");
        if (xml.contains("<!DOCTYPE") || xml.contains("<!ENTITY")) throw new IOException("Nieobsługiwane deklaracje XML w dokumencie.");
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        DocumentBuilder builder = factory.newDocumentBuilder();
        builder.setEntityResolver((publicId, systemId) -> { throw new SAXException("External entities disabled"); });
        return builder.parse(new InputSource(new StringReader(xml)));
    }
}
