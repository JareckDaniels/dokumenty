package pl.jarekgadzina.dokumenty;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.List;

/** Local diagnostic records. No upload or document/search text is recorded. */
final class AppDiagnostics {
    private static boolean installed;
    private static SharedPreferences prefs(Context c) { return c.getSharedPreferences("diagnostics",Context.MODE_PRIVATE); }
    static synchronized void install(Context context) {
        if (installed) return;
        installed=true;
        Context app=context.getApplicationContext();
        Thread.UncaughtExceptionHandler previous=Thread.getDefaultUncaughtExceptionHandler();
        Thread.setDefaultUncaughtExceptionHandler((thread,error) -> {
            try {
                StringWriter log=new StringWriter(); error.printStackTrace(new PrintWriter(log));
                String text=log.toString(); if(text.length()>16000) text=text.substring(0,16000);
                prefs(app).edit().putString("java",System.currentTimeMillis()+"\n"+text).commit();
            } catch (Throwable ignored) { }
            if(previous!=null) previous.uncaughtException(thread,error);
            else { android.os.Process.killProcess(android.os.Process.myPid()); System.exit(10); }
        });
    }
    static void mark(Context c,String operation) {
        prefs(c).edit().putString("operation",System.currentTimeMillis()+" "+operation).commit();
    }
    static String read(Context c) {
        String version="?";
        try { version=c.getPackageManager().getPackageInfo(c.getPackageName(),0).versionName; } catch(Exception ignored) { }
        StringBuilder out=new StringBuilder("Plikownik "+version+"; Android API "+Build.VERSION.SDK_INT+"\n");
        out.append("Ostatnia operacja: ").append(prefs(c).getString("operation","brak")).append('\n');
        out.append("Ostatni zapisany błąd Java:\n").append(prefs(c).getString("java","brak")).append('\n');
        if(Build.VERSION.SDK_INT>=30) {
            try {
                Object manager=c.getSystemService(Context.ACTIVITY_SERVICE);
                Object value=manager.getClass().getMethod("getHistoricalProcessExitReasons",String.class,int.class,int.class)
                    .invoke(manager,c.getPackageName(),0,1);
                List<?> exits=(List<?>)value;
                if(!exits.isEmpty()) {
                    Object exit=exits.get(0); Class<?> type=exit.getClass();
                    out.append("Ostatnie zakończenie procesu: ").append(type.getMethod("getTimestamp").invoke(exit))
                        .append("; powód: ").append(type.getMethod("getReason").invoke(exit))
                        .append("; ").append(type.getMethod("getDescription").invoke(exit)).append('\n');
                    int reason=((Number)type.getMethod("getReason").invoke(exit)).intValue();
                    if(reason==4 || reason==5 || reason==6) {
                        try(InputStream in=(InputStream)type.getMethod("getTraceInputStream").invoke(exit)) {
                            if(in!=null) {
                                ByteArrayOutputStream trace=new ByteArrayOutputStream(); byte[] buf=new byte[4096]; int n;
                                while(trace.size()<24000 && (n=in.read(buf,0,Math.min(buf.length,24000-trace.size())))>0) trace.write(buf,0,n);
                                // Native tombstones may be binary protobuf. Preserve only textual traces.
                                byte[] bytes=trace.toByteArray(); boolean binary=false;
                                for(byte b:bytes) if(b==0) {binary=true;break;}
                                if(!binary) out.append(new String(bytes,StandardCharsets.UTF_8));
                            }
                        }
                    }
                }
            } catch(Exception e) {out.append("System nie udostępnił pełnych szczegółów zakończenia.\n");}
        }
        return out.toString();
    }
}
