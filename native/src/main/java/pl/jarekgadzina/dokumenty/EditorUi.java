package pl.jarekgadzina.dokumenty;

import android.app.Dialog;
import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.view.Gravity;
import android.view.Window;
import android.widget.*;

/** Shared, density-aware editor controls. No dependency on the device's legacy alert theme. */
final class EditorUi {
    static final int INK = Color.rgb(28, 48, 42), GREEN = Color.rgb(29, 81, 69);
    static final int BG = Color.rgb(246, 248, 245), MUTED = Color.rgb(91, 109, 101);
    static final int SELECTED = Color.rgb(221, 237, 228);
    static int dp(Context c, int value) { return Math.round(c.getResources().getDisplayMetrics().density * value); }
    static GradientDrawable shape(Context c, int color, int radius) {
        GradientDrawable d = new GradientDrawable(); d.setColor(color); d.setCornerRadius(dp(c, radius)); return d;
    }
    static TextView label(Context c, String text, int size, int color) {
        TextView v = new TextView(c); v.setText(text); v.setTextSize(size); v.setTextColor(color);
        v.setFontFeatureSettings("kern"); return v;
    }
    static Button button(Context c, String text, Runnable action, boolean primary) {
        Button b = new Button(c); b.setText(text); b.setTextSize(14); b.setAllCaps(false);
        b.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        b.setMinWidth(dp(c,48)); b.setMinimumWidth(dp(c,48)); b.setMinHeight(dp(c, 48)); b.setMinimumHeight(dp(c, 48));
        b.setPadding(dp(c, 14), 0, dp(c, 14), 0); b.setFocusable(false); b.setStateListAnimator(null);
        style(b, primary, false); b.setOnClickListener(v -> action.run());
        return b;
    }
    static void style(Button b, boolean primary, boolean selected) {
        Context c = b.getContext();
        int fill = primary ? GREEN : selected ? SELECTED : Color.WHITE;
        int text = primary ? Color.WHITE : INK;
        b.setTextColor(new ColorStateList(new int[][]{new int[]{-android.R.attr.state_enabled},new int[]{}}, new int[]{0x66708076,text}));
        b.setBackground(new RippleDrawable(ColorStateList.valueOf(0x22307559), shape(c, fill, 14), null));
        b.setSelected(selected);
    }
    static void field(EditText v) {
        Context c = v.getContext(); v.setTextColor(INK); v.setHintTextColor(MUTED); v.setTextSize(15);
        v.setBackground(shape(c, Color.WHITE, 12));
        v.setPadding(dp(c, 12), dp(c, 6), dp(c, 12), dp(c, 6)); v.setMinHeight(dp(c, 48));
    }
    static final class Sheet {
        final Dialog dialog;
        final LinearLayout body;
        Sheet(Context c, String title, String description) {
            dialog = new Dialog(c); dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
            body = new LinearLayout(c); body.setOrientation(LinearLayout.VERTICAL);
            body.setPadding(dp(c,24),dp(c,24),dp(c,24),dp(c,20)); body.setBackground(shape(c,BG,24));
            TextView heading = label(c,title,22,INK); heading.setTypeface(Typeface.create("sans-serif-medium",0));
            body.addView(heading);
            if (description != null) {
                TextView copy = label(c,description,15,MUTED); copy.setPadding(0,dp(c,12),0,dp(c,16));
                body.addView(copy);
            }
            ScrollView scroll = new ScrollView(c); scroll.addView(body);
            scroll.setBackground(shape(c,BG,24)); scroll.setClipToOutline(true);
            dialog.setContentView(scroll);
        }
        void action(String label, boolean primary, Runnable action) {
            Button b = button(body.getContext(),label,() -> {dialog.dismiss(); action.run();},primary);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1,dp(body.getContext(),48));
            lp.topMargin = dp(body.getContext(),8); body.addView(b,lp);
        }
        void show() {
            dialog.show();
            Window w = dialog.getWindow(); w.setBackgroundDrawableResource(android.R.color.transparent);
            int available = body.getResources().getDisplayMetrics().widthPixels-dp(body.getContext(),32);
            int width=Math.min(available,dp(body.getContext(),420));
            body.measure(android.view.View.MeasureSpec.makeMeasureSpec(width,android.view.View.MeasureSpec.EXACTLY),
                android.view.View.MeasureSpec.makeMeasureSpec(0,android.view.View.MeasureSpec.UNSPECIFIED));
            int height=Math.min(body.getMeasuredHeight(),body.getResources().getDisplayMetrics().heightPixels-dp(body.getContext(),64));
            w.setLayout(width,height); w.setGravity(Gravity.CENTER);
            w.setDimAmount(0.35f);
        }
    }
}
