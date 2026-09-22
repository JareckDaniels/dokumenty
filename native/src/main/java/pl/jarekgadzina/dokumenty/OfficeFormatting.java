package pl.jarekgadzina.dokumenty;

public final class OfficeFormatting {
    private OfficeFormatting() {}
    public static String fontSize(int points) {
        if (points < 8 || points > 72) throw new IllegalArgumentException("Rozmiar czcionki: od 8 do 72 pkt.");
        // Use the string-valued representation expected by LibreOffice's UNO JSON bridge.
        return "{\"FontHeight\":{\"type\":\"float\",\"value\":\"" + points + ".0\"}}";
    }
}
