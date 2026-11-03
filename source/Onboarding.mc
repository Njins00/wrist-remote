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

    function initialize(s as Number) {
        View.initialize();
        step = s;
        first = s;
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
        offset += dir * areaBottom * 60 / 100;
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
        if (step == STEP_SETUP) {
            // button first, then the chevron zones (top/bottom 18% of the
            // area, only while that chevron shows)
            if (inBox(mx, my, ONB_BTN_X, ONB_BTN_Y, ONB_BTN_W, ONB_BTN_H)) {
                checkAgain();
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
        for (var i = 0; i < TYPE_CARDS.size(); i++) {
            var c = TYPE_CARDS[i];
            if (inBox(mx, my, c[0], c[1], c[2], c[3])) {
                picked = i;
                WatchUi.requestUpdate();
                return;
            }
        }
        if (inBox(mx, my, ONB_BTN_X, ONB_BTN_Y, ONB_BTN_W, ONB_BTN_H)) {
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
        var lineH = dc.getFontHeight(Graphics.FONT_XTINY);
        var list = POP_STEPS[POP_BAD_IP] as Array<String>;
        var y = hy(SETUP_ROWS_Y, h);
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
            y += lines * lineH + hy(6, h);
        }
        var bottom = y + hy(SETUP_GAP, h);
        areaBottom = hy(ONB_BTN_Y - SETUP_GAP, h);
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

        // violet tile with a little tv drawn from shapes
        var tx = hx(TILE_X, w);
        var ty = hy(TILE_Y, h) - offset;
        var tw = hx(TILE_X + TILE, w) - tx;
        var th = hy(TILE_Y + TILE, h) - ty;
        dc.setColor(tileBg, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(tx, ty, tw, th, hr(TILE_R, w, h));
        var cx = tx + tw / 2;
        var cy = ty + th / 2 - hr(3, w, h);
        var sw = hr(28, w, h);
        var sh = hr(19, w, h);
        var e = hr(3, w, h);
        dc.setColor(tileIcon, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - sw / 2, cy - sh / 2, sw, sh, hr(4, w, h));
        dc.setColor(tileBg, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - sw / 2 + e, cy - sh / 2 + e, sw - e * 2, sh - e * 2, hr(2, w, h));
        dc.setColor(tileIcon, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - hr(7, w, h), cy + sh / 2 + e, hr(14, w, h), e); // stand

        var title = "Set up your Roku";
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, hy(SETUP_TITLE_Y, h) - offset, fitFont(dc, title, hx(280, w)), title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // numbered rows, stacked by their real height
        var lineH = dc.getFontHeight(Graphics.FONT_XTINY);
        var nx = hx(SETUP_NUM_X, w);
        for (var i = 0; i < stepText.size(); i++) {
            var y = stepY[i] - offset;
            var ny = y + lineH / 2;
            dc.setColor(dim ? COL_BTN_DIM : COL_BTN, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(nx, ny, hr(SETUP_NUM_R, w, h));
            dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
            dc.drawText(nx, ny, Graphics.FONT_XTINY, (i + 1).toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(dim ? COL_SOFT_TEXT_DIM : COL_SOFT_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(hx(SETUP_TEXT_X, w), y, Graphics.FONT_XTINY, stepText[i], Graphics.TEXT_JUSTIFY_LEFT);
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
        for (var i = 0; i < TYPE_CARDS.size(); i++) {
            var c = TYPE_CARDS[i];
            var x = hx(c[0], w);
            var y = hy(c[1], h);
            var cw = hx(c[0] + c[2], w) - x;
            var ch = hy(c[1] + c[3], h) - y;
            var r = hr(TYPE_CARD_R, w, h);
            // edge colour full size, then the fill inside it. picked = thicker violet edge
            var on = i == picked;
            var e = hr(on ? 3 : 2, w, h);
            dc.setColor(on ? COL_ACCENT : COL_CARD_EDGE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, cw, ch, r);
            dc.setColor(COL_BTN, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + e, y + e, cw - e * 2, ch - e * 2, r - e);

            // title in the upper half, subtitle in the lower, 8 px padding.
            // fonts picked by real height so both fit. subtitle goes one more
            // size down from what fits, so it has room to spare (xtiny at least)
            var lx = x + hx(20, w);
            var maxW = cw - hx(40, w);
            var pad = hy(8, h);
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

    // pill at the bottom. off = grey and ignored. dim = behind the pop-up
    hidden function drawButton(dc as Graphics.Dc, w as Number, h as Number, label as String,
            on as Boolean, dim as Boolean) as Void {
        var x = hx(ONB_BTN_X, w);
        var y = hy(ONB_BTN_Y, h);
        var bw = hx(ONB_BTN_X + ONB_BTN_W, w) - x;
        var bh = hy(ONB_BTN_Y + ONB_BTN_H, h) - y;
        var fill = on ? (dim ? COL_ACCENT_DIM : COL_ACCENT) : COL_BTN;
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, bw, bh, bh / 2);
        // same label rule as the pop-up buttons: width - 24, height - 16, tiny at most
        var f = fitBox(dc, label, bw - hr(24, w, h), bh - hr(16, w, h), 1);
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
