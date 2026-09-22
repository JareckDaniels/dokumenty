import pl.jarekgadzina.dokumenty.OfficeFormatting;
public class OfficeFormattingTest {
    public static void main(String[] args) {
        for(int size:new int[]{8,10,11,12,14,16,18,20,24,28,32,36,48,72})
            System.out.println(OfficeFormatting.fontSize(size));
        for(int size:new int[]{-1,0,7,73,Integer.MAX_VALUE}) {
            try {OfficeFormatting.fontSize(size);throw new AssertionError("Accepted invalid size");}
            catch(IllegalArgumentException expected) {}
        }
    }
}
