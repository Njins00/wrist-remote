import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// "How to fix" page: pinned header (back arrow + title), numbered steps that
// scroll under it. no timers, no connector, nothing gets sent from here.
// also home to the shared header, arrow and chevron drawing

// header, mockup px. shared with the tip and settings pages later.
// back button has the remote's Back proportions, sized to the 52 px strip
const HDR_H = 52;
const HDR_BTN_X = 16;
const HDR_BTN_Y = 6;
const HDR_BTN_W = 64;
const HDR_BTN_H = 40;
const HDR_BTN_R = 12;
const HDR_HIT_W = 100;   // tap area: x 0-100, the whole header height
const HDR_TITLE_X = 90;  // button edge + 10
const HDR_MARGIN = 20;

// scroll area, mockup px
const HELP_MARGIN = 20;  // each side, clear of the rounded corners
const PILL_W = 64;       // chevron pill, same shape as the back button
const PILL_H = 40;
const PILL_R = 12;
const PILL_PAD = 6;      // black strip around the pill
const CHEV_ZONE = 18;    // % that taps to scroll

// mockup px -> screen px for pages that don't have MainView's helpers
function hx(v as Number, w as Number) as Number {
    return v * w / MOCK_W;
}

function hy(v as Number, h as Number) as Number {
    return v * h / MOCK_H;
}

function hr(v as Number, w as Number, h as Number) as Number {
    var a = hx(v, w);
    var b = hy(v, h);
    var r = a < b ? a : b;
    return r < 1 ? 1 : r;
}

function helpHeaderH(h as Number) as Number {
    return hy(HDR_H, h);
}

// the remote's Back arrow: left arrow with a stem. current colour
function drawBackArrow(dc as Graphics.Dc, cx as Number, cy as Number) as Void {
    var w = dc.getWidth();
    var h = dc.getHeight();
    var a = hr(11, w, h);
    var t = hr(7, w, h);
    dc.setPenWidth(hr(4, w, h));
    dc.drawLine(cx - a, cy, cx + a, cy);
    dc.drawLine(cx - a, cy, cx - a + t, cy - t);
    dc.drawLine(cx - a, cy, cx - a + t, cy + t);
    dc.setPenWidth(1);
}

// the remote's chevron: two thick lines pointing (dx,dy). current colour
function drawChevron(dc as Graphics.Dc, cx as Number, cy as Number, dx as Number, dy as Number) as Void {
    var w = dc.getWidth();
    var h = dc.getHeight();
    var d = hr(6, w, h);  // half depth
    var a = hr(12, w, h); // half width
    var tipX = cx + dx * d;
    var tipY = cy + dy * d;
    var bx = cx - dx * d;
    var by = cy - dy * d;
    dc.setPenWidth(hr(5, w, h));
    dc.drawLine(bx - dy * a, by + dx * a, tipX, tipY);
    dc.drawLine(bx + dy * a, by - dx * a, tipX, tipY);
    dc.setPenWidth(1);
}

// black strip from stripTop to stripBottom, then a pill with a chevron
// centred at cy. dir 1 points down, -1 up
function drawChevPill(dc as Graphics.Dc, cy as Number, dir as Number, stripTop as Number, stripBottom as Number) as Void {
    var w = dc.getWidth();
    var h = dc.getHeight();
    dc.setColor(COL_BG, COL_BG);
    dc.fillRectangle(0, stripTop, w, stripBottom - stripTop);
    var pw = hx(PILL_W, w);
    var ph = hy(PILL_H, h);
    var cx = w / 2;
    dc.setColor(COL_BTN, Graphics.COLOR_TRANSPARENT);
    dc.fillRoundedRectangle(cx - pw / 2, cy - ph / 2, pw, ph, hr(PILL_R, w, h));
    dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
    drawChevron(dc, cx, cy, 0, dir);
}

// title room, screen px: from the title's x to the right margin
function headerTitleW(w as Number) as Number {
    return w - hx(HDR_TITLE_X, w) - hx(HDR_MARGIN, w);
}

// index into FIT_FONTS of the biggest font that fits on one line,
// -1 if not even xtiny does (then it wraps)
function headerFont(dc as Graphics.Dc, title as String) as Number {
    var maxW = headerTitleW(dc.getWidth());
    for (var i = 0; i < FIT_FONTS.size(); i++) {
        if (dc.getTextWidthInPixels(title, FIT_FONTS[i] as Graphics.FontDefinition) <= maxW) {
            return i;
        }
    }
    return -1;
}

// xtiny, split at spaces so each line fits. never cuts a word
function headerLines(dc as Graphics.Dc, title as String) as Array<String> {
    var maxW = headerTitleW(dc.getWidth());
    var lines = [] as Array<String>;
    var line = "";
    var rest = title;
    while (rest.length() > 0) {
        // next word off the front
        var sp = rest.find(" ");
        var word = rest;
        if (sp == null) {
            rest = "";
        } else {
            word = rest.substring(0, sp) as String;
            rest = rest.substring(sp + 1, rest.length()) as String;
        }
        var next = line.length() == 0 ? word : line + " " + word;
        if (line.length() > 0 && dc.getTextWidthInPixels(next, Graphics.FONT_XTINY) > maxW) {
            lines.add(line);
            line = word;
        } else {
            line = next;
        }
    }
    if (line.length() > 0) {
        lines.add(line);
    }
    return lines;
}

// header height for this title, screen px. 52 normally, taller if the
// wrapped title needs it (6 px above and below like the button)
function headerHeight(dc as Graphics.Dc, title as String) as Number {
    var h = dc.getHeight();
    var hh = helpHeaderH(h);
    if (headerFont(dc, title) >= 0) {
        return hh;
    }
    var need = headerLines(dc, title).size() * dc.getFontHeight(Graphics.FONT_XTINY) + hy(HDR_BTN_Y, h) * 2;
    return need > hh ? need : hh;
}

// black strip, back button with an arrow, title to its right. never scrolls.
// title: one line small, tiny or xtiny, else xtiny wrapped and the header
// grows. never cut
function drawHeader(dc as Graphics.Dc, title as String) as Void {
    var w = dc.getWidth();
    var h = dc.getHeight();
    var hh = headerHeight(dc, title);
    dc.setColor(COL_BG, COL_BG);
    dc.fillRectangle(0, 0, w, hh);

    // button stays centred in the header, however tall it got
    var bx = hx(HDR_BTN_X, w);
    var bw = hx(HDR_BTN_X + HDR_BTN_W, w) - bx;
    var bh = hy(HDR_BTN_Y + HDR_BTN_H, h) - hy(HDR_BTN_Y, h);
    var by = (hh - bh) / 2;
    dc.setColor(COL_BTN, Graphics.COLOR_TRANSPARENT);
    dc.fillRoundedRectangle(bx, by, bw, bh, hr(HDR_BTN_R, w, h));
    var cy = hh / 2;
    dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
    drawBackArrow(dc, bx + bw / 2, cy);

    var tx = hx(HDR_TITLE_X, w);
    var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
    var f = headerFont(dc, title);
    if (f >= 0) {
        dc.drawText(tx, cy, FIT_FONTS[f] as Graphics.FontDefinition, title, just);
        return;
    }
    // one line at a time, the block centred on the button
    var lines = headerLines(dc, title);
    var lineH = dc.getFontHeight(Graphics.FONT_XTINY);
    var y = cy - lines.size() * lineH / 2 + lineH / 2;
    for (var i = 0; i < lines.size(); i++) {
        dc.drawText(tx, y + i * lineH, Graphics.FONT_XTINY, lines[i], just);
    }
}

// x,y in screen px. whole left part of a 52 px header, not just the button.
// pages with a taller header use backHitH
function headerBackHit(x as Number, y as Number, w as Number, h as Number) as Boolean {
    return backHitH(x, y, w, helpHeaderH(h));
}

// same, for a header hh screen px tall
function backHitH(x as Number, y as Number, w as Number, hh as Number) as Boolean {
    return x >= 0 && x < hx(HDR_HIT_W, w) && y >= 0 && y < hh;
}

class HelpView extends WatchUi.View {
    hidden var kind as Number;
    hidden var offset as Number = 0;    // screen px scrolled down, 0 = top
    hidden var maxOffset as Number = 0;
    // worked out on the first onUpdate (needs a dc), texts never change
    hidden var ready as Boolean = false;
    hidden var steps as Array<String> = [] as Array<String>;
    hidden var stepY as Array<Number> = [] as Array<Number>;
    hidden var margin as Number = 0;
    // screen px, 52 scaled unless the title wraps. 0 until the first draw
    hidden var hdrH as Number = 0;

    function initialize(k as Number) {
        View.initialize();
        kind = k;
    }

    hidden function layout(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        hdrH = headerHeight(dc, POP_TITLES[kind]);
        margin = hx(HELP_MARGIN, w);
        var textW = w - margin * 2;
        var y = hdrH + hy(10, h);

        // each step wrapped on its own, room for 6 lines so nothing's cut
        var lineH = dc.getFontHeight(Graphics.FONT_XTINY);
        var list = POP_STEPS[kind] as Array<String>;
        for (var i = 0; i < list.size(); i++) {
            var s = (i + 1).toString() + ". " + list[i];
            var fit = Graphics.fitTextToArea(s, Graphics.FONT_XTINY, textW, lineH * 6, false);
            var text = fit != null ? fit : s;
            var lines = 1;
            var chars = text.toCharArray();
            for (var j = 0; j < chars.size(); j++) {
                if (chars[j] == '\n') {
                    lines++;
                }
            }
            steps.add(text);
            stepY.add(y);
            y += lines * lineH + hy(8, h);
        }

        var bottom = y + hy(12, h);
        maxOffset = bottom > h ? bottom - h : 0;
        ready = true;
    }

    // dir 1 = show more below, -1 = back up. ~60% of the scroll area per step
    function scroll(dir as Number, screenH as Number) as Void {
        if (maxOffset == 0) {
            return;
        }
        offset += dir * (screenH - hdrH) * 60 / 100;
        if (offset < 0) { offset = 0; }
        if (offset > maxOffset) { offset = maxOffset; }
        WatchUi.requestUpdate();
    }

    // chevron zones: bottom 18% of the screen, top 18% of the scroll area.
    // only while that chevron is showing
    function tapScroll(y as Number, screenH as Number) as Void {
        var top = hdrH;
        if (offset < maxOffset && y >= screenH * (100 - CHEV_ZONE) / 100) {
            scroll(1, screenH);
        } else if (offset > 0 && y >= top && y < top + (screenH - top) * CHEV_ZONE / 100) {
            scroll(-1, screenH);
        }
    }

    // redraws only after a scroll
    function onUpdate(dc as Graphics.Dc) as Void {
        if (!ready) {
            layout(dc);
        }
        var h = dc.getHeight();
        dc.setColor(COL_BG, COL_BG);
        dc.clear();

        dc.setColor(COL_SOFT_TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < steps.size(); i++) {
            dc.drawText(margin, stepY[i] - offset, Graphics.FONT_XTINY, steps[i],
                Graphics.TEXT_JUSTIFY_LEFT);
        }

        // static chevron pills, only on pages that scroll. down 314-354,
        // up just under the header (58-98 with the normal 52 px one)
        var half = PILL_H / 2;
        if (offset < maxOffset) {
            var downY = h - hy(PILL_PAD + half, h);
            drawChevPill(dc, downY, 1, downY - hy(half + PILL_PAD, h), h);
        }
        if (offset > 0) {
            var upY = hdrH + hy(PILL_PAD + half, h);
            drawChevPill(dc, upY, -1, hdrH, upY + hy(half + PILL_PAD, h));
        }

        // header last so the steps slide under it
        drawHeader(dc, POP_TITLES[kind]);
    }

    // x,y in screen px. back area covers this page's real header height
    function backHit(x as Number, y as Number, w as Number) as Boolean {
        return backHitH(x, y, w, hdrH);
    }
}

class HelpDelegate extends WatchUi.BehaviorDelegate {
    hidden var view as HelpView;

    function initialize(v as HelpView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    // up/down scroll, left/right do nothing. true for all so swipe right never exits
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        getRemoteApp().poke();
        var dir = evt.getDirection();
        var h = System.getDeviceSettings().screenHeight;
        if (dir == WatchUi.SWIPE_UP) {
            view.scroll(1, h);
        } else if (dir == WatchUi.SWIPE_DOWN) {
            view.scroll(-1, h);
        }
        return true;
    }

    // safety net in case a device sends page behaviours instead of swipes
    function onNextPage() as Boolean {
        getRemoteApp().poke();
        view.scroll(1, System.getDeviceSettings().screenHeight);
        return true;
    }

    function onPreviousPage() as Boolean {
        getRemoteApp().poke();
        view.scroll(-1, System.getDeviceSettings().screenHeight);
        return true;
    }

    // back area first, then the chevron zones. everything else does nothing
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        getRemoteApp().poke();
        var xy = evt.getCoordinates();
        var ds = System.getDeviceSettings();
        if (view.backHit(xy[0], xy[1], ds.screenWidth)) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else {
            view.tapScroll(xy[1], ds.screenHeight);
        }
        return true;
    }

    // physical back goes back to the screen underneath
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
