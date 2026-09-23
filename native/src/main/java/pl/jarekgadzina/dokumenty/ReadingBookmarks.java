package pl.jarekgadzina.dokumenty;

import java.util.*;

/** Page indices in a content-specific preview; never written into the document. */
public final class ReadingBookmarks {
    public static final int MAX_PAGES = 50;
    private ReadingBookmarks() {}
    public static List<Integer> read(String encoded, int pageCount) {
        TreeSet<Integer> pages = new TreeSet<>();
        if (encoded != null) for (String token : encoded.split(",")) {
            try {
                int page = Integer.parseInt(token);
                if (page >= 0 && page < pageCount) pages.add(page);
            } catch (NumberFormatException ignored) { }
        }
        return new ArrayList<>(pages);
    }
    public static String update(String encoded, int page, int pageCount, boolean add) {
        if (page < 0 || page >= pageCount) throw new IllegalArgumentException("Nieprawidłowy numer strony.");
        TreeSet<Integer> pages = new TreeSet<>(read(encoded, pageCount));
        if (add) {
            if (!pages.contains(page) && pages.size() >= MAX_PAGES)
                throw new IllegalArgumentException("Możesz zaznaczyć maksymalnie 50 stron w dokumencie.");
            pages.add(page);
        } else pages.remove(page);
        StringJoiner result = new StringJoiner(",");
        for (int value : pages) result.add(Integer.toString(value));
        return result.toString();
    }
}
