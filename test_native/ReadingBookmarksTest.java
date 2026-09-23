import pl.jarekgadzina.dokumenty.ReadingBookmarks;
import java.util.*;

public class ReadingBookmarksTest {
    static void check(boolean condition, String description) {
        if(!condition)throw new AssertionError(description);
    }
    public static void main(String[] args) {
        String saved=ReadingBookmarks.update("",7,20,true);
        saved=ReadingBookmarks.update(saved,0,20,true);
        saved=ReadingBookmarks.update(saved,7,20,true);
        check(ReadingBookmarks.read(saved,20).equals(Arrays.asList(0,7)),"Sorted unique bookmarks survive serialization");
        saved=ReadingBookmarks.update(saved,7,20,false);
        check(ReadingBookmarks.read(saved,20).equals(Arrays.asList(0)),"Remove just selected page");
        check(ReadingBookmarks.update(saved,0,20,false).isEmpty(),"Empty document entry can be removed");
        check(ReadingBookmarks.read("-1,0,9,100,broken,0",10).equals(Arrays.asList(0,9)),"Ignore invalid and obsolete page indices");
        String full="";
        for(int page=0;page<50;page++)full=ReadingBookmarks.update(full,page,60,true);
        check(ReadingBookmarks.read(ReadingBookmarks.update(full,0,60,true),60).size()==50,"Duplicate addition at limit is idempotent");
        try { ReadingBookmarks.update(full,50,60,true);throw new AssertionError("Limit not enforced"); }
        catch(IllegalArgumentException expected) { }
        check(ReadingBookmarks.read(full,60).size()==50,"Limit failure preserves saved bookmarks");
        String freed=ReadingBookmarks.update(full,0,60,false);
        check(ReadingBookmarks.read(ReadingBookmarks.update(freed,50,60,true),60).size()==50,"Removing frees a slot");
        for(int page:new int[]{-1,60,Integer.MAX_VALUE}) {
            try {ReadingBookmarks.update(full,page,60,true);throw new AssertionError("Invalid page accepted");}
            catch(IllegalArgumentException expected){}
        }
        System.out.println("ReadingBookmarks: persistence format, boundaries, deduplication, removal and limits OK");
    }
}
