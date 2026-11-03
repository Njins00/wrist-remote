import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// "How to fix" page: pinned header (back arrow + title), numbered steps that
// scroll under it. no timers, no connector, nothing gets sent from here

// header, mockup px. shared with the tip and settings pages later
const HDR_H = 52;
const HDR_BTN_X = 20;
const HDR_BTN_Y = 8;
const HDR_BTN = 36;      // looks 36x36
const HDR_BTN_R = 12;
const HDR_HIT_X = 16;    // tap area 44x44 around the button
const HDR_HIT_Y = 4;
const HDR_HIT = 44;
const HDR_TITLE_X = 66;  // button edge + 10
const HDR_MARGIN = 20;

// scroll area, mockup px
const HELP_MARGIN = 20;  // each side, clear of the rounded corners
const CHEV_W = 56;       // pill behind each chevron so it reads as a button
const CHEV_H = 28;
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

// black strip, back button with an arrow, title to its right. never scrolls
function drawHeader(dc as Graphics.Dc, title as String) as Void {
    var w = dc.getWidth();
    var h = dc.getHeight();
    dc.setColor(COL_BG, COL_BG);
    dc.fillRectangle(0, 0, w, helpHeaderH(h));

    var bx = hx(HDR_BTN_X, w);
    var by = hy(HDR_BTN_Y, h);
    var bw = hx(HDR_BTN_X + HDR_BTN, w) - bx;
    var bh = hy(HDR_BTN_Y + HDR_BTN, h) - by;
    dc.setColor(COL_BTN, Graphics.COLOR_TRANSPARENT);
    dc.fillRoundedRectangle(bx, by, bw, bh, hr(HDR_BTN_R, w, h));

    // same arrow as the remote's Back (copy for now, merge in phase 6)
    var cx = bx + bw / 2;
    var cy = by + bh / 2;
    var a = hr(11, w, h);
    var t = hr(7, w, h);
    dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(hr(4, w, h));
    dc.drawLine(cx - a, cy, cx + a, cy);
    dc.drawLine(cx - a, cy, cx - a + t, cy - t);
    dc.drawLine(cx - a, cy, cx - a + t, cy + t);
    dc.setPenWidth(1);

    // title: biggest font that fits, else wrap to 2 lines. never cut
    var tx = hx(HDR_TITLE_X, w);
    var maxW = w - tx - hx(HDR_MARGIN, w);
    var font = fitFont(dc, title, maxW);
    var text = title;
    if (dc.getTextWidthInPixels(title, font) > maxW) {
        var fit = Graphics.fitTextToArea(title, Graphics.FONT_XTINY, maxW, helpHeaderH(h), false);
        if (fit != null) {
            text = fit;
        }
    }
    dc.drawText(tx, cy, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
}

// x,y in screen px
function headerBackHit(x as Number, y as Number, w as Number, h as Number) as Boolean {
    return x >= hx(HDR_HIT_X, w) && x < hx(HDR_HIT_X + HDR_HIT, w) &&
        y >= hy(HDR_HIT_Y, h) && y < hy(HDR_HIT_Y + HDR_HIT, h);
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

    function initialize(k as Number) {
        View.initialize();
        kind = k;
    }

    hidden function layout(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        margin = hx(HELP_MARGIN, w);
        var textW = w - margin * 2;
        var y = helpHeaderH(h) + hy(10, h);

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
        offset += dir * (screenH - helpHeaderH(screenH)) * 60 / 100;
        if (offset < 0) { offset = 0; }
        if (offset > maxOffset) { offset = maxOffset; }
        WatchUi.requestUpdate();
    }

    // chevron zones: bottom 18% of the screen, top 18% of the scroll area.
    // only while that chevron is showing
    function tapScroll(y as Number, screenH as Number) as Void {
        var top = helpHeaderH(screenH);
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
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(COL_BG, COL_BG);
        dc.clear();

        dc.setColor(COL_SOFT_TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < steps.size(); i++) {
            dc.drawText(margin, stepY[i] - offset, Graphics.FONT_XTINY, steps[i],
                Graphics.TEXT_JUSTIFY_LEFT);
        }

        // static chevron buttons, only on pages that scroll
        if (offset < maxOffset) {
            chevron(dc, h - hy(22, h), 1, w, h);
        }
        if (offset > 0) {
            chevron(dc, helpHeaderH(h) + hy(18, h), -1, w, h);
        }

        // header last so the steps slide under it
        drawHeader(dc, POP_TITLES[kind]);
    }

    // pill with a chevron on a black strip. dir 1 points down, -1 up
    hidden function chevron(dc as Graphics.Dc, cy as Number, dir as Number, w as Number, h as Number) as Void {
        var pw = hx(CHEV_W, w);
        var ph = hy(CHEV_H, h);
        var pad = hy(6, h);
        dc.setColor(COL_BG, COL_BG);
        if (dir > 0) {
            dc.fillRectangle(0, cy - ph / 2 - pad, w, h - (cy - ph / 2 - pad));
        } else {
            var top = helpHeaderH(h);
            dc.fillRectangle(0, top, w, cy + ph / 2 + pad - top);
        }
        var cx = w / 2;
        dc.setColor(COL_BTN, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - pw / 2, cy - ph / 2, pw, ph, ph / 2);

        var a = hr(12, w, h);
        var d = hr(6, w, h);
        dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(hr(4, w, h));
        dc.drawLine(cx - a, cy - dir * d, cx, cy + dir * d);
        dc.drawLine(cx + a, cy - dir * d, cx, cy + dir * d);
        dc.setPenWidth(1);
    }
}

class HelpDelegate extends WatchUi.BehaviorDelegate {
    hidden var view as HelpView;
    hidden var main as MainView; // only for poke(), keeps the idle clock honest

    function initialize(v as HelpView, m as MainView) {
        BehaviorDelegate.initialize();
        view = v;
        main = m;
    }

    // up/down scroll, left/right do nothing. true for all so swipe right never exits
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        main.poke();
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
        main.poke();
        view.scroll(1, System.getDeviceSettings().screenHeight);
        return true;
    }

    function onPreviousPage() as Boolean {
        main.poke();
        view.scroll(-1, System.getDeviceSettings().screenHeight);
        return true;
    }

    // back arrow first, then the chevron zones. everything else does nothing
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        main.poke();
        var xy = evt.getCoordinates();
        var ds = System.getDeviceSettings();
        if (headerBackHit(xy[0], xy[1], ds.screenWidth, ds.screenHeight)) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else {
            view.tapScroll(xy[1], ds.screenHeight);
        }
        return true;
    }

    // physical back goes back to the remote
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
