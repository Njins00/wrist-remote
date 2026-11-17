import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// main remote screen. numbers are mockup px (320x360), scaled to the real screen.
// round screens use their own tables from a 416x416 mockup instead

const MOCK_W = 320;
const MOCK_H = 360;
const SLACK = 4; // extra px around each button for fat fingers

const FLASH_MS = 150; // pressed look after a send

const COL_BG = 0x000000;
const COL_BTN = 0x1C1F22;
const COL_TEXT = 0xF2F4F5;
// blue is in the 64-colour mip palette, so every watch shows the same one
const COL_ACCENT = 0x0055FF;
const COL_BTN_PRESSED = 0x3A3F44;
const COL_ACCENT_PRESSED = 0x55AAFF;
// remote behind the pop-up. solid colours, no transparency
const COL_BTN_DIM = 0x0E0F11;
const COL_TEXT_DIM = 0x5A5C5D;
const COL_ACCENT_DIM = 0x000055;

// volume off. OK first so it wins where its slack touches an arm
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

// volume on: smaller d-pad on the left, rocker on the right (+, mute, -).
// bottom row same as volume off
const VOL_KEYS = [KEY_SELECT, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_BACK, KEY_HOME, KEY_PLAY, KEY_VOL_UP, KEY_MUTE, KEY_VOL_DOWN];
const VOL_RECTS = [
    [85, 133, 76, 76, 38],
    [90, 70, 66, 59, 19],
    [90, 213, 66, 59, 19],
    [22, 138, 59, 66, 19],
    [165, 138, 59, 66, 19],
    [22, 292, 85, 54, 16],
    [117, 292, 86, 54, 16],
    [213, 292, 85, 54, 16],
    [238, 70, 60, 67, 30],  // + end of the rocker
    [238, 137, 60, 68, 30], // mute, the middle
    [238, 205, 60, 67, 30]  // - end
];
// the whole rocker pill, drawn under its three zones
const ROCKER = [238, 70, 60, 202, 30];

// round: 416 circle scaled by the short side and centred. same cell order
const RND_MOCK = 416;
const RND_CELL_RECTS = [
    [169, 151, 78, 78, 39],
    [173, 84, 70, 62, 20],
    [173, 234, 70, 62, 20],
    [102, 155, 62, 70, 20],
    [252, 155, 62, 70, 20],
    [102, 306, 62, 52, 18],
    [177, 306, 62, 52, 18],
    [252, 306, 62, 52, 18]
];
// volume on: d-pad box 196 at x 77, 12 px gap, rocker at x 285
const RND_VOL_RECTS = [
    [139, 146, 72, 72, 36],
    [143, 84, 64, 57, 18],
    [143, 223, 64, 57, 18],
    [77, 150, 57, 64, 18],
    [216, 150, 57, 64, 18],
    [102, 290, 62, 52, 18],
    [177, 290, 62, 52, 18],
    [252, 290, 62, 52, 18],
    [285, 84, 54, 65, 27],  // +
    [285, 149, 54, 66, 27], // mute
    [285, 215, 54, 65, 27]  // -
];
const RND_ROCKER = [285, 84, 54, 196, 27];

class MainView extends WatchUi.View {
    var roku as RokuConnector;
    var flashCell as Number = -1; // cell drawn pressed, -1 = none
    // layout table in use, swapped by the volume setting
    hidden var vol as Boolean = false;
    hidden var keys as Array<Number> = CELL_KEYS;
    hidden var rects as Array<Array<Number>> = CELL_RECTS;
    hidden var rocker as Array<Number> = ROCKER;
    hidden var round as Boolean = false;
    var popup as Popup or Null = null;
    var flashTimer as Timer.Timer;
    var header as Header;
    hidden var played as Boolean = false;  // name marquee only plays on the first show
    hidden var sending as Boolean = false; // a key is in flight, marquee paused
    // screen size, set in onLayout/onUpdate for the scale helpers
    hidden var sw as Number = MOCK_W;
    hidden var sh as Number = MOCK_H;
    // round only: short side and the offsets that centre the circle
    hidden var sm as Number = RND_MOCK;
    hidden var ox as Number = 0;
    hidden var oy as Number = 0;
    // which page is up. new view = page 1, settings and back keep it
    hidden var pg as Number = 1;
    // page 2 buttons in screen px (Page2.mc), worked out in onLayout
    hidden var p2 as Array<Array<Number>> = [] as Array<Array<Number>>;
    // power button on (hidden switch in settings), and page 2's keys to match
    hidden var power as Boolean = false;
    hidden var keys2 as Array<Number> = P2_KEYS;
    // when the last power send started (System.getTimer), -1 = not blocked.
    // goes by the clock, the flash timer only wakes us up at the end
    hidden var blockAt as Number = -1;

    function initialize(r as RokuConnector) {
        View.initialize();
        roku = r;
        flashTimer = new Timer.Timer();
        round = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        header = new Header(round);
        loadMode();
    }

    // only a real true turns the rocker on
    hidden function loadMode() as Void {
        var v = Application.Properties.getValue("volumeButtons");
        vol = false;
        if (v instanceof Boolean) {
            vol = v;
        }
        keys = vol ? VOL_KEYS : CELL_KEYS;
        if (round) {
            rects = vol ? RND_VOL_RECTS : RND_CELL_RECTS;
            rocker = RND_ROCKER;
        } else {
            rects = vol ? VOL_RECTS : CELL_RECTS;
            rocker = ROCKER;
        }
        // page 2 with or without power. before the first layout onLayout does it
        power = powerButtonOn();
        keys2 = power ? P2_KEYS_PWR : P2_KEYS;
        if (p2.size() > 0) {
            layout2();
        }
    }

    // runs before the first onShow, so the header knows if the name scrolls
    function onLayout(dc as Graphics.Dc) as Void {
        setSize(dc);
        header.measure(dc, self);
        layout2();
    }

    // page 2 to screen px. round has its own floors, square just scales
    hidden function layout2() as Void {
        if (round) {
            p2 = p2Round(sm, power);
            for (var i = 0; i < p2.size(); i++) {
                p2[i][0] += ox;
                p2[i][1] += oy;
            }
            return;
        }
        var t = power ? P2_RECTS_PWR : P2_RECTS;
        p2 = [] as Array<Array<Number>>;
        for (var i = 0; i < t.size(); i++) {
            var c = t[i];
            var x = sx(c[0]);
            var y = sy(c[1]);
            p2.add([x, y, sx(c[0] + c[2]) - x, sy(c[1] + c[3]) - y, rs(c[4])]);
        }
    }

    // swipes and the page buttons. always a set page, never a toggle, so a
    // doubled event can't flip it back. nothing while a pop-up is up
    function goPage(n as Number) as Void {
        poke();
        if (n == pg || popup != null) {
            return;
        }
        flashTimer.stop();
        flashCell = -1; // the index was for the other page
        pg = n;
        armBlock();
        WatchUi.requestUpdate();
    }

    // ms left on the power block, 0 = free. clears it once it's run out
    hidden function blockLeft() as Number {
        if (blockAt < 0) {
            return 0;
        }
        var left = POWER_BLOCK_MS - (System.getTimer() - blockAt);
        if (left <= 0) {
            blockAt = -1;
            return 0;
        }
        return left;
    }

    // block still on: borrow the flash timer to redraw when it ends. called
    // wherever that timer got stopped, so power can't stay grey
    hidden function armBlock() as Void {
        var left = blockLeft();
        if (left > 0) {
            flashTimer.stop();
            flashTimer.start(method(:endFlash), left < TIMER_MIN_MS ? TIMER_MIN_MS : left, false);
        }
    }

    function page() as Number {
        return pg;
    }

    // page 2 cell under x,y (screen px). play and power are circles. -1 if none
    function cellAt2(x as Number, y as Number) as Number {
        var s = rs(SLACK);
        for (var i = 0; i < p2.size(); i++) {
            var c = p2[i];
            if (i == 0 || keys2[i] == KEY_POWER) {
                var half = c[2] / 2;
                var dx = x - (c[0] + half);
                var dy = y - (c[1] + half);
                var r = half + s;
                if (dx * dx + dy * dy <= r * r) {
                    return i;
                }
            } else if (x >= c[0] - s && x < c[0] + c[2] + s &&
                y >= c[1] - s && y < c[1] + c[3] + s) {
                return i;
            }
        }
        return -1;
    }

    // also runs when we come back from settings, so the rocker is right away
    function onShow() as Void {
        poke();
        flashCell = -1;
        loadMode();
        armBlock();
        if (!played) {
            played = true;
            header.play();
        }
    }

    // idle lives in the app, it keeps counting on the help page
    function onHide() as Void {
        flashTimer.stop();
        flashCell = -1;
        header.stop();
    }

    // settings changed: new room name and maybe the other layout, no replay
    function refreshSettings() as Void {
        flashTimer.stop();
        flashCell = -1; // the index was for the old table
        loadMode();
        armBlock();
        header.refresh();
        WatchUi.requestUpdate();
    }

    // any tap resets the app's idle clock
    function poke() as Void {
        getRemoteApp().poke();
    }

    // which cell is under mx,my (mockup px). -1 if none
    function cellAt(mx as Number, my as Number) as Number {
        // OK circle, from its box in row 0
        var ok = rects[0];
        var half = ok[2] / 2;
        var dx = mx - (ok[0] + half);
        var dy = my - (ok[1] + half);
        var r = half + SLACK;
        if (dx * dx + dy * dy <= r * r) {
            return 0;
        }
        // exact hit first so the rocker zones (they touch) split cleanly, then slack
        for (var pass = 0; pass < 2; pass++) {
            var s = pass * SLACK;
            for (var i = 1; i < rects.size(); i++) {
                var c = rects[i];
                if (mx >= c[0] - s && mx < c[0] + c[2] + s &&
                    my >= c[1] - s && my < c[1] + c[3] + s) {
                    return i;
                }
            }
        }
        return -1; // header, d-pad corners, gaps
    }

    function tap(x as Number, y as Number) as Void {
        poke();
        var mx = x * MOCK_W / System.getDeviceSettings().screenWidth;
        var my = y * MOCK_H / System.getDeviceSettings().screenHeight;
        // pop-up open (maps the screen px itself): only its two buttons do anything, no keys get sent
        var p = popup;
        if (p != null) {
            var hit = p.buttonAt(x, y);
            if (hit == POP_HIT_OK) {
                closePopup();
            } else if (hit == POP_HIT_FIX) {
                // close first so Done/back lands on a clean remote
                var kind = p.getKind();
                closePopup();
                var help = new HelpView(kind);
                WatchUi.pushView(help, new HelpDelegate(help), WatchUi.SLIDE_IMMEDIATE);
            }
            return;
        }
        // round: back to 416 px for the header and cells
        if (round) {
            mx = (x - ox) * RND_MOCK / sm;
            my = (y - oy) * RND_MOCK / sm;
        }
        // header: gear opens settings, name replays, the right slot does
        // nothing. never reaches the send code below
        var top = header.hit(mx, my);
        if (top != TOP_NONE) {
            if (top == TOP_GEAR) {
                getRemoteApp().open(PAGE_SETTINGS);
            } else if (top == TOP_NAME) {
                header.play();
                if (sending) {
                    header.pause();
                }
            }
            return;
        }
        var ks = pg == 2 ? keys2 : keys;
        var cell = pg == 2 ? cellAt2(x, y) : cellAt(mx, my);
        if (cell < 0 || ks[cell] < 0) {
            return;
        }
        // power blocked: nothing at all, not even ending another flash
        var isPower = ks[cell] == KEY_POWER;
        if (isPower && blockLeft() > 0) {
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
        var res = roku.send(ks[cell], method(:onResult));
        if (res == SEND_BUSY) {
            sending = was; // the earlier request is still going
        } else if (res != SEND_STARTED) {
            sending = false;
        }
        if (res == SEND_BAD_IP) {
            showError(POP_BAD_IP);
        } else if (res == SEND_NO_PHONE) {
            showError(POP_NO_PHONE);
        } else if (res == SEND_STARTED && isPower) {
            // 2 s block from the tap, whatever the reply. the grey check is
            // the feedback, no flash. busy/bad ip/no phone never get here
            blockAt = System.getTimer();
            armBlock();
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
            getRemoteApp().sent(); // tip counter, stays on the watch
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

    // end of a flash or of the power block. a flash during the block
    // hands the timer back to the block
    function endFlash() as Void {
        flashCell = -1;
        armBlock();
        WatchUi.requestUpdate();
    }

    function showError(kind as Number) as Void {
        flashTimer.stop();
        flashCell = -1;
        header.stop();
        popup = new Popup(kind, true);
    }

    function popupOpen() as Boolean {
        return popup != null;
    }

    function closePopup() as Void {
        popup = null;
        armBlock(); // showError stopped the timer
        WatchUi.requestUpdate();
    }

    // redraws on tap, flash end, error, pop-up close, and marquee ticks while a long name scrolls
    function onUpdate(dc as Graphics.Dc) as Void {
        setSize(dc);
        dc.setColor(COL_BG, COL_BG);
        dc.clear();
        var p = popup;
        var dim = p != null;
        var btn = dim ? COL_BTN_DIM : COL_BTN;
        var ink = dim ? COL_TEXT_DIM : COL_TEXT;
        var accent = dim ? COL_ACCENT_DIM : COL_ACCENT;
        if (flashCell == 0) {
            accent = COL_ACCENT_PRESSED; // OK or play, both are cell 0
        }

        if (pg == 2) {
            drawPage2(dc, btn, ink, accent, dim);
        } else {
            drawPage1(dc, btn, ink, accent);
        }
        drawDots(dc, dim);

        header.draw(dc, self, dim);

        if (p != null) {
            p.draw(dc);
        }
    }

    // d-pad, bottom row, rocker if it's on
    hidden function drawPage1(dc as Graphics.Dc, btn as Number, ink as Number, accent as Number) as Void {
        // OK: accent circle
        var ok = rects[0];
        var half = ok[2] / 2;
        var okX = sx(ok[0] + half);
        var okY = sy(ok[1] + half);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(okX, okY, rs(half));
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(okX, okY, Graphics.FONT_SMALL, "OK",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // rocker pill goes under its three zones
        if (vol) {
            dc.setColor(btn, Graphics.COLOR_TRANSPARENT);
            pill(dc);
        }

        // arms + bottom row (+ rocker ends)
        for (var i = 1; i < rects.size(); i++) {
            var c = rects[i];
            var x = sx(c[0]);
            var y = sy(c[1]);
            var bw = sx(c[0] + c[2]) - x;
            var bh = sy(c[1] + c[3]) - y;
            var key = keys[i];
            if (key == KEY_VOL_UP || key == KEY_VOL_DOWN || key == KEY_MUTE) {
                // pill's already drawn. pressed: light up just this zone
                if (i == flashCell) {
                    dc.setColor(COL_BTN_PRESSED, Graphics.COLOR_TRANSPARENT);
                    dc.setClip(x, y, bw, bh);
                    pill(dc);
                    dc.clearClip();
                }
            } else {
                dc.setColor(i == flashCell ? COL_BTN_PRESSED : btn, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x, y, bw, bh, rs(c[4]));
            }
            dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
            drawIcon(dc, key, x + bw / 2, y + bh / 2);
        }
    }

    // two dots on the right, top one = page 1. dim behind a pop-up
    hidden function drawDots(dc as Graphics.Dc, dim as Boolean) as Void {
        var d = round ? DOTS_RND : DOTS_SQ;
        var r = rs(d[3]);
        if (round && r < DOT_MIN_R) {
            r = DOT_MIN_R;
        }
        var on = dim ? COL_TEXT_DIM : COL_TEXT;
        var off = dim ? COL_DOT_OFF_DIM : COL_DOT_OFF;
        var x = sx(d[0]);
        dc.setColor(pg == 1 ? on : off, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, sy(d[1]), r);
        dc.setColor(pg == 2 ? on : off, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, sy(d[2]), r);
    }

    // play circle, rev/fwd, replay/options. already in screen px
    hidden function drawPage2(dc as Graphics.Dc, btn as Number, ink as Number, accent as Number,
            dim as Boolean) as Void {
        var q = p2[1][3]; // side button height, icons scale with it
        for (var i = 0; i < p2.size(); i++) {
            var c = p2[i];
            var cx = c[0] + c[2] / 2;
            var cy = c[1] + c[3] / 2;
            var key = keys2[i];
            var icon = ink;
            if (i == 0) {
                dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx, cy, c[2] / 2);
            } else if (key == KEY_POWER) {
                // red circle, no label. blocked = grey with a check instead
                // of the power sign, so it reads without colour too
                var fill = dim ? COL_POWER_DIM : COL_POWER;
                if (blockLeft() > 0) {
                    fill = dim ? COL_BTN_DIM : COL_BLOCK;
                    icon = dim ? COL_TEXT_DIM : COL_BLOCK_ICON;
                    key = KEY_BLOCKED;
                }
                dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx, cy, c[2] / 2);
            } else {
                dc.setColor(i == flashCell ? COL_BTN_PRESSED : btn, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(c[0], c[1], c[2], c[3], c[4]);
            }
            dc.setColor(icon, Graphics.COLOR_TRANSPARENT);
            p2Icon(dc, key, cx, cy, q);
        }
    }

    hidden function setSize(dc as Graphics.Dc) as Void {
        sw = dc.getWidth();
        sh = dc.getHeight();
        if (round) {
            sm = sw < sh ? sw : sh;
            ox = (sw - sm) / 2;
            oy = (sh - sm) / 2;
        }
    }

    // mockup px -> screen px
    function sx(v as Number) as Number {
        if (round) {
            return ox + v * sm / RND_MOCK;
        }
        return v * sw / MOCK_W;
    }

    function sy(v as Number) as Number {
        if (round) {
            return oy + v * sm / RND_MOCK;
        }
        return v * sh / MOCK_H;
    }

    // radii and pens use the smaller scale so circles stay round
    function rs(v as Number) as Number {
        if (round) {
            var q = v * sm / RND_MOCK;
            return q < 1 ? 1 : q;
        }
        var a = sx(v);
        var b = sy(v);
        var r = a < b ? a : b;
        return r < 1 ? 1 : r;
    }

    // icons are drawn, no text. sizes in mockup px around the button centre.
    // arrow and chevrons are shared with the help pages (HelpView.mc)
    function drawIcon(dc as Graphics.Dc, key as Number, cx as Number, cy as Number) as Void {
        if (key == KEY_UP) {
            drawChevron(dc, cx, cy, 0, -1);
        } else if (key == KEY_DOWN) {
            drawChevron(dc, cx, cy, 0, 1);
        } else if (key == KEY_LEFT) {
            drawChevron(dc, cx, cy, -1, 0);
        } else if (key == KEY_RIGHT) {
            drawChevron(dc, cx, cy, 1, 0);
        } else if (key == KEY_BACK) {
            drawBackArrow(dc, cx, cy);
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
        } else if (key == KEY_VOL_UP || key == KEY_VOL_DOWN) {
            // plus or minus
            var a = rs(10);
            dc.setPenWidth(rs(4));
            dc.drawLine(cx - a, cy, cx + a, cy);
            if (key == KEY_VOL_UP) {
                dc.drawLine(cx, cy - a, cx, cy + a);
            }
        } else if (key == KEY_MUTE) {
            // speaker with an X next to it
            speaker(dc, cx - rs(6), cy);
            var a = rs(5);
            var xc = cx + rs(10);
            dc.setPenWidth(rs(3));
            dc.drawLine(xc - a, cy - a, xc + a, cy + a);
            dc.drawLine(xc - a, cy + a, xc + a, cy - a);
        }
        dc.setPenWidth(1);
    }

    // small box + cone, about 14 px wide around cx. uses the current colour
    function speaker(dc as Graphics.Dc, cx as Number, cy as Number) as Void {
        var l = cx - rs(7);
        var m = cx - rs(2);
        var r = cx + rs(7);
        dc.fillRectangle(l, cy - rs(4), m - l, rs(8));
        dc.fillPolygon([[m, cy - rs(4)], [r, cy - rs(10)], [r, cy + rs(10)], [m, cy + rs(4)]]);
    }

    // the whole rocker pill in the current colour
    function pill(dc as Graphics.Dc) as Void {
        var x = sx(rocker[0]);
        var y = sy(rocker[1]);
        dc.fillRoundedRectangle(x, y, sx(rocker[0] + rocker[2]) - x,
            sy(rocker[1] + rocker[3]) - y, rs(rocker[4]));
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

    // back closes the pop-up if one is open, then page 2 -> page 1,
    // otherwise default (exit)
    function onBack() as Boolean {
        if (view.popupOpen()) {
            view.closePopup();
            return true;
        }
        if (view.page() == 2) {
            view.goPage(1);
            return true;
        }
        return false;
    }

    // up = page 2, down = page 1. left/right still get eaten so a sloppy
    // tap can't close the remote. returning true means no page event too
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            view.goPage(2);
        } else if (dir == WatchUi.SWIPE_DOWN) {
            view.goPage(1);
        } else {
            view.poke();
        }
        return true;
    }

    // up/down buttons (fenix 7 and co), same as the swipes
    function onNextPage() as Boolean {
        view.goPage(2);
        return true;
    }

    function onPreviousPage() as Boolean {
        view.goPage(1);
        return true;
    }
}
