package pl.jarekgadzina.dokumenty;

import android.graphics.Point;
import android.graphics.RectF;
import android.graphics.pdf.PdfRenderer;
import java.io.IOException;
import java.util.*;

/** API 35 selection, reflected so the reader still installs on API 26. */
final class PdfTextSelection {
    static Map<String,Object> select(PdfRenderer renderer,int index,List<Number> start,List<Number> stop) throws Exception {
        if(android.os.Build.VERSION.SDK_INT<35)throw new IOException("Zaznaczanie tekstu wymaga Androida 15 lub nowszego.");
        if(index<0||index>=renderer.getPageCount()||start==null||stop==null||start.size()!=2||stop.size()!=2)throw new IOException("Nieprawidłowe zaznaczenie.");
        for(Number n:Arrays.asList(start.get(0),start.get(1),stop.get(0),stop.get(1)))if(n==null||!Double.isFinite(n.doubleValue())||n.doubleValue()<0||n.doubleValue()>1)throw new IOException("Nieprawidłowy punkt.");
        try(PdfRenderer.Page page=renderer.openPage(index)) {
            Class<?> boundary=Class.forName("android.graphics.pdf.models.selection.SelectionBoundary");
            Object a=boundary.getConstructor(Point.class).newInstance(new Point(Math.round(start.get(0).floatValue()*page.getWidth()),Math.round(start.get(1).floatValue()*page.getHeight())));
            Object b=boundary.getConstructor(Point.class).newInstance(new Point(Math.round(stop.get(0).floatValue()*page.getWidth()),Math.round(stop.get(1).floatValue()*page.getHeight())));
            Object selection=PdfRenderer.Page.class.getMethod("selectContent",boundary,boundary).invoke(page,a,b);
            List<Object> rectangles=new ArrayList<>();StringBuilder text=new StringBuilder();
            if(selection!=null) {
                List<?> contents=(List<?>)selection.getClass().getMethod("getSelectedTextContents").invoke(selection);
                for(Object content:contents) {
                    if(text.length()>0)text.append('\n');text.append((String)content.getClass().getMethod("getText").invoke(content));
                    List<?> bounds=(List<?>)content.getClass().getMethod("getBounds").invoke(content);
                    for(Object item:bounds){RectF r=(RectF)item;
                        float l=Math.max(0,r.left/page.getWidth()),t=Math.max(0,r.top/page.getHeight()),right=Math.min(1,r.right/page.getWidth()),bottom=Math.min(1,r.bottom/page.getHeight());
                        if(right>l&&bottom>t)rectangles.add(Arrays.asList(l,t,right,bottom));}
                }
            }
            Map<String,Object> result=new HashMap<>();result.put("text",text.toString());result.put("rects",rectangles);return result;
        }
    }
}
