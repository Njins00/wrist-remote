import Toybox.Graphics;
import Toybox.Lang;

// error card drawn over the remote. MainView owns it.
// OK closes it, How to fix opens the help page

enum {
    POP_NO_PHONE,
    POP_UNREACHABLE,
    POP_BAD_IP,
    POP_HTTP
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
    "Phone blocks HTTP"
];

// help steps, same order. numbers get added when drawn
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
        "Enter the IP and save."
    ],
    [
        "Your phone blocks plain web requests from watch apps.",
        "See the app’s store page for help."
    ]
];

// mockup px. card height comes from the real title font (see draw)
const CARD_X = 20;
const CARD_W = 280;
const CARD_R = 24;
const CARD_EDGE = 2;
const CARD_PAD = 16;
const ICON_R = 22;
// two full-width buttons inside the padding, OK on top
const POP_BTN_X = 38;
const POP_BTN_W = 244;
const POP_BTN_H = 42;
const POP_BTN_GAP = 8;

const COL_CARD_EDGE = 0x3A3F44;
const COL_WARN_BG = 0x2B2113;
const COL_WARN = 0xF2A93B;
const COL_SOFT_TEXT = 0xB9C1C6;

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

class Popup {
    hidden var kind as Number;
    // button top in mockup px, set by draw. default is just a safe guess
    hidden var btnY as Number = 200;

    function initialize(k as Number) {
        kind = k;
    }

    function getKind() as Number {
        return kind;
    }

    // mx,my in mockup px. a bit of slack like the remote buttons
    function buttonAt(mx as Number, my as Number) as Number {
        if (mx < POP_BTN_X - SLACK || mx >= POP_BTN_X + POP_BTN_W + SLACK) {
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

    // icon, title, buttons top to bottom, card centred
    function draw(dc as Graphics.Dc, v as MainView) as Void {
        var sh = v.sy(MOCK_H);

        // title must fit the card's real inner width
        var title = POP_TITLES[kind];
        var inner = v.sx(CARD_X + CARD_W - CARD_EDGE - CARD_PAD) - v.sx(CARD_X + CARD_EDGE + CARD_PAD);
        var tfont = fitFont(dc, title, inner);
        var th = dc.getFontHeight(tfont) * MOCK_H / sh;

        // heights in mockup px
        var h = CARD_PAD + ICON_R * 2 + 12 + th + 16 + POP_BTN_H * 2 + POP_BTN_GAP + CARD_PAD;
        var top = (MOCK_H - h) / 2;
        if (top < 8) {
            top = 8;
        }
        var iconCy = top + CARD_PAD + ICON_R;
        var titleCy = top + CARD_PAD + ICON_R * 2 + 12 + th / 2;
        btnY = titleCy + th / 2 + 16;

        // card: edge colour full size, then the fill 2 px in
        var x = v.sx(CARD_X);
        var y = v.sy(top);
        var w = v.sx(CARD_X + CARD_W) - x;
        var ch = v.sy(top + h) - y;
        var e = v.rs(CARD_EDGE);
        dc.setColor(COL_CARD_EDGE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, ch, v.rs(CARD_R));
        dc.setColor(COL_BTN, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + e, y + e, w - e * 2, ch - e * 2, v.rs(CARD_R - CARD_EDGE));

        // amber circle with a drawn "!" so we don't need the glyph
        var cx = v.sx(160);
        var cy = v.sy(iconCy);
        dc.setColor(COL_WARN_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, v.rs(ICON_R));
        dc.setColor(COL_WARN, Graphics.COLOR_TRANSPARENT);
        var bw = v.rs(5);
        dc.fillRoundedRectangle(cx - bw / 2, cy - v.rs(12), bw, v.rs(14), bw / 2);
        dc.fillCircle(cx, cy + v.rs(8), v.rs(3));

        dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, v.sy(titleCy), tfont, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // measure both labels, use the smaller font so they match
        var bwid = v.sx(POP_BTN_X + POP_BTN_W) - v.sx(POP_BTN_X) - v.rs(16);
        var f1 = fitFont(dc, "OK", bwid);
        var f2 = fitFont(dc, "How to fix", bwid);
        var lfont = dc.getFontHeight(f1) < dc.getFontHeight(f2) ? f1 : f2;
        drawButton(dc, v, btnY, "OK", COL_ACCENT, false, lfont);
        drawButton(dc, v, btnY + POP_BTN_H + POP_BTN_GAP, "How to fix", COL_BTN, true, lfont);
    }

    hidden function drawButton(dc as Graphics.Dc, v as MainView, my as Number, label as String,
            fill as Number, edged as Boolean, font as Graphics.FontDefinition) as Void {
        var x = v.sx(POP_BTN_X);
        var y = v.sy(my);
        var w = v.sx(POP_BTN_X + POP_BTN_W) - x;
        var h = v.sy(my + POP_BTN_H) - y;
        if (edged) {
            // dark on dark, the edge makes it read as a button
            var e = v.rs(CARD_EDGE);
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
