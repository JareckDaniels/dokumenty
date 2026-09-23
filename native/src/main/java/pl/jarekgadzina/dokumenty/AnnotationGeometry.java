package pl.jarekgadzina.dokumenty;

/** Normalized, top-left display coordinates -> cropped, rotated PDF user space. */
public final class AnnotationGeometry {
    private AnnotationGeometry() {}
    public static float[] quad(float l,float t,float r,float b,float x,float y,float w,float h,int rotation) {
        if(!Float.isFinite(l+t+r+b+x+y+w+h)||l<0||t<0||r>1||b>1||r<=l||b<=t||w<=0||h<=0)
            throw new IllegalArgumentException("Nieprawidłowe współrzędne PDF.");
        int angle=((rotation%360)+360)%360;
        float[] out={l,t,r,t,l,b,r,b};
        for(int i=0;i<8;i+=2) {
            float u=out[i],v=out[i+1];
            switch(angle) {
                case 0: out[i]=x+u*w;out[i+1]=y+(1-v)*h;break;
                case 90: out[i]=x+v*w;out[i+1]=y+u*h;break;
                case 180: out[i]=x+(1-u)*w;out[i+1]=y+v*h;break;
                case 270: out[i]=x+(1-v)*w;out[i+1]=y+(1-u)*h;break;
                default: throw new IllegalArgumentException("Nieobsługiwany obrót strony.");
            }
        }
        return out;
    }
}
