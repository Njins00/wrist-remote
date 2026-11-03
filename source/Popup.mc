import Toybox.Graphics;
import Toybox.Lang;

// error card drawn over whatever screen is up. that screen dims itself and
// passes taps in. OK closes it, How to fix opens the help page

enum {
    POP_NO_PHONE,
    POP_UNREACHABLE,
    POP_BAD_IP,
    POP_HTTP,
    POP_NO_IP
}

// what buttonAt() says
enum {
    POP_HIT_NONE,
    POP_HIT_OK,
    POP_HIT_FIX
}

// same order as the enum
const POP_TITLES = [
    "Phone not connected",
    "Can’t reach your Roku",
    "Set your Roku’s IP",
    "Phone blocks HTTP",
    "No valid home IP yet"
];

// help steps, same order. numbers get added when drawn. empty = OK only
const POP_STEPS = [
    [
        "Keep your phone nearby with Bluetooth on.",
        "Open Garmin Connect on your phone.",
        "Try the button again."
    ],
    [
        "Check the Roku is on and connected to home Wi-Fi.",
        "Your phone must be on the same Wi-Fi.",
        "On the Roku: Settings › System › Advanced system settings › Control by mobile apps › Network access › Enabled.",
        "Check the Roku’s IP in the app settings."
    ],
    [
        "On the Roku: Settings › Network › About, and note the IP address.",
        "On your phone: Connect IQ › Roku Remote › Settings.",
        "Enter the IP (and a room name if you like), then save."
    ],
    [
        "Your phone blocks plain web requests from watch apps.",
        "See the app’s store page for help."
    ],
    []
];

// mockup px. card height comes from the real title font (see draw)
const CARD_X = 20;
const CARD_W = 280;
const CARD_R = 24;
const CARD_EDGE = 2;
const CARD_PAD = 16;
const TITLE_PAD = 24;  // title room each side, inside the edge
const ICON_R = 22;
// full-width buttons inside the padding, OK on top
const POP_BTN_X = 38;
const POP_BTN_W = 244;
const POP_BTN_H = 42;
const POP_BTN_GAP = 8;

const COL_CARD_EDGE = 0x3A3F44;
const COL_WARN_BG = 0x2B2113;
const COL_WARN = 0xF2A93B;
const COL_SOFT_TEXT = 0xB9C1C6;

// biggest first. fitBox picks from here
const FIT_FONTS = [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];

// biggest of small / tiny / xtiny that fits maxW on one line
function fitFont(dc as Graphics.Dc, text as String, maxW as Number) as Graphics.FontDefinition {
    if (dc.getTextWidthInPixels(text, Graphics.FONT_SMALL) <= maxW) {
        return Graphics.FONT_SMALL;
    }
    if (dc.getTextWidthInPixels(text, Graphics.FONT_TINY) <= maxW) {
        return Graphics.FONT_TINY;
    }
    return Graphics.FONT_XTINY;
}

// biggest font from FIT_FONTS (starting at index start) that fits maxW and
// maxH. returns the index, ends at xtiny
function fitBox(dc as Graphics.Dc, text as String, maxW as Number, maxH as Number, start as Number) as Number {
    var last = FIT_FONTS.size() - 1;
    for (var i = start; i < last; i++) {
        var f = FIT_FONTS[i] as Graphics.FontDefinition;
        if (dc.getTextWidthInPixels(text, f) <= maxW && dc.getFontHeight(f) <= maxH) {
            return i;
        }
    }
    return last;
}

class Popup {
    hidden var kind as Number;
    hidden var fix as Boolean; // false = OK only, card is one button shorter
    // button top in mockup px, set by draw. default is just a safe guess
    hidden var btnY as Number = 200;

    // f false = no How to fix. kinds with no steps are always OK only
    function initialize(k as Number, f as Boolean) {
        kind = k;
        fix = f && (POP_STEPS[k] as Array).size() > 0;
    }

    function getKind() as Number {
        return kind;
    }

    // mx,my in mockup px. a bit of slack like the remote buttons
    function buttonAt(mx as Number, my as Number) as Number {
        if (mx < POP_BTN_X - SLACK || mx >= POP_BTN_X + POP_BTN_W + SLACK) {
            return POP_HIT_NONE;
        }
        if (!fix) {
            if (my >= btnY - SLACK && my < btnY + POP_BTN_H + SLACK) {
                return POP_HIT_OK;
            }
            return POP_HIT_NONE;
        }
        // the two areas meet in the middle of the gap
        var split = btnY + POP_BTN_H + POP_BTN_GAP / 2;
        if (my >= btnY - SLACK && my < split) {
            return POP_HIT_OK;
        }
        if (my >= split && my < btnY + POP_BTN_H * 2 + POP_BTN_GAP + SLACK) {
            return POP_HIT_FIX;
        }
        return POP_HIT_NONE;
    }

    // icon, title, buttons top to bottom, card centred. scales from the dc
    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // title must fit the card's real inner width, minus its side room
        var title = POP_TITLES[kind];
        var inner = hx(CARD_X + CARD_W - CARD_EDGE - TITLE_PAD, w) - hx(CARD_X + CARD_EDGE + TITLE_PAD, w);
        var tfont = fitFont(dc, title, inner);
        var th = dc.getFontHeight(tfont) * MOCK_H / h;

        // heights in mockup px
        var btns = fix ? POP_BTN_H * 2 + POP_BTN_GAP : POP_BTN_H;
        var ch = CARD_PAD + ICON_R * 2 + 12 + th + 16 + btns + CARD_PAD;
        var top = (MOCK_H - ch) / 2;
        if (top < 8) {
            top = 8;
        }
        var iconCy = top + CARD_PAD + ICON_R;
        var titleCy = top + CARD_PAD + ICON_R * 2 + 12 + th / 2;
        btnY = titleCy + th / 2 + 16;

        // card: edge colour full size, then the fill 2 px in
        var x = hx(CARD_X, w);
        var y = hy(top, h);
        var cw = hx(CARD_X + CARD_W, w) - x;
        var sh = hy(top + ch, h) - y;
        var e = hr(CARD_EDGE, w, h);
        dc.setColor(COL_CARD_EDGE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, cw, sh, hr(CARD_R, w, h));
        dc.setColor(COL_BTN, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + e, y + e, cw - e * 2, sh - e * 2, hr(CARD_R - CARD_EDGE, w, h));

        // amber circle with a drawn "!" so we don't need the glyph
        var cx = hx(160, w);
        var cy = hy(iconCy, h);
        dc.setColor(COL_WARN_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, hr(ICON_R, w, h));
        dc.setColor(COL_WARN, Graphics.COLOR_TRANSPARENT);
        var bw = hr(5, w, h);
        dc.fillRoundedRectangle(cx - bw / 2, cy - hr(12, w, h), bw, hr(14, w, h), bw / 2);
        dc.fillCircle(cx, cy + hr(8, w, h), hr(3, w, h));

        dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, hy(titleCy, h), tfont, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // labels fit width - 24 and height - 16, tiny at most. both use the
        // smaller font so they match
        var lw = hx(POP_BTN_X + POP_BTN_W, w) - hx(POP_BTN_X, w) - hr(24, w, h);
        var lh = hy(btnY + POP_BTN_H, h) - hy(btnY, h) - hr(16, w, h);
        var f = fitBox(dc, "OK", lw, lh, 1);
        if (fix) {
            var f2 = fitBox(dc, "How to fix", lw, lh, 1);
            if (f2 > f) {
                f = f2;
            }
        }
        var lfont = FIT_FONTS[f] as Graphics.FontDefinition;
        drawButton(dc, w, h, btnY, "OK", COL_ACCENT, false, lfont);
        if (fix) {
            drawButton(dc, w, h, btnY + POP_BTN_H + POP_BTN_GAP, "How to fix", COL_BTN, true, lfont);
        }
    }

    hidden function drawButton(dc as Graphics.Dc, sw as Number, sh as Number, my as Number, label as String,
            fill as Number, edged as Boolean, font as Graphics.FontDefinition) as Void {
        var x = hx(POP_BTN_X, sw);
        var y = hy(my, sh);
        var w = hx(POP_BTN_X + POP_BTN_W, sw) - x;
        var h = hy(my + POP_BTN_H, sh) - y;
        if (edged) {
            // dark on dark, the edge makes it read as a button
            var e = hr(CARD_EDGE, sw, sh);
            dc.setColor(COL_CARD_EDGE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, h, h / 2);
            dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + e, y + e, w - e * 2, h - e * 2, h / 2 - e);
        } else {
            dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, h, h / 2);
        }
        dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w / 2, y + h / 2, font, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
