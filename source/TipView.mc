import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// tip jar: ko-fi qr, open on phone, not now. shows once at 30/150/500 sends
// and anytime from settings. the only link the app ever hands the phone

const TIP_URL = "https://ko-fi.com/njinsapps"; // fixed, never built from anything

// mockup px: text top, title x, title w, button 1 x, y, w, button 2 x, y, w,
// button h, min gap round the qr. the sub line is always xtiny, measured to fit
// square: 38 px pills and 8 px gaps so the qr isn't jammed in (venusq2:
// text 8-86, qr box 95-248, buttons 258-296 and 304-342)
const TIP_SQ = [8, 20, 280, 38, 258, 244, 38, 304, 244, 38, 8];
// round 416: title room stays inside the circle at y 52, button 2 is
// narrower so its ends clear the edge (14 px spare)
const TIP_RND = [52, 88, 240, 76, 284, 264, 96, 334, 224, 42, 4];
const TIP_BTN_GAP = 8;
const TIP_QR_PAD = 4;  // white round the qr's own margin
const TIP_QR_R = 8;

const COL_QR_BG = 0xFFFFFF;

enum {
    TIP_IDLE,
    TIP_SENT,
    TIP_NO_PHONE
}

// what buttonAt() says
enum {
    TIP_HIT_NONE,
    TIP_HIT_OPEN,
    TIP_HIT_CLOSE
}

class TipView extends WatchUi.View {
    hidden var state as Number = TIP_IDLE;
    hidden var round as Boolean;
    hidden var lay as Array<Number>;
    hidden var qr as WatchUi.BitmapResource or Null = null;

    function initialize() {
        View.initialize();
        round = isRound();
        lay = round ? TIP_RND : TIP_SQ;
    }

    // only held while the screen is up
    function onShow() as Void {
        getRemoteApp().poke();
        qr = WatchUi.loadResource(Rez.Drawables.QrKofi) as WatchUi.BitmapResource;
    }

    function onHide() as Void {
        qr = null;
    }

    // mockup px -> screen px, same as the pop-up
    hidden function px(v as Number, w as Number, h as Number) as Number {
        return round ? rx(v, w, h) : hx(v, w);
    }

    hidden function py(v as Number, w as Number, h as Number) as Number {
        return round ? ry(v, w, h) : hy(v, h);
    }

    hidden function pr(v as Number, w as Number, h as Number) as Number {
        if (round) {
            var r = rp(v, w, h);
            return r < 1 ? 1 : r;
        }
        return hr(v, w, h);
    }

    // not now / done / back key / swipe right
    function back() as Void {
        getRemoteApp().up();
    }

    // only on a tap. no phone = nothing sent, the qr still works
    function openOnPhone() as Void {
        if (!System.getDeviceSettings().phoneConnected) {
            state = TIP_NO_PHONE;
        } else {
            Communications.openWebPage(TIP_URL, null, null);
            state = TIP_SENT;
        }
        WatchUi.requestUpdate();
    }

    // x,y in screen px, mapped like the pop-up. buttons split in the gap
    function buttonAt(x as Number, y as Number) as Number {
        var ds = System.getDeviceSettings();
        var w = ds.screenWidth;
        var h = ds.screenHeight;
        var mx = x * MOCK_W / w;
        var my = y * MOCK_H / h;
        if (round) {
            var m = w < h ? w : h;
            mx = (x - (w - m) / 2) * RND_MOCK / m;
            my = (y - (h - m) / 2) * RND_MOCK / m;
        }
        var split = lay[4] + lay[9] + TIP_BTN_GAP / 2;
        if (my >= lay[4] - SLACK && my < split &&
            mx >= lay[3] - SLACK && mx < lay[3] + lay[5] + SLACK) {
            return TIP_HIT_OPEN;
        }
        if (my >= split && my < lay[7] + lay[9] + SLACK &&
            mx >= lay[6] - SLACK && mx < lay[6] + lay[8] + SLACK) {
            return TIP_HIT_CLOSE;
        }
        return TIP_HIT_NONE;
    }

    function tap(x as Number, y as Number) as Void {
        var hit = buttonAt(x, y);
        if (hit == TIP_HIT_OPEN) {
            openOnPhone();
        } else if (hit == TIP_HIT_CLOSE) {
            back();
        }
    }

    // title + sub from the top, qr centred in what's left above the buttons,
    // all from the real fonts and the real bitmap so nothing gets cut
    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(COL_BG, COL_BG);
        dc.clear();

        var sub = "Tips keep it free.";
        if (state == TIP_SENT) {
            sub = "Check your phone.";
        } else if (state == TIP_NO_PHONE) {
            sub = "No phone link.";
        }
        var bmp = qr;
        var qs = bmp != null ? bmp.getWidth() : 0;
        var box = qs + pr(TIP_QR_PAD, w, h) * 2;
        var gap = pr(lay[10], w, h);

        var top = py(lay[0], w, h);
        var btnTop = py(lay[4], w, h);
        var subH = dc.getFontHeight(Graphics.FONT_XTINY);
        // title gets whatever height the qr and sub line leave
        var roomH = btnTop - top - subH - box - gap * 2;
        var titleW = px(lay[1] + lay[2], w, h) - px(lay[1], w, h);
        var tf = FIT_FONTS[fitBox(dc, "Enjoying it?", titleW, roomH, 0)] as Graphics.FontDefinition;
        var titleH = dc.getFontHeight(tf);
        var cx = w / 2;
        var just = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top + titleH / 2, tf, "Enjoying it?", just);
        dc.setColor(COL_SOFT_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top + titleH + subH / 2, Graphics.FONT_XTINY, sub, just);

        // white box, then the qr (it has its own quiet zone) on top
        var textBot = top + titleH + subH;
        var by = textBot + (btnTop - textBot - box) / 2;
        var bx = cx - box / 2;
        if (bmp != null) {
            dc.setColor(COL_QR_BG, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx, by, box, box, pr(TIP_QR_R, w, h));
            dc.drawBitmap(bx + (box - qs) / 2, by + (box - qs) / 2, bmp);
        }

        // labels fit width - 24 and height - 16, from tiny down (never small),
        // both the same font
        var close = state == TIP_SENT ? "Done" : "Not now";
        var lw = px(lay[6] + lay[8], w, h) - px(lay[6], w, h) - pr(24, w, h);
        var lh = py(lay[4] + lay[9], w, h) - btnTop - pr(16, w, h);
        var f = fitBox(dc, "Open on phone", lw, lh, 1);
        var f2 = fitBox(dc, close, lw, lh, 1);
        if (f2 > f) {
            f = f2;
        }
        var lf = FIT_FONTS[f] as Graphics.FontDefinition;
        pill(dc, w, h, lay[3], lay[4], lay[5], "Open on phone", COL_ACCENT, false, lf);
        pill(dc, w, h, lay[6], lay[7], lay[8], close, COL_BTN, true, lf);
    }

    // mockup px -> screen px, then the pop-up's pill (drawPill in Popup.mc)
    hidden function pill(dc as Graphics.Dc, sw as Number, sh as Number, mx as Number, my as Number, mw as Number,
            label as String, fill as Number, edged as Boolean, font as Graphics.FontDefinition) as Void {
        var x = px(mx, sw, sh);
        var y = py(my, sw, sh);
        var w = px(mx + mw, sw, sh) - x;
        var h = py(my + lay[9], sw, sh) - y;
        drawPill(dc, x, y, w, h, pr(CARD_EDGE, sw, sh), label, fill, edged, font);
    }
}

class TipDelegate extends WatchUi.BehaviorDelegate {
    hidden var view as TipView;

    function initialize(v as TipView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        getRemoteApp().poke();
        var xy = evt.getCoordinates();
        view.tap(xy[0], xy[1]);
        return true;
    }

    // right goes back, the rest do nothing
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        getRemoteApp().poke();
        if (evt.getDirection() == WatchUi.SWIPE_RIGHT) {
            view.back();
        }
        return true;
    }

    function onBack() as Boolean {
        getRemoteApp().poke();
        view.back();
        return true;
    }
}
