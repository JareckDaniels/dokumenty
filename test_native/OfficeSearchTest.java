import pl.jarekgadzina.dokumenty.OfficeSearch;

public class OfficeSearchTest {
    public static void main(String[] args) throws Exception {
        String text = "Zażółć 😀 \"cytat\" \\ .* $1\n\t";
        System.out.println(OfficeSearch.arguments(text, "", false, false, OfficeSearch.FIND));
        System.out.println(OfficeSearch.arguments("Cena", "$1\\nowa", true, true, OfficeSearch.REPLACE));
        System.out.println(OfficeSearch.arguments(" ", "", false, true, OfficeSearch.REPLACE_ALL));
        for (String invalid : new String[]{null, "", "a".repeat(1001)}) {
            try { OfficeSearch.arguments(invalid, "", false, false, 0); throw new AssertionError("Accepted invalid query"); }
            catch (IllegalArgumentException expected) {}
        }
        try { OfficeSearch.arguments("a", "b", false, false, 9); throw new AssertionError("Accepted unknown operation"); }
        catch (IllegalArgumentException expected) {}
        try { OfficeSearch.arguments("a", "b".repeat(1001), false, false, 3); throw new AssertionError("Accepted oversized replacement"); }
        catch (IllegalArgumentException expected) {}
    }
}
