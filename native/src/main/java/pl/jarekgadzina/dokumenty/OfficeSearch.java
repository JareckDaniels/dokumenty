package pl.jarekgadzina.dokumenty;

/** Literal Writer search; no regular expressions or replacement backreferences. */
public final class OfficeSearch {
    public static final int FIND = 0, REPLACE = 2, REPLACE_ALL = 3;
    private OfficeSearch() {}
    public static String arguments(String query, String replacement, boolean backward,
                                   boolean matchCase, int mode) throws Exception {
        if (query == null || query.isEmpty()) throw new IllegalArgumentException("Wpisz szukany tekst.");
        if (query.length() > 1000 || replacement == null || replacement.length() > 1000)
            throw new IllegalArgumentException("Wyszukiwanie i zamiana obsługują do 1000 znaków.");
        if (mode != FIND && mode != REPLACE && mode != REPLACE_ALL)
            throw new IllegalArgumentException("Nieobsługiwany rodzaj wyszukiwania.");
        return "{" +
            property("SearchItem.SearchString", "string", quote(query)) + "," +
            property("SearchItem.ReplaceString", "string", quote(replacement)) + "," +
            property("SearchItem.Backward", "boolean", String.valueOf(backward)) + "," +
            property("SearchItem.Command", "long", String.valueOf(mode)) + "," +
            property("SearchItem.AlgorithmType", "short", "0") + "," +
            property("SearchItem.SearchFlags", "long", "0") + "," +
            property("SearchItem.TransliterateFlags", "long", matchCase ? "0" : "1") + "," +
            property("SearchItem.Pattern", "boolean", "false") + "," +
            property("Quiet", "boolean", "true") + "}";
    }
    private static String property(String name, String type, String jsonValue) {
        return quote(name) + ":{\"type\":" + quote(type) + ",\"value\":" + jsonValue + "}";
    }
    private static String quote(String text) {
        StringBuilder out = new StringBuilder("\"");
        // Escape every UTF-16 code unit. Paired surrogates remain paired in JSON;
        // punctuation, backslashes and control characters cannot become UNO arguments.
        for (int i = 0; i < text.length(); i++) {
            String hex = Integer.toHexString(text.charAt(i));
            out.append('\\').append('u');
            for (int j = hex.length(); j < 4; j++) out.append('0');
            out.append(hex);
        }
        return out.append('"').toString();
    }
}
