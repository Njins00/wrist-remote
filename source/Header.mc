import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// remote header: gear, heart, accent dot + room name. long names scroll twice.
// the name is only drawn here, never sent or logged

// what hit() says
enum {
    TOP_NONE,
    TOP_GEAR,
    TOP_HEART,
    TOP_NAME
}

// mockup px
const TOP_GEAR_X = 20;
const TOP_HEART_X = 264;
const TOP_BTN_Y = 8;
const TOP_BTN = 36;
const TOP_BTN_R = 12;
const TOP_NAME_X = 75;    // name window 75..245
const TOP_NAME_W = 170;
const TOP_NAME_Y = 26;
const TOP_DOT = 8;
const TOP_DOT_GAP = 6;
const TOP_LOOP_GAP = 40;  // space before the name comes round again
const TOP_STEP = 5;       // px per tick
const TOP_TICK_MS = 100;  // ~10 fps, only while scrolling
const TOP_PASSES = 2;

const COL_ICON = 0xA7B0B5;

class Header {
    hidden var name as String;
    hidden var dirty as Boolean = true; // re-measure on next draw
    hidden var scrolls as Boolean = false; // name too wide for the window
    // screen px, worked out in measure()
    hidden var textW as Number = 0;
    hidden var stepPx as Number = 1;
    hidden var loopPx as Number = 1;
    // marquee
    hidden var offset as Number = 0;
    hidden var passes as Number = 0;
    hidden var running as Boolean = false;
    hidden var paused as Boolean = false;
    hidden var timer as Timer.Timer;

    function initialize() {
        name = roomName().toUpper();
        timer = new Timer.Timer();
    }

    // settings changed: new name, measure again, no replay
    function refresh() as Void {
        stop();
        name = roomName().toUpper();
        dirty = true;
    }

    function measure(dc as Graphics.Dc, v as MainView) as Void {
        textW = dc.getTextWidthInPixels(name, Graphics.FONT_XTINY);
        var room = v.sx(TOP_NAME_X + TOP_NAME_W) - v.sx(TOP_NAME_X + TOP_DOT + TOP_DOT_GAP);
        scrolls = textW > room;
        stepPx = v.sx(TOP_STEP);
        if (stepPx < 1) { stepPx = 1; }
        loopPx = textW + v.sx(TOP_LOOP_GAP);
        dirty = false;
    }

    // start from the beginning. short names never start the timer
    function play() as Void {
        if (dirty || !scrolls) {
            return;
        }
        timer.stop();
        offset = 0;
        passes = 0;
        running = true;
        paused = false;
        timer.start(method(:tick), TOP_TICK_MS, false);
    }

    // back to the start of the name, timer off
    function stop() as Void {
        timer.stop();
        running = false;
        paused = false;
        offset = 0;
        passes = 0;
    }

    // while a key is being sent, so we never run 4 timers at once
    function pause() as Void {
        if (running && !paused) {
            timer.stop();
            paused = true;
        }
    }

    function resume() as Void {
        if (running && paused) {
            paused = false;
            timer.start(method(:tick), TOP_TICK_MS, false);
        }
    }

    // one-shot, re-arms itself only while there's more to scroll
    function tick() as Void {
        if (!running || paused) {
            return;
        }
        offset += stepPx;
        if (offset >= loopPx) {
            offset -= loopPx;
            passes++;
            if (passes >= TOP_PASSES) {
                stop(); // ends on the start of the name
                WatchUi.requestUpdate();
                return;
            }
        }
        timer.start(method(:tick), TOP_TICK_MS, false);
        WatchUi.requestUpdate();
    }

    // mx,my in mockup px. generous areas, all above the Up arm's tap area
    function hit(mx as Number, my as Number) as Number {
        if (my < 56 && mx < 80) {
            return TOP_GEAR;
        }
        if (my < 56 && mx >= 240) {
            return TOP_HEART;
        }
        if (my < 52 && mx >= 80 && mx < 240) {
            return TOP_NAME;
        }
        return TOP_NONE;
    }

    function draw(dc as Graphics.Dc, v as MainView, dim as Boolean) as Void {
        if (dirty) {
            measure(dc, v);
        }
        var btn = dim ? COL_BTN_DIM : COL_BTN;
        var ink = dim ? COL_TEXT_DIM : COL_ICON;

        drawGear(dc, v, btn, ink);
        drawHeart(dc, v, btn, ink);

        // dot + name
        var cy = v.sy(TOP_NAME_Y);
        var dot = v.rs(TOP_DOT);
        var gap = v.sx(TOP_DOT_GAP);
        var left;
        if (scrolls) {
            left = v.sx(TOP_NAME_X); // dot pinned, text scrolls in the rest
        } else {
            left = v.sx(160) - (dot + gap + textW) / 2;
        }
        dc.setColor(dim ? COL_ACCENT_DIM : COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(left + dot / 2, cy, dot / 2);

        var tx = left + dot + gap;
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        if (scrolls) {
            var right = v.sx(TOP_NAME_X + TOP_NAME_W);
            dc.setClip(tx, 0, right - tx, v.sy(52));
            dc.drawText(tx - offset, cy, Graphics.FONT_XTINY, name, just);
            if (running) {
                // second copy so the loop has no hole
                dc.drawText(tx - offset + loopPx, cy, Graphics.FONT_XTINY, name, just);
            }
            dc.clearClip();
        } else {
            dc.drawText(tx, cy, Graphics.FONT_XTINY, name, just);
        }
    }

    hidden function button(dc as Graphics.Dc, v as MainView, mx as Number, btn as Number) as Array<Number> {
        var x = v.sx(mx);
        var y = v.sy(TOP_BTN_Y);
        var w = v.sx(mx + TOP_BTN) - x;
        var h = v.sy(TOP_BTN_Y + TOP_BTN) - y;
        dc.setColor(btn, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, v.rs(TOP_BTN_R));
        return [x + w / 2, y + h / 2];
    }

    // 4 thick bars make 8 teeth, a disc on top, a hole in the middle
    hidden function drawGear(dc as Graphics.Dc, v as MainView, btn as Number, ink as Number) as Void {
        var c = button(dc, v, TOP_GEAR_X, btn);
        var cx = c[0];
        var cy = c[1];
        var a = v.rs(11);
        var d = v.rs(8);
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(v.rs(4));
        dc.drawLine(cx - a, cy, cx + a, cy);
        dc.drawLine(cx, cy - a, cx, cy + a);
        dc.drawLine(cx - d, cy - d, cx + d, cy + d);
        dc.drawLine(cx - d, cy + d, cx + d, cy - d);
        dc.setPenWidth(1);
        dc.fillCircle(cx, cy, v.rs(7));
        dc.setColor(btn, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, v.rs(3));
    }

    // two circles + a triangle
    hidden function drawHeart(dc as Graphics.Dc, v as MainView, btn as Number, ink as Number) as Void {
        var c = button(dc, v, TOP_HEART_X, btn);
        var cx = c[0];
        var cy = c[1];
        var r = v.rs(5);
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r, cy - v.rs(3), r);
        dc.fillCircle(cx + r, cy - v.rs(3), r);
        dc.fillPolygon([[cx - r * 2, cy - v.rs(2)], [cx + r * 2, cy - v.rs(2)], [cx, cy + v.rs(8)]]);
    }
}
