import android.os.SystemClock;
import android.view.InputEvent;
import android.view.InputDevice;
import android.view.MotionEvent;
import java.lang.reflect.Method;

public class ImageTouch {
    static Object manager;
    static Method inject;
    static long down;
    static void send(int action, float x1, float y1, float x2, float y2, int count) throws Exception {
        MotionEvent.PointerProperties[] properties = new MotionEvent.PointerProperties[count];
        MotionEvent.PointerCoords[] coords = new MotionEvent.PointerCoords[count];
        for (int i = 0; i < count; i++) {
            properties[i] = new MotionEvent.PointerProperties(); properties[i].id = i;
            properties[i].toolType = MotionEvent.TOOL_TYPE_FINGER;
            coords[i] = new MotionEvent.PointerCoords(); coords[i].x = i == 0 ? x1 : x2;
            coords[i].y = i == 0 ? y1 : y2; coords[i].pressure = 1; coords[i].size = 1;
        }
        MotionEvent e = MotionEvent.obtain(down, SystemClock.uptimeMillis(), action, count, properties, coords,
            0, 0, 1, 1, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0);
        inject.invoke(manager, e, 2); e.recycle();
    }
    public static void main(String[] args) throws Exception {
        Class<?> cls = Class.forName("android.hardware.input.InputManagerGlobal");
        manager = cls.getMethod("getInstance").invoke(null);
        inject = cls.getMethod("injectInputEvent", InputEvent.class, int.class);
        float cx = Float.parseFloat(args[1]), cy = Float.parseFloat(args[2]);
        if (args[0].equals("double")) {
            for (int n = 0; n < 2; n++) { down = SystemClock.uptimeMillis(); send(0,cx,cy,0,0,1); SystemClock.sleep(50); send(1,cx,cy,0,0,1); SystemClock.sleep(75); }
            return;
        }
        float start = Float.parseFloat(args[3]), end = Float.parseFloat(args[4]);
        down = SystemClock.uptimeMillis(); send(0,cx-start,cy,0,0,1);
        send(5 | (1 << 8),cx-start,cy,cx+start,cy,2);
        for (int i = 0; i <= 30; i++) { float span = start + (end-start)*i/30; send(2,cx-span,cy,cx+span,cy,2); SystemClock.sleep(16); }
        send(6 | (1 << 8),cx-end,cy,cx+end,cy,2); send(1,cx-end,cy,0,0,1);
    }
}
