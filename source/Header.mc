import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// remote header: gear, accent dot + room name. long names scroll twice.
// the name is only drawn here, never sent or logged

// what hit() says
enum {
    TOP_NONE,
    TOP_GEAR,
    TOP_NAME
}

// mockup px per shape: gear x, right slot x (empty until the v2 switcher),
// button y, button size, button radius,
// name x, name w (dot + gap + text, 8 px clear of the buttons), name y,
// middle x, clip bottom
const TOP_SQ = [20, 264, 8, 36, 12, 64, 192, 26, 160, 52];
const TOP_RND = [97, 285, 40, 34, 12, 139, 138, 57, 208, 80];
const TOP_DOT = 8;
const TOP_DOT_GAP = 6;
const TOP_LOOP_GAP = 40;  // space before the name comes round again
const TOP_STEP = 5;       // px per tick
const TOP_TICK_MS = 100;  // ~10 fps, only while scrolling
const TOP_PASSES = 2;

const COL_ICON = 0xA7B0B5;

class Header {
    hidden var name as String;
    hidden var round as Boolean;
    hidden var lay as Array<Number>; // TOP_SQ or TOP_RND
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

    // normal case, it's narrower than all caps
    function initialize(r as Boolean) {
        round = r;
        lay = r ? TOP_RND : TOP_SQ;
        name = roomName();
        timer = new Timer.Timer();
    }

    // settings changed: new name, measure again, no replay
    function refresh() as Void {
        stop();
        name = roomName();
        dirty = true;
    }

    function measure(dc as Graphics.Dc, v as MainView) as Void {
        textW = dc.getTextWidthInPixels(name, Graphics.FONT_XTINY);
        var room = v.sx(lay[5] + lay[6]) - v.sx(lay[5] + TOP_DOT + TOP_DOT_GAP);
        scrolls = textW > room;
        // minus sx(0) so the round centring offset doesn't count
        stepPx = v.sx(TOP_STEP) - v.sx(0);
        if (stepPx < 1) { stepPx = 1; }
        loopPx = textW + v.sx(TOP_LOOP_GAP) - v.sx(0);
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
        if (round) {
            // whole band above y 80, split in the middle of the 8 px gaps.
            // the screen edge is the outer limit
            if (my >= 80) {
                return TOP_NONE;
            }
            if (mx < 135) {
                return TOP_GEAR;
            }
            // right slot is empty for now
            return mx >= 281 ? TOP_NONE : TOP_NAME;
        }
        if (my < 56 && mx < 80) {
            return TOP_GEAR;
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

        // dot + name
        var cy = v.sy(lay[7]);
        var dot = v.rs(TOP_DOT);
        var gap = v.sx(TOP_DOT_GAP);
        var left;
        if (scrolls) {
            left = v.sx(lay[5]); // dot pinned, text scrolls in the rest
        } else {
            left = v.sx(lay[8]) - (dot + gap + textW) / 2;
        }
        dc.setColor(dim ? COL_ACCENT_DIM : COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(left + dot / 2, cy, dot / 2);

        var tx = left + dot + gap;
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        if (scrolls) {
            var right = v.sx(lay[5] + lay[6]);
            dc.setClip(tx, 0, right - tx, v.sy(lay[9]));
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
        var y = v.sy(lay[2]);
        var w = v.sx(mx + lay[3]) - x;
        var h = v.sy(lay[2] + lay[3]) - y;
        dc.setColor(btn, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, v.rs(lay[4]));
        return [x + w / 2, y + h / 2];
    }

    // 4 thick bars make 8 teeth, a disc on top, a hole in the middle
    hidden function drawGear(dc as Graphics.Dc, v as MainView, btn as Number, ink as Number) as Void {
        var c = button(dc, v, lay[0], btn);
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
}
