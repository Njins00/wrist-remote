import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// first run: setup (only if there's no ip yet) -> which device.
// one view, step says which screen. nothing ever gets sent from here

enum {
    STEP_SETUP,
    STEP_TYPE
}

// what the user picked, kept in Storage as "deviceType". -1 = nothing yet
enum {
    TYPE_TV,
    TYPE_STICK
}

const COL_TILE_BG = 0x24153F;
const COL_TILE_ICON = 0xB99BFA;
// setup behind the pop-up. solid colours like the remote's dim ones
const COL_TILE_BG_DIM = 0x120A1F;
const COL_TILE_ICON_DIM = 0x453A5E;
const COL_SOFT_TEXT_DIM = 0x45484A;

// mockup px. one big button at the bottom of each screen
const ONB_BTN_X = 38;
const ONB_BTN_Y = 290;
const ONB_BTN_W = 244;
const ONB_BTN_H = 42;

// setup screen
const TILE_X = 136;
const TILE_Y = 14;
const TILE = 48;
const TILE_R = 14;
const SETUP_TITLE_Y = 84;
const SETUP_ROWS_Y = 104;
const SETUP_NUM_X = 30;  // centre of the number circle
const SETUP_NUM_R = 10;
const SETUP_TEXT_X = 48;
const SETUP_TEXT_R = 304; // right edge of the step text
const SETUP_GAP = 8;      // between the content and the pinned button strip

// type screen: x, y, w, h. TV first, same order as TYPE_*.
// 96 high so two xtiny lines (39 px) fit inside the 8 px padding
const TYPE_CARDS = [
    [20, 60, 280, 96],
    [20, 164, 280, 96]
];
const TYPE_CARD_R = 20;
// round, 416 px. setup: tile and title pinned, only the steps scroll,
// clipped to the window where the 276 column fits the circle
const RND_TILE_X = 185;
const RND_TILE_Y = 40;
const RND_TILE = 46;
const RND_TITLE_Y = 110;
const RND_TITLE_W = 280;
const RND_NUM_X = 80;
const RND_TEXT_X = 98;
const RND_TEXT_R = 346;
const RND_WIN_TOP = 134;
const RND_WIN_BOT = 318;
const RND_DOWN_Y = 292;  // pill centres, strips 266-318 and 134-186
const RND_UP_Y = 160;
// x, y, w, h. fully rounded
const RND_CHECK = [103, 326, 210, 54];
const RND_CONT = [108, 282, 200, 52];
// 80 high, not 70: two xtiny lines are 68 on fr265
const RND_TYPE_CARDS = [
    [72, 98, 272, 80],
    [72, 188, 272, 80]
];
const RND_CARD_PAD = 6;

const TYPE_TITLES = ["Roku TV", "Roku stick or box"];
const TYPE_SUBS = ["Roku built in", "Plugs into a TV"];

class OnboardView extends WatchUi.View {
    hidden var step as Number;
    hidden var first as Number;          // back on this screen exits
    hidden var picked as Number = -1;    // TYPE_*, -1 = nothing yet
    // "No valid home IP yet", OK only. setup screen only
    hidden var popup as Popup or Null = null;
    // setup layout, worked out on the first draw (needs a dc). screen px,
    // unscrolled. texts never change
    hidden var wrapped as Boolean = false;
    hidden var stepText as Array<String> = [] as Array<String>;
    hidden var stepY as Array<Number> = [] as Array<Number>;
    hidden var areaBottom as Number = 0; // content stops here, button strip below
    // setup scroll, only if the content doesn't fit above the button
    hidden var offset as Number = 0;
    hidden var maxOffset as Number = 0;
    // round: 416 px tables, steps window top in screen px
    hidden var round as Boolean;
    hidden var winTop as Number = 0;

    function initialize(s as Number) {
        View.initialize();
        step = s;
        first = s;
        round = isRound();
    }

    // mockup px -> screen px, 320x360 on square, the 416 circle on round.
    // px/py are positions, pw/ph lengths, pr radii
    hidden function px(v as Number, w as Number, h as Number) as Number {
        return round ? rx(v, w, h) : hx(v, w);
    }

    hidden function py(v as Number, w as Number, h as Number) as Number {
        return round ? ry(v, w, h) : hy(v, h);
    }

    hidden function pw(v as Number, w as Number, h as Number) as Number {
        return round ? rp(v, w, h) : hx(v, w);
    }

    hidden function ph(v as Number, w as Number, h as Number) as Number {
        return round ? rp(v, w, h) : hy(v, h);
    }

    hidden function pr(v as Number, w as Number, h as Number) as Number {
        if (round) {
            var r = rp(v, w, h);
            return r < 1 ? 1 : r;
        }
        return hr(v, w, h);
    }

    // the big button: one shared spot on square, its own on each round screen
    hidden function btnRect() as Array<Number> {
        if (round) {
            return step == STEP_SETUP ? RND_CHECK : RND_CONT;
        }
        return [ONB_BTN_X, ONB_BTN_Y, ONB_BTN_W, ONB_BTN_H];
    }

    hidden function cards() as Array<Array<Number>> {
        return round ? RND_TYPE_CARDS : TYPE_CARDS;
    }

    // ip is good now. already onboarded = straight to the remote
    hidden function ipReady() as Void {
        popup = null;
        if (isOnboarded()) {
            getRemoteApp().showRemote();
            return;
        }
        step = STEP_TYPE;
        WatchUi.requestUpdate();
    }

    // only re-reads the setting, no network. nothing yet = OK-only pop-up
    hidden function checkAgain() as Void {
        if (homeIpSet()) {
            ipReady();
        } else {
            popup = new Popup(POP_NO_IP, false);
            WatchUi.requestUpdate();
        }
    }

    // ip saved in the phone app while we're on the setup screen.
    // closes the pop-up too if it's open
    function refreshSettings() as Void {
        if (step == STEP_SETUP && homeIpSet()) {
            ipReady();
        }
    }

    // Continue. only Roku TVs do volume over the network, so TV = volume
    // buttons on, stick = off (can still be turned on in the phone settings).
    // onboarded = from now on the app opens on the remote. watch only
    hidden function next() as Void {
        if (picked < 0) {
            return;
        }
        Application.Storage.setValue("deviceType", picked);
        Application.Properties.setValue("volumeButtons", picked == TYPE_TV);
        Application.Storage.setValue("onboarded", true);
        getRemoteApp().showRemote();
    }

    // closes the pop-up first, else one step back. false on the first
    // screen, so back exits
    function back() as Boolean {
        if (popup != null) {
            popup = null;
            WatchUi.requestUpdate();
            return true;
        }
        if (step == first) {
            return false;
        }
        step--;
        offset = 0;
        WatchUi.requestUpdate();
        return true;
    }

    // dir 1 = show more below, -1 = back up. setup only, ~60% of the area
    // per step. nothing while the pop-up is open
    function scroll(dir as Number) as Void {
        if (popup != null || step != STEP_SETUP || maxOffset == 0) {
            return;
        }
        var area = round ? areaBottom - winTop : areaBottom;
        offset += dir * area * 60 / 100;
        if (offset < 0) { offset = 0; }
        if (offset > maxOffset) { offset = maxOffset; }
        WatchUi.requestUpdate();
    }

    // x,y in screen px
    function tap(x as Number, y as Number) as Void {
        var ds = System.getDeviceSettings();
        var w = ds.screenWidth;
        var h = ds.screenHeight;
        var mx = x * MOCK_W / w;
        var my = y * MOCK_H / h;
        // pop-up open: only OK does anything
        var p = popup;
        if (p != null) {
            if (p.buttonAt(mx, my) == POP_HIT_OK) {
                popup = null;
                WatchUi.requestUpdate();
            }
            return;
        }
        // round: back to 416 px for the buttons and cards
        if (round) {
            var m = w < h ? w : h;
            mx = (x - (w - m) / 2) * RND_MOCK / m;
            my = (y - (h - m) / 2) * RND_MOCK / m;
        }
        var b = btnRect();
        if (step == STEP_SETUP) {
            // button first, then the chevron zones (top/bottom 18% of the
            // area, only while that chevron shows). round: the pill strips
            var strip = rp(PILL_H + PILL_PAD * 2, w, h);
            if (inBox(mx, my, b[0], b[1], b[2], b[3])) {
                checkAgain();
            } else if (round) {
                if (offset < maxOffset && y >= areaBottom - strip && y < areaBottom) {
                    scroll(1);
                } else if (offset > 0 && y >= winTop && y < winTop + strip) {
                    scroll(-1);
                }
            } else if (offset < maxOffset && y < areaBottom && y >= areaBottom * (100 - CHEV_ZONE) / 100) {
                scroll(1);
            } else if (offset > 0 && y < areaBottom * CHEV_ZONE / 100) {
                scroll(-1);
            }
            return;
        }
        // type screen: header arrow works like back
        if (headerBackHit(x, y, w, h)) {
            if (!back()) {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
            return;
        }
        var list = cards();
        for (var i = 0; i < list.size(); i++) {
            var c = list[i];
            if (inBox(mx, my, c[0], c[1], c[2], c[3])) {
                picked = i;
                WatchUi.requestUpdate();
                return;
            }
        }
        if (inBox(mx, my, b[0], b[1], b[2], b[3])) {
            next(); // does nothing until a card is picked
        }
    }

    // mockup px, with the usual slack
    hidden function inBox(mx as Number, my as Number, x as Number, y as Number, w as Number, h as Number) as Boolean {
        return mx >= x - SLACK && mx < x + w + SLACK && my >= y - SLACK && my < y + h + SLACK;
    }

    // redraws only on taps and settings changes
    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(COL_BG, COL_BG);
        dc.clear();
        if (step == STEP_SETUP) {
            drawSetup(dc, w, h);
        } else {
            drawType(dc, w, h);
        }
        var p = popup;
        if (p != null) {
            p.draw(dc);
        }
    }

    // same steps as the "Set your Roku's IP" help page. each wraps to as many
    // lines as it needs, never cut. scrolls if it all won't fit above the button
    hidden function layout(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var tw = hx(SETUP_TEXT_R, w) - hx(SETUP_TEXT_X, w);
        var y = hy(SETUP_ROWS_Y, h);
        if (round) {
            // steps only, they start at the top of the window
            tw = rx(RND_TEXT_R, w, h) - rx(RND_TEXT_X, w, h);
            winTop = ry(RND_WIN_TOP, w, h);
            y = winTop + rp(6, w, h);
        }
        var lineH = dc.getFontHeight(Graphics.FONT_XTINY);
        var list = POP_STEPS[POP_BAD_IP] as Array<String>;
        for (var i = 0; i < list.size(); i++) {
            // room for 8 lines so nothing's cut
            var fit = Graphics.fitTextToArea(list[i], Graphics.FONT_XTINY, tw, lineH * 8, false);
            var text = fit != null ? fit : list[i];
            var lines = 1;
            var chars = text.toCharArray();
            for (var j = 0; j < chars.size(); j++) {
                if (chars[j] == '\n') {
                    lines++;
                }
            }
            stepText.add(text);
            stepY.add(y);
            y += lines * lineH + ph(6, w, h);
        }
        var bottom = y + ph(SETUP_GAP, w, h);
        areaBottom = round ? ry(RND_WIN_BOT, w, h) : hy(ONB_BTN_Y - SETUP_GAP, h);
        maxOffset = bottom > areaBottom ? bottom - areaBottom : 0;
        wrapped = true;
    }

    hidden function drawSetup(dc as Graphics.Dc, w as Number, h as Number) as Void {
        if (!wrapped) {
            layout(dc, w, h);
        }
        // pop-up open: everything dim, no chevrons
        var dim = popup != null;
        var tileBg = dim ? COL_TILE_BG_DIM : COL_TILE_BG;
        var tileIcon = dim ? COL_TILE_ICON_DIM : COL_TILE_ICON;
        var ink = dim ? COL_TEXT_DIM : COL_TEXT;

        // violet tile with a little tv drawn from shapes. round: pinned,
        // only the steps scroll
        var top = round ? 0 : offset;
        var tx = hx(TILE_X, w);
        var ty = hy(TILE_Y, h) - top;
        var tw = hx(TILE_X + TILE, w) - tx;
        var th = hy(TILE_Y + TILE, h) - ty;
        if (round) {
            tx = rx(RND_TILE_X, w, h);
            ty = ry(RND_TILE_Y, w, h);
            tw = rp(RND_TILE, w, h);
            th = tw;
        }
        dc.setColor(tileBg, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(tx, ty, tw, th, pr(TILE_R, w, h));
        var cx = tx + tw / 2;
        var cy = ty + th / 2 - pr(3, w, h);
        var sw = pr(28, w, h);
        var sh = pr(19, w, h);
        var e = pr(3, w, h);
        dc.setColor(tileIcon, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - sw / 2, cy - sh / 2, sw, sh, pr(4, w, h));
        dc.setColor(tileBg, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - sw / 2 + e, cy - sh / 2 + e, sw - e * 2, sh - e * 2, pr(2, w, h));
        dc.setColor(tileIcon, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - pr(7, w, h), cy + sh / 2 + e, pr(14, w, h), e); // stand

        var title = "Set up your Roku";
        var titleY = round ? ry(RND_TITLE_Y, w, h) : hy(SETUP_TITLE_Y, h) - offset;
        var titleW = round ? rp(RND_TITLE_W, w, h) : hx(280, w);
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, titleY, fitFont(dc, title, titleW), title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // numbered rows, stacked by their real height. round: clipped to
        // the window so no line reaches the round edge
        if (round) {
            dc.setClip(0, winTop, w, areaBottom - winTop);
        }
        var lineH = dc.getFontHeight(Graphics.FONT_XTINY);
        var nx = round ? rx(RND_NUM_X, w, h) : hx(SETUP_NUM_X, w);
        var textX = round ? rx(RND_TEXT_X, w, h) : hx(SETUP_TEXT_X, w);
        for (var i = 0; i < stepText.size(); i++) {
            var y = stepY[i] - offset;
            var ny = y + lineH / 2;
            dc.setColor(dim ? COL_BTN_DIM : COL_BTN, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(nx, ny, pr(SETUP_NUM_R, w, h));
            dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
            dc.drawText(nx, ny, Graphics.FONT_XTINY, (i + 1).toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(dim ? COL_SOFT_TEXT_DIM : COL_SOFT_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(textX, y, Graphics.FONT_XTINY, stepText[i], Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (round) {
            dc.clearClip();
            drawRoundPills(dc, w, h, dim);
            dc.setColor(COL_BG, COL_BG);
            dc.fillRectangle(0, areaBottom, w, h - areaBottom);
            drawButton(dc, w, h, "Check again", true, dim);
            return;
        }

        // shared chevron pills (HelpView.mc), only while there's more that
        // way. down sits just above the button strip, up at the top
        var half = PILL_H / 2;
        if (!dim && offset < maxOffset) {
            var downY = areaBottom - hy(PILL_PAD + half, h);
            drawChevPill(dc, downY, 1, downY - hy(half + PILL_PAD, h), areaBottom);
        }
        if (!dim && offset > 0) {
            var upY = hy(PILL_PAD + half, h);
            drawChevPill(dc, upY, -1, 0, upY + hy(half + PILL_PAD, h));
        }

        // pinned: black strip so scrolled content slides under the button
        dc.setColor(COL_BG, COL_BG);
        dc.fillRectangle(0, areaBottom, w, h - areaBottom);
        drawButton(dc, w, h, "Check again", true, dim);
    }

    hidden function drawType(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var list = cards();
        for (var i = 0; i < list.size(); i++) {
            var c = list[i];
            var x = px(c[0], w, h);
            var y = py(c[1], w, h);
            var cw = px(c[0] + c[2], w, h) - x;
            var ch = py(c[1] + c[3], w, h) - y;
            var r = pr(TYPE_CARD_R, w, h);
            // edge colour full size, then the fill inside it. picked = thicker violet edge
            var on = i == picked;
            var e = pr(on ? 3 : 2, w, h);
            dc.setColor(on ? COL_ACCENT : COL_CARD_EDGE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, cw, ch, r);
            dc.setColor(COL_BTN, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + e, y + e, cw - e * 2, ch - e * 2, r - e);

            // title in the upper half, subtitle in the lower, 8 px padding.
            // fonts picked by real height so both fit. subtitle goes one more
            // size down from what fits, so it has room to spare (xtiny at least)
            var lx = x + pw(20, w, h);
            var maxW = cw - pw(40, w, h);
            var pad = ph(round ? RND_CARD_PAD : 8, w, h);
            var half = (ch - pad * 2) / 2;
            var ti = fitBox(dc, TYPE_TITLES[i], maxW, half, 0);
            var si = fitBox(dc, TYPE_SUBS[i], maxW, half, ti + 1) + 1;
            if (si >= FIT_FONTS.size()) {
                si = FIT_FONTS.size() - 1;
            }
            dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lx, y + pad + half / 2, FIT_FONTS[ti] as Graphics.FontDefinition, TYPE_TITLES[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(COL_SOFT_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lx, y + pad + half + half / 2, FIT_FONTS[si] as Graphics.FontDefinition, TYPE_SUBS[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        drawButton(dc, w, h, "Continue", picked >= 0, false);

        // help header: back arrow + title. becomes a device list later (home assistant)
        drawHeader(dc, "Which device?");
    }

    // round pills (shared, round-sized): down at the bottom of the window,
    // up at its top. only while there's more that way, never behind the pop-up
    hidden function drawRoundPills(dc as Graphics.Dc, w as Number, h as Number, dim as Boolean) as Void {
        var strip = rp(PILL_H + PILL_PAD * 2, w, h);
        if (!dim && offset < maxOffset) {
            drawChevPill(dc, ry(RND_DOWN_Y, w, h), 1, areaBottom - strip, areaBottom);
        }
        if (!dim && offset > 0) {
            drawChevPill(dc, ry(RND_UP_Y, w, h), -1, winTop, winTop + strip);
        }
    }

    // pill at the bottom. off = grey and ignored. dim = behind the pop-up
    hidden function drawButton(dc as Graphics.Dc, w as Number, h as Number, label as String,
            on as Boolean, dim as Boolean) as Void {
        var b = btnRect();
        var x = px(b[0], w, h);
        var y = py(b[1], w, h);
        var bw = px(b[0] + b[2], w, h) - x;
        var bh = py(b[1] + b[3], w, h) - y;
        var fill = on ? (dim ? COL_ACCENT_DIM : COL_ACCENT) : COL_BTN;
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, bw, bh, bh / 2);
        // same label rule as the pop-up buttons: width - 24, height - 16, tiny at most
        var f = fitBox(dc, label, bw - pr(24, w, h), bh - pr(16, w, h), 1);
        dc.setColor(on && !dim ? COL_TEXT : COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + bw / 2, y + bh / 2, FIT_FONTS[f] as Graphics.FontDefinition, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class OnboardDelegate extends WatchUi.BehaviorDelegate {
    hidden var view as OnboardView;

    function initialize(v as OnboardView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        getRemoteApp().poke();
        var xy = evt.getCoordinates();
        view.tap(xy[0], xy[1]);
        return true;
    }

    // one step back, or the default (exit) on the first screen
    function onBack() as Boolean {
        getRemoteApp().poke();
        return view.back();
    }

    // up/down scroll the setup screen if it needs it. true for all so a
    // sloppy swipe can't close the app
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        getRemoteApp().poke();
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            view.scroll(1);
        } else if (dir == WatchUi.SWIPE_DOWN) {
            view.scroll(-1);
        }
        return true;
    }

    // same safety net as the help page, in case of page behaviours instead of swipes
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
}
