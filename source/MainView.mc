import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// main remote screen. numbers are mockup px (320x360), scaled to the real screen

const IDLE_MS = 300000; // 5 min with no taps, then back to the watch face

const MOCK_W = 320;
const MOCK_H = 360;
const SLACK = 4; // extra px around each button for fat fingers

const FLASH_MS = 150; // pressed look after a send

const COL_BG = 0x000000;
const COL_BTN = 0x1C1F22;
const COL_TEXT = 0xF2F4F5;
const COL_ACCENT = 0x6C2BD9;
const COL_BTN_PRESSED = 0x3A3F44;
const COL_ACCENT_PRESSED = 0x8A4DFF;
// remote behind the pop-up. solid colours, no transparency
const COL_BTN_DIM = 0x0E0F11;
const COL_TEXT_DIM = 0x5A5C5D;
const COL_ACCENT_DIM = 0x2F135F;

const OK_CX = 160;
const OK_CY = 171;
const OK_R = 42;

// OK first so it wins where its slack touches an arm
const CELL_KEYS = [KEY_SELECT, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_BACK, KEY_HOME, KEY_PLAY];
// x, y, w, h, corner radius. OK is its circle's box
const CELL_RECTS = [
    [118, 129, 84, 84, 42],
    [123, 58, 74, 66, 21],
    [123, 218, 74, 66, 21],
    [47, 134, 66, 74, 21],
    [207, 134, 66, 74, 21],
    [22, 292, 85, 54, 16],
    [117, 292, 86, 54, 16],
    [213, 292, 85, 54, 16]
];

class MainView extends WatchUi.View {
    var roku as RokuConnector;
    var flashCell as Number = -1; // cell drawn pressed, -1 = none
    var popup as Popup or Null = null;
    var idle as Timer.Timer;
    var flashTimer as Timer.Timer;
    var header as Header;
    hidden var played as Boolean = false;  // name marquee only plays on the first show
    hidden var sending as Boolean = false; // a key is in flight, marquee paused
    // screen size, set in onLayout/onUpdate for the scale helpers
    hidden var sw as Number = MOCK_W;
    hidden var sh as Number = MOCK_H;

    function initialize(r as RokuConnector) {
        View.initialize();
        roku = r;
        idle = new Timer.Timer();
        flashTimer = new Timer.Timer();
        header = new Header();
    }

    // runs before the first onShow, so the header knows if the name scrolls
    function onLayout(dc as Graphics.Dc) as Void {
        sw = dc.getWidth();
        sh = dc.getHeight();
        header.measure(dc, self);
    }

    function onShow() as Void {
        poke();
        if (!played) {
            played = true;
            header.play();
        }
    }

    // idle keeps running so it still counts on the help page. dies with the app anyway
    function onHide() as Void {
        flashTimer.stop();
        flashCell = -1;
        header.stop();
    }

    // settings changed: new room name, no replay
    function refreshHeader() as Void {
        header.refresh();
        WatchUi.requestUpdate();
    }

    // any tap resets the idle clock
    function poke() as Void {
        idle.stop();
        idle.start(method(:bail), IDLE_MS, false);
    }

    function bail() as Void {
        System.exit();
    }

    // which cell is under mx,my (mockup px). -1 if none
    function cellAt(mx as Number, my as Number) as Number {
        // OK circle
        var dx = mx - OK_CX;
        var dy = my - OK_CY;
        var r = OK_R + SLACK;
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
        var mx = x * MOCK_W / System.getDeviceSettings().screenWidth;
        var my = y * MOCK_H / System.getDeviceSettings().screenHeight;
        // pop-up open: only its two buttons do anything, no keys get sent
        var p = popup;
        if (p != null) {
            var hit = p.buttonAt(mx, my);
            if (hit == POP_HIT_OK) {
                closePopup();
            } else if (hit == POP_HIT_FIX) {
                // close first so Done/back lands on a clean remote
                var kind = p.getKind();
                closePopup();
                var help = new HelpView(kind);
                WatchUi.pushView(help, new HelpDelegate(help, self), WatchUi.SLIDE_IMMEDIATE);
            }
            return;
        }
        // header: gear and heart do nothing yet (phase 6 / 7), name replays.
        // never reaches the send code below
        var top = header.hit(mx, my);
        if (top != TOP_NONE) {
            if (top == TOP_NAME) {
                header.play();
                if (sending) {
                    header.pause();
                }
            }
            return;
        }
        var cell = cellAt(mx, my);
        if (cell < 0 || CELL_KEYS[cell] < 0) {
            return;
        }
        // new tap ends any flash still showing
        flashTimer.stop();
        flashCell = -1;
        // marquee waits while a key is in flight, so at most 3 timers run.
        // set before send(), onResult can fire inside it
        var was = sending;
        sending = true;
        header.pause();
        var res = roku.send(CELL_KEYS[cell], method(:onResult));
        if (res == SEND_BUSY) {
            sending = was; // the earlier request is still going
        } else if (res != SEND_STARTED) {
            sending = false;
        }
        if (res == SEND_BAD_IP) {
            showError(POP_BAD_IP);
        } else if (res == SEND_NO_PHONE) {
            showError(POP_NO_PHONE);
        } else if (res == SEND_STARTED && popup == null) {
            // only real sends flash. popup check: onResult can fire inside send()
            flashCell = cell;
            flashTimer.start(method(:endFlash), FLASH_MS, false);
        }
        if (!sending) {
            header.resume(); // no-op if a pop-up stopped it
        }
        // busy: tap dropped, nothing changes
        WatchUi.requestUpdate();
    }

    function onResult(result as Number) as Void {
        sending = false;
        if (result == RESULT_SENT) {
            header.resume();
            return; // the flash was the feedback
        } else if (result == RESULT_NO_PHONE) {
            showError(POP_NO_PHONE);
        } else if (result == RESULT_HTTP_BLOCKED) {
            showError(POP_HTTP);
        } else {
            showError(POP_UNREACHABLE); // timed out or failed
        }
        WatchUi.requestUpdate();
    }

    function endFlash() as Void {
        flashCell = -1;
        WatchUi.requestUpdate();
    }

    function showError(kind as Number) as Void {
        flashTimer.stop();
        flashCell = -1;
        header.stop();
        popup = new Popup(kind);
    }

    function popupOpen() as Boolean {
        return popup != null;
    }

    function closePopup() as Void {
        popup = null;
        WatchUi.requestUpdate();
    }

    // redraws on tap, flash end, error, pop-up close, and marquee ticks while a long name scrolls
    function onUpdate(dc as Graphics.Dc) as Void {
        sw = dc.getWidth();
        sh = dc.getHeight();
        dc.setColor(COL_BG, COL_BG);
        dc.clear();
        var p = popup;
        var dim = p != null;
        var btn = dim ? COL_BTN_DIM : COL_BTN;
        var ink = dim ? COL_TEXT_DIM : COL_TEXT;
        var accent = dim ? COL_ACCENT_DIM : COL_ACCENT;
        if (flashCell == 0) {
            accent = COL_ACCENT_PRESSED;
        }

        // OK: accent circle
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx(OK_CX), sy(OK_CY), rs(OK_R));
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx(OK_CX), sy(OK_CY), Graphics.FONT_SMALL, "OK",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // arms + bottom row
        for (var i = 1; i < CELL_RECTS.size(); i++) {
            var c = CELL_RECTS[i];
            var x = sx(c[0]);
            var y = sy(c[1]);
            var bw = sx(c[0] + c[2]) - x;
            var bh = sy(c[1] + c[3]) - y;
            dc.setColor(i == flashCell ? COL_BTN_PRESSED : btn, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, bw, bh, rs(c[4]));
            dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
            drawIcon(dc, CELL_KEYS[i], x + bw / 2, y + bh / 2);
        }

        header.draw(dc, self, dim);

        if (p != null) {
            p.draw(dc, self);
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

    // back closes the pop-up if one is open, otherwise default (exit)
    function onBack() as Boolean {
        if (view.popupOpen()) {
            view.closePopup();
            return true;
        }
        return false;
    }

    // eat all swipes so a sloppy tap can't close the remote
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        return true;
    }
}
