package pl.jarekgadzina.dokumenty;

public final class OfficeFormatting {
    private OfficeFormatting() {}
    public static String fontSize(int points) {
        if (points < 8 || points > 72) throw new IllegalArgumentException("Rozmiar czcionki: od 8 do 72 pkt.");
        // svxitems.sdi defines SvxFontHeight as a struct with the float member Height.
        // FontHeight alone addresses the whole struct, not its numeric height.
        return "{\"FontHeight.Height\":{\"type\":\"float\",\"value\":\"" + points + ".0\"}}";
    }
}
