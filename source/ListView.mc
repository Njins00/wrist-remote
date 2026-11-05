import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// shared list page: rows of title + grey line under it, thin dividers, a
// chevron on rows that open something. scrolls like the help page.
// settings and device pages are built on it (devices list in v2)

// mockup px. square 320x360, round 416 (same column as the help steps)
const LIST_X = 20;
const LIST_W = 280;
const RND_LIST_X = 68;
const RND_LIST_W = 280;
const LIST_PAD = 10;      // above the title and below the grey line
const LIST_GAP = 2;       // between the two lines
const LIST_CHEV_W = 32;   // kept free on the right of every row

// long lines scroll like the room name: same speed, twice, then stop.
// one timer, only runs while something's moving
class Marquee {
    hidden var timer as Timer.Timer;
    hidden var travel as Number = 0;
    hidden var limit as Number = 0;  // 0 = nothing to scroll
    hidden var step as Number = 1;
    hidden var running as Boolean = false;

    function initialize() {
        timer = new Timer.Timer();
    }

    // longest loop on the page (text + gap), screen px. 0 = all fits
    function setup(maxLoop as Number, stepPx as Number) as Void {
        stop();
        limit = maxLoop * TOP_PASSES;
        step = stepPx < 1 ? 1 : stepPx;
    }

    function play() as Void {
        if (limit == 0) {
            return;
        }
        timer.stop();
        travel = 0;
        running = true;
        timer.start(method(:tick), TOP_TICK_MS, false);
    }

    // back to the start, timer off
    function stop() as Void {
        timer.stop();
        running = false;
        travel = 0;
    }

    // one-shot, re-armed only while there's more to go
    function tick() as Void {
        if (!running) {
            return;
        }
        travel += step;
        if (travel >= limit) {
            stop(); // ends on the start of every line
            WatchUi.requestUpdate();
            return;
        }
        timer.start(method(:tick), TOP_TICK_MS, false);
        WatchUi.requestUpdate();
    }

    function isRunning() as Boolean {
        return running;
    }

    // how far a line with this loop length has moved
    function shift(loop as Number) as Number {
        return running ? travel % loop : 0;
    }
}

class ListView extends WatchUi.View {
    hidden var round as Boolean;
    hidden var title as String;
    // filled by load(): [title, grey line, opens a page]
    hidden var rows as Array<Array> = [] as Array<Array>;
    hidden var marq as Marquee;
    // layout, screen px, unscrolled. redone after refresh()
    hidden var ready as Boolean = false;
    hidden var rowY as Array<Number> = [] as Array<Number>;
    hidden var rowH as Array<Number> = [] as Array<Number>;
    hidden var tFont as Array<Graphics.FontDefinition> = [] as Array<Graphics.FontDefinition>;
    hidden var colX as Number = 0;
    hidden var colW as Number = 0;
    hidden var textW as Number = 0;
    hidden var loopGap as Number = 0;
    hidden var hdrH as Number = 0;
    hidden var viewBot as Number = 0;
    hidden var offset as Number = 0;
    hidden var maxOffset as Number = 0;

    function initialize(t as String) {
        View.initialize();
        title = t;
        round = isRound();
        marq = new Marquee();
    }

    // pages fill rows here
    function load() as Void {
    }

    // row i tapped, only rows with a chevron get here
    function open(i as Number) as Void {
    }

    // back goes up one level
    function back() as Void {
        getRemoteApp().up();
    }

    // phone settings changed: new values, measure again, no replay
    function refresh() as Void {
        marq.stop();
        load();
        ready = false;
        WatchUi.requestUpdate();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        layout(dc);
    }

    function onShow() as Void {
        marq.play();
    }

    function onHide() as Void {
        marq.stop();
    }

    hidden function pw(v as Number, w as Number, h as Number) as Number {
        return round ? rp(v, w, h) : hx(v, w);
    }

    hidden function ph(v as Number, w as Number, h as Number) as Number {
        return round ? rp(v, w, h) : hy(v, h);
    }

    // row height comes from the real fonts, so the lines can't overlap
    hidden function layout(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        hdrH = headerHeight(dc, title);
        viewBot = round ? ry(RHELP_BOT, w, h) : h;
        if (round) {
            colX = rx(RND_LIST_X, w, h);
            colW = rp(RND_LIST_W, w, h);
        } else {
            colX = hx(LIST_X, w);
            colW = hx(LIST_X + LIST_W, w) - colX;
        }
        textW = colW - pw(LIST_CHEV_W, w, h);
        loopGap = pw(TOP_LOOP_GAP, w, h);

        rowY = [] as Array<Number>;
        rowH = [] as Array<Number>;
        tFont = [] as Array<Graphics.FontDefinition>;
        var pad = ph(LIST_PAD, w, h);
        var gap = ph(LIST_GAP, w, h);
        var sh = dc.getFontHeight(Graphics.FONT_XTINY);
        var maxLoop = 0;
        var y = hdrH;
        for (var i = 0; i < rows.size(); i++) {
            var t = rows[i][0] as String;
            var s = rows[i][1] as String;
            // title: tiny if it fits, else xtiny. grey line is always xtiny
            var f = Graphics.FONT_TINY;
            if (dc.getTextWidthInPixels(t, f) > textW) {
                f = Graphics.FONT_XTINY;
            }
            tFont.add(f);
            // still too wide = it scrolls
            var tw = dc.getTextWidthInPixels(t, f);
            var sw = dc.getTextWidthInPixels(s, Graphics.FONT_XTINY);
            if (tw > textW && tw + loopGap > maxLoop) { maxLoop = tw + loopGap; }
            if (sw > textW && sw + loopGap > maxLoop) { maxLoop = sw + loopGap; }

            var rh = pad + dc.getFontHeight(f) + gap + sh + pad;
            rowY.add(y);
            rowH.add(rh);
            y += rh;
        }
        marq.setup(maxLoop, pw(TOP_STEP, w, h));

        maxOffset = y + ph(12, w, h) > viewBot ? y + ph(12, w, h) - viewBot : 0;
        if (offset > maxOffset) {
            offset = maxOffset;
        }
        ready = true;
    }

    // dir 1 = more below, -1 = back up. ~60% of the window per step
    function scroll(dir as Number) as Void {
        if (maxOffset == 0) {
            return;
        }
        offset += dir * (viewBot - hdrH) * 60 / 100;
        if (offset < 0) { offset = 0; }
        if (offset > maxOffset) { offset = maxOffset; }
        WatchUi.requestUpdate();
    }

    // x,y in screen px. back, then the pills, then rows in the window
    function tap(x as Number, y as Number) as Void {
        var ds = System.getDeviceSettings();
        var w = ds.screenWidth;
        var h = ds.screenHeight;
        if (backHitH(x, y, w, hdrH)) {
            back();
            return;
        }
        var downAt = round ? viewBot : h * (100 - CHEV_ZONE) / 100;
        var upTo = round ? hdrH + ph(PILL_H + PILL_PAD * 2, w, h) : hdrH + (h - hdrH) * CHEV_ZONE / 100;
        if (offset < maxOffset && y >= downAt) {
            scroll(1);
            return;
        }
        if (offset > 0 && y >= hdrH && y < upTo) {
            scroll(-1);
            return;
        }
        if (y < hdrH || y >= viewBot) {
            return;
        }
        // whole row width, a bit of slack at the sides. rows touch, no gaps
        var s = pw(SLACK, w, h);
        if (x < colX - s || x >= colX + colW + s) {
            return;
        }
        var cy = y + offset;
        for (var i = 0; i < rows.size(); i++) {
            if (cy >= rowY[i] && cy < rowY[i] + rowH[i]) {
                if (rows[i][2] as Boolean) {
                    open(i);
                }
                return;
            }
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (!ready) {
            layout(dc);
        }
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(COL_BG, COL_BG);
        dc.clear();

        var pad = ph(LIST_PAD, w, h);
        var gap = ph(LIST_GAP, w, h);
        var sh = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setClip(0, hdrH, w, viewBot - hdrH);
        for (var i = 0; i < rows.size(); i++) {
            var y = rowY[i] - offset;
            var f = tFont[i];
            var th = dc.getFontHeight(f);
            line(dc, rows[i][0] as String, f, y + pad, th, COL_TEXT);
            line(dc, rows[i][1] as String, Graphics.FONT_XTINY, y + pad + th + gap, sh, COL_SOFT_TEXT);
            if (rows[i][2] as Boolean) {
                dc.setColor(COL_ICON, Graphics.COLOR_TRANSPARENT);
                drawChevron(dc, colX + colW - pw(12, w, h), y + rowH[i] / 2, 1, 0);
            }
            // thin line between rows, not after the last one
            if (i < rows.size() - 1) {
                dc.setColor(COL_CARD_EDGE, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(colX, y + rowH[i] - 1, colW, 1);
            }
        }
        dc.clearClip();

        drawPills(dc, w, h);
        // header last so the rows slide under it
        drawHeader(dc, title);
    }

    // one line of text from top y. too wide = clipped to its box and scrolled
    // with a second copy so the loop has no hole
    hidden function line(dc as Graphics.Dc, s as String, f as Graphics.FontDefinition, top as Number,
            lh as Number, col as Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        var cy = top + lh / 2;
        var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var tw = dc.getTextWidthInPixels(s, f);
        if (tw <= textW) {
            dc.drawText(colX, cy, f, s, just);
            return;
        }
        // own clip, kept inside the scroll window
        var ct = top > hdrH ? top : hdrH;
        var cb = top + lh < viewBot ? top + lh : viewBot;
        if (cb <= ct) {
            return;
        }
        var loop = tw + loopGap;
        var x = colX - marq.shift(loop);
        dc.setClip(colX, ct, textW, cb - ct);
        dc.drawText(x, cy, f, s, just);
        if (marq.isRunning()) {
            dc.drawText(x + loop, cy, f, s, just);
        }
        dc.setClip(0, hdrH, dc.getWidth(), viewBot - hdrH);
    }

    // same pills as the help page, only while there's more that way
    hidden function drawPills(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var half = PILL_H / 2;
        if (offset < maxOffset) {
            if (round) {
                drawChevPill(dc, ry(RPILL_Y, w, h), 1, viewBot, h);
            } else {
                var downY = h - hy(PILL_PAD + half, h);
                drawChevPill(dc, downY, 1, downY - hy(half + PILL_PAD, h), h);
            }
        }
        if (offset > 0) {
            var upY = hdrH + ph(PILL_PAD + half, w, h);
            drawChevPill(dc, upY, -1, hdrH, hdrH + ph(PILL_H + PILL_PAD * 2, w, h));
        }
    }
}

// taps, scroll swipes, and every kind of back goes up one level
class ListDelegate extends WatchUi.BehaviorDelegate {
    hidden var view as ListView;

    function initialize(v as ListView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        getRemoteApp().poke();
        var xy = evt.getCoordinates();
        view.tap(xy[0], xy[1]);
        return true;
    }

    // up/down only scroll, right goes back, left does nothing.
    // swipes never get to the row taps
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        getRemoteApp().poke();
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            view.scroll(1);
        } else if (dir == WatchUi.SWIPE_DOWN) {
            view.scroll(-1);
        } else if (dir == WatchUi.SWIPE_RIGHT) {
            view.back();
        }
        return true;
    }

    function onNextPage() as Boolean {
        getRemoteApp().poke();
        view.scroll(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        getRemoteApp().poke();
        view.scroll(-1);
        return true;
    }

    function onBack() as Boolean {
        getRemoteApp().poke();
        view.back();
        return true;
    }
}
