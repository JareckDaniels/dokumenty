package pl.jarekgadzina.dokumenty;

import java.io.*;
import org.json.*;
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader;
import com.tom_roush.pdfbox.io.MemoryUsageSetting;
import com.tom_roush.pdfbox.pdmodel.*;
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle;
import com.tom_roush.pdfbox.pdmodel.graphics.color.*;
import com.tom_roush.pdfbox.pdmodel.interactive.annotation.PDAnnotationTextMarkup;

/** Standard PDF annotations; page content and existing annotations are retained. */
final class AnnotatedPdf {
    static void write(android.content.Context context, File source, File target, JSONArray marks) throws Exception {
        if(marks.length()==0)throw new IOException("Brak zaznaczeń do eksportu.");
        PDFBoxResourceLoader.init(context.getApplicationContext());
        try(PDDocument document=PDDocument.load(source,MemoryUsageSetting.setupMixed(16*1024*1024).setTempDir(context.getCacheDir()))) {
            if(!document.getCurrentAccessPermission().canModifyAnnotations())throw new IOException("Ten PDF nie zezwala na dodawanie adnotacji.");
            if(!document.getSignatureDictionaries().isEmpty())throw new IOException("PDF jest podpisany cyfrowo. Udostępnij oryginał i osobny plik notatek, aby zachować podpis.");
            for(int i=0;i<marks.length();i++) {
                JSONObject mark=marks.getJSONObject(i);
                int index=mark.getInt("page");
                if(index<0||index>=document.getNumberOfPages())throw new IOException("Nieprawidłowa strona zaznaczenia.");
                PDPage page=document.getPage(index);
                PDRectangle crop=page.getCropBox();
                float[] quad=AnnotationGeometry.quad((float)mark.getDouble("left"),(float)mark.getDouble("top"),
                    (float)mark.getDouble("right"),(float)mark.getDouble("bottom"),crop.getLowerLeftX(),crop.getLowerLeftY(),crop.getWidth(),crop.getHeight(),page.getRotation());
                float minX=Float.MAX_VALUE,minY=Float.MAX_VALUE,maxX=-Float.MAX_VALUE,maxY=-Float.MAX_VALUE;
                for(int j=0;j<8;j+=2){minX=Math.min(minX,quad[j]);minY=Math.min(minY,quad[j+1]);maxX=Math.max(maxX,quad[j]);maxY=Math.max(maxY,quad[j+1]);}
                PDAnnotationTextMarkup annotation=new PDAnnotationTextMarkup(PDAnnotationTextMarkup.SUB_TYPE_HIGHLIGHT);
                annotation.setRectangle(new PDRectangle(minX,minY,maxX-minX,maxY-minY));
                annotation.setQuadPoints(quad);
                String color=mark.optString("color","yellow");
                float[] rgb=color.equals("green")?new float[]{.396f,.859f,.467f}:color.equals("pink")?new float[]{1,.498f,.741f}:new float[]{1,.831f,.231f};
                annotation.setColor(new PDColor(rgb,PDDeviceRGB.INSTANCE));
                annotation.setConstantOpacity(.38f);
                annotation.setContents(mark.optString("note",""));
                annotation.setTitlePopup("Plikownik");
                annotation.setPrinted(true);
                annotation.setPage(page);
                page.getAnnotations().add(annotation);
                annotation.constructAppearances();
            }
            document.save(target);
        }
    }
}
