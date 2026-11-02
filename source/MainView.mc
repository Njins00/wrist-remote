import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// main remote screen. numbers are mockup px (320x360), scaled to the real screen

const IDLE_MS = 300000; // 5 min with no taps, then back to the watch face

const MOCK_W = 320;
const MOCK_H = 360;
const STATUS_Y = 27; // middle of the empty header (0-54), 4.4 fills it
const SLACK = 4;     // extra px around each button for fat fingers

const COL_BG = 0x000000;
const COL_BTN = 0x1C1F22;
const COL_TEXT = 0xF2F4F5;
const COL_ACCENT = 0x6C2BD9;
const COL_TEXT2 = 0xA7B0B5;

// OK first so it wins where its slack touches an arm
const CELL_KEYS = [KEY_SELECT, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_BACK, KEY_HOME, KEY_PLAY];
const CELL_LABELS = ["OK", "Up", "Down", "Left", "Right", "Back", "Home", "Play"];
// x, y, w, h, corner radius. OK is its circle's box (centre 160,170, r 39)
const CELL_RECTS = [
    [121, 131, 78, 78, 39],
    [125, 64, 70, 62, 20],
    [125, 214, 70, 62, 20],
    [54, 135, 62, 70, 20],
    [204, 135, 62, 70, 20],
    [22, 294, 85, 50, 16],
    [117, 294, 86, 50, 16],
    [213, 294, 85, 50, 16]
];

class MainView extends WatchUi.View {
    var roku as RokuConnector;
    var status as String = "Tap a key";
    var lastLabel as String = "";
    var sentAt as Number = 0;
    var idle as Timer.Timer;
    // screen size, set in onUpdate for the scale helpers
    hidden var sw as Number = MOCK_W;
    hidden var sh as Number = MOCK_H;

    function initialize(r as RokuConnector) {
        View.initialize();
        roku = r;
        idle = new Timer.Timer();
    }

    function onShow() as Void {
        poke();
    }

    function onHide() as Void {
        idle.stop();
    }

    // any tap resets the idle clock
    function poke() as Void {
        idle.stop();
        idle.start(method(:bail), IDLE_MS, false);
    }

    function bail() as Void {
        System.exit();
    }

    // which cell is under x,y. -1 if none. works in mockup px
    function cellAt(x as Number, y as Number) as Number {
        var mx = x * MOCK_W / System.getDeviceSettings().screenWidth;
        var my = y * MOCK_H / System.getDeviceSettings().screenHeight;
        // OK circle
        var dx = mx - 160;
        var dy = my - 170;
        var r = 39 + SLACK;
        if (dx * dx + dy * dy <= r * r) {
            return 0;
        }
        for (var i = 1; i < CELL_RECTS.size(); i++) {
            var c = CELL_RECTS[i];
            if (mx >= c[0] - SLACK && mx < c[0] + c[2] + SLACK &&
                my >= c[1] - SLACK && my < c[1] + c[3] + SLACK) {
                return i;
            }
        }
        return -1; // header, d-pad corners, gaps
    }

    function tap(x as Number, y as Number) as Void {
        poke();
        var cell = cellAt(x, y);
        if (cell < 0 || CELL_KEYS[cell] < 0) {
            return;
        }
        var label = CELL_LABELS[cell];
        // set "Sending" first, onResult can fire inside send() and must win
        var prevStatus = status;
        var prevLabel = lastLabel;
        var prevAt = sentAt;
        lastLabel = label;
        sentAt = System.getTimer();
        status = "Sending · " + label;
        var res = roku.send(CELL_KEYS[cell], method(:onResult));
        if (res == SEND_BAD_IP) {
            status = "Set a home IP in settings";
        } else if (res == SEND_NO_PHONE) {
            status = "Phone not connected";
        } else if (res != SEND_STARTED) {
            // busy, tap dropped. put things back for the request still in flight
            status = prevStatus;
            lastLabel = prevLabel;
            sentAt = prevAt;
        }
        WatchUi.requestUpdate();
    }

    function onResult(result as Number) as Void {
        var ms = System.getTimer() - sentAt;
        if (result == RESULT_SENT) {
            status = "Sent · " + lastLabel + "  " + ms + " ms";
        } else if (result == RESULT_NO_PHONE) {
            status = "Phone not connected";
        } else if (result == RESULT_TIMED_OUT) {
            status = "Can't reach Roku";
        } else if (result == RESULT_HTTP_BLOCKED) {
            status = "Phone blocks HTTP";
        } else {
            status = "Failed";
        }
        WatchUi.requestUpdate();
    }

    // only redraws on tap or result, nothing animates
    function onUpdate(dc as Graphics.Dc) as Void {
        sw = dc.getWidth();
        sh = dc.getHeight();
        dc.setColor(COL_BG, COL_BG);
        dc.clear();

        dc.setColor(COL_TEXT2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, sy(STATUS_Y), Graphics.FONT_XTINY, status,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // OK: accent circle
        dc.setColor(COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx(160), sy(170), rs(39));
        dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx(160), sy(170), Graphics.FONT_SMALL, "OK",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // arms + bottom row
        for (var i = 1; i < CELL_RECTS.size(); i++) {
            var c = CELL_RECTS[i];
            var x = sx(c[0]);
            var y = sy(c[1]);
            var bw = sx(c[0] + c[2]) - x;
            var bh = sy(c[1] + c[3]) - y;
            dc.setColor(COL_BTN, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, bw, bh, rs(c[4]));
            dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
            drawIcon(dc, CELL_KEYS[i], x + bw / 2, y + bh / 2);
        }
    }

    // mockup px -> screen px
    function sx(v as Number) as Number {
        return v * sw / MOCK_W;
    }

    function sy(v as Number) as Number {
        return v * sh / MOCK_H;
    }

    // radii and pens use the smaller scale so circles stay round
    function rs(v as Number) as Number {
        var a = sx(v);
        var b = sy(v);
        var r = a < b ? a : b;
        return r < 1 ? 1 : r;
    }

    // icons are drawn, no text. sizes in mockup px around the button centre
    function drawIcon(dc as Graphics.Dc, key as Number, cx as Number, cy as Number) as Void {
        if (key == KEY_UP) {
            chevron(dc, cx, cy, 0, -1);
        } else if (key == KEY_DOWN) {
            chevron(dc, cx, cy, 0, 1);
        } else if (key == KEY_LEFT) {
            chevron(dc, cx, cy, -1, 0);
        } else if (key == KEY_RIGHT) {
            chevron(dc, cx, cy, 1, 0);
        } else if (key == KEY_BACK) {
            // arrow left with a stem
            var a = rs(11);
            var t = rs(7);
            dc.setPenWidth(rs(4));
            dc.drawLine(cx - a, cy, cx + a, cy);
            dc.drawLine(cx - a, cy, cx - a + t, cy - t);
            dc.drawLine(cx - a, cy, cx - a + t, cy + t);
        } else if (key == KEY_HOME) {
            // roof + walls + floor, open under the roof
            var r = rs(12);
            var b = rs(8);
            dc.setPenWidth(rs(3));
            dc.drawLine(cx - r, cy - rs(1), cx, cy - r);
            dc.drawLine(cx, cy - r, cx + r, cy - rs(1));
            dc.drawLine(cx - b, cy - rs(4), cx - b, cy + rs(10));
            dc.drawLine(cx - b, cy + rs(10), cx + b, cy + rs(10));
            dc.drawLine(cx + b, cy + rs(10), cx + b, cy - rs(4));
        } else if (key == KEY_PLAY) {
            // triangle + two bars
            var s = rs(10);
            var b = s * 3 / 4;
            dc.fillPolygon([[cx - s, cy - b], [cx - s, cy + b], [cx, cy]]);
            dc.fillRectangle(cx + s / 4, cy - b, s / 4 + 1, b * 2);
            dc.fillRectangle(cx + s * 3 / 4, cy - b, s / 4 + 1, b * 2);
        }
        dc.setPenWidth(1);
    }

    // two thick lines pointing (dx,dy)
    function chevron(dc as Graphics.Dc, cx as Number, cy as Number, dx as Number, dy as Number) as Void {
        var d = rs(6);  // half depth
        var a = rs(12); // half width
        var tipX = cx + dx * d;
        var tipY = cy + dy * d;
        var bx = cx - dx * d;
        var by = cy - dy * d;
        dc.setPenWidth(rs(5));
        dc.drawLine(bx - dy * a, by + dx * a, tipX, tipY);
        dc.drawLine(bx + dy * a, by - dx * a, tipX, tipY);
    }
}

class MainDelegate extends WatchUi.BehaviorDelegate {
    var view as MainView;

    function initialize(v as MainView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var xy = evt.getCoordinates();
        view.tap(xy[0], xy[1]);
        return true;
    }

    // eat all swipes so a sloppy tap can't close the remote.
    // physical back button still exits through the default onBack
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        return true;
    }
}
