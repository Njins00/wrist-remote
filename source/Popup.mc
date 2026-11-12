import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

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
        "Check the IP on the watch: tap the gear, then Device."
    ],
    [
        "On the Roku: Settings › Network › About, and note the IP address.",
        "On your phone, open the Connect IQ app.",
        "Device › My Device Apps › Wrist Remote › Settings.",
        "Enter the IP, then tap Save."
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
const TITLE_PAD = 32;  // message room each side, inside the edge
const ICON_R = 22;
// full-width buttons inside the padding, OK on top
const POP_BTN_X = 38;
const POP_BTN_W = 244;
const POP_BTN_H = 42;
const POP_BTN_GAP = 8;
// round, 416 px: card 58-358, buttons the same 18 px in. rest as above
const RND_CARD_X = 58;
const RND_CARD_W = 300;
const RND_BTN_X = 76;
const RND_BTN_W = 264;

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

// two lines, split at the space that makes the longer line shortest, both
// fitting maxW. if no split fits, word by word, as many lines as it takes.
// never cuts a word
function wrapTwo(dc as Graphics.Dc, text as String, font as Graphics.FontDefinition, maxW as Number) as Array<String> {
    var chars = text.toCharArray();
    var best = [] as Array<String>;
    var bestW = -1;
    for (var i = 0; i < chars.size(); i++) {
        if (chars[i] == ' ') {
            var a = text.substring(0, i) as String;
            var b = text.substring(i + 1, text.length()) as String;
            var wa = dc.getTextWidthInPixels(a, font);
            var wb = dc.getTextWidthInPixels(b, font);
            var longer = wa > wb ? wa : wb;
            if (longer <= maxW && (bestW < 0 || longer < bestW)) {
                best = [a, b] as Array<String>;
                bestW = longer;
            }
        }
    }
    if (bestW >= 0) {
        return best;
    }

    var lines = [] as Array<String>;
    var line = "";
    var rest = text;
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
        if (line.length() > 0 && dc.getTextWidthInPixels(next, font) > maxW) {
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

class Popup {
    hidden var kind as Number;
    hidden var fix as Boolean; // false = OK only, card is one button shorter
    // button top in mockup px, set by draw. default is just a safe guess
    hidden var btnY as Number = 200;
    // message font and lines, worked out on the first draw (needs a dc)
    hidden var laid as Boolean = false;
    hidden var tfont as Graphics.FontDefinition = Graphics.FONT_XTINY;
    hidden var lines as Array<String> = [] as Array<String>;
    // round: 416 px numbers, card and buttons from the RND_ consts
    hidden var round as Boolean;
    hidden var cardX as Number = CARD_X;
    hidden var cardW as Number = CARD_W;
    hidden var btnX as Number = POP_BTN_X;
    hidden var btnW as Number = POP_BTN_W;
    // screen size, for mapping taps
    hidden var tapW as Number;
    hidden var tapH as Number;

    // f false = no How to fix. kinds with no steps are always OK only
    function initialize(k as Number, f as Boolean) {
        kind = k;
        fix = f && (POP_STEPS[k] as Array).size() > 0;
        round = isRound();
        if (round) {
            cardX = RND_CARD_X;
            cardW = RND_CARD_W;
            btnX = RND_BTN_X;
            btnW = RND_BTN_W;
        }
        var ds = System.getDeviceSettings();
        tapW = ds.screenWidth;
        tapH = ds.screenHeight;
    }

    function getKind() as Number {
        return kind;
    }

    // mockup px -> screen px, 320x360 on square, the 416 circle on round
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

    // x,y in screen px. mapped the same way the card is drawn: 320x360 on
    // square, the 416 circle on round. a bit of slack like the remote buttons
    function buttonAt(x as Number, y as Number) as Number {
        var mx = x * MOCK_W / tapW;
        var my = y * MOCK_H / tapH;
        if (round) {
            var m = tapW < tapH ? tapW : tapH;
            mx = (x - (tapW - m) / 2) * RND_MOCK / m;
            my = (y - (tapH - m) / 2) * RND_MOCK / m;
        }
        if (mx < btnX - SLACK || mx >= btnX + btnW + SLACK) {
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

    // message: one line in the biggest font that really fits the room
    // (32 px each side inside the edge), else xtiny on two lines
    hidden function layoutTitle(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var title = POP_TITLES[kind];
        var inner = px(cardX + cardW - CARD_EDGE - TITLE_PAD, w, h) - px(cardX + CARD_EDGE + TITLE_PAD, w, h);
        laid = true;
        for (var i = 0; i < FIT_FONTS.size(); i++) {
            var f = FIT_FONTS[i] as Graphics.FontDefinition;
            if (dc.getTextWidthInPixels(title, f) <= inner) {
                tfont = f;
                lines = [title] as Array<String>;
                return;
            }
        }
        tfont = Graphics.FONT_XTINY;
        lines = wrapTwo(dc, title, tfont, inner);
    }

    // icon, message, buttons top to bottom, card centred. scales from the dc.
    // card grows if the message wraps
    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        tapW = w;
        tapH = h;
        if (!laid) {
            layoutTitle(dc, w, h);
        }
        var lineH = dc.getFontHeight(tfont);
        // round: 416 px per short side
        var mockH = MOCK_H;
        var scrH = h;
        if (round) {
            mockH = RND_MOCK;
            scrH = w < h ? w : h;
        }
        var th = lines.size() * lineH * mockH / scrH;

        // heights in mockup px
        var btns = fix ? POP_BTN_H * 2 + POP_BTN_GAP : POP_BTN_H;
        var ch = CARD_PAD + ICON_R * 2 + 12 + th + 16 + btns + CARD_PAD;
        var top = (mockH - ch) / 2;
        if (top < 8) {
            top = 8;
        }
        var iconCy = top + CARD_PAD + ICON_R;
        var titleCy = top + CARD_PAD + ICON_R * 2 + 12 + th / 2;
        btnY = titleCy + th / 2 + 16;

        // card: edge colour full size, then the fill 2 px in
        var x = px(cardX, w, h);
        var y = py(top, w, h);
        var cw = px(cardX + cardW, w, h) - x;
        var sh = py(top + ch, w, h) - y;
        var e = pr(CARD_EDGE, w, h);
        dc.setColor(COL_CARD_EDGE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, cw, sh, pr(CARD_R, w, h));
        dc.setColor(COL_BTN, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + e, y + e, cw - e * 2, sh - e * 2, pr(CARD_R - CARD_EDGE, w, h));

        // amber circle with a drawn "!" so we don't need the glyph
        var cx = px(cardX + cardW / 2, w, h);
        var cy = py(iconCy, w, h);
        dc.setColor(COL_WARN_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, pr(ICON_R, w, h));
        dc.setColor(COL_WARN, Graphics.COLOR_TRANSPARENT);
        var bw = pr(5, w, h);
        dc.fillRoundedRectangle(cx - bw / 2, cy - pr(12, w, h), bw, pr(14, w, h), bw / 2);
        dc.fillCircle(cx, cy + pr(8, w, h), pr(3, w, h));

        // one line at a time, the block centred where the title goes
        dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
        var ty = py(titleCy, w, h) - lines.size() * lineH / 2 + lineH / 2;
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(cx, ty + i * lineH, tfont, lines[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // labels fit width - 24 and height - 16, tiny at most. both use the
        // smaller font so they match
        var lw = px(btnX + btnW, w, h) - px(btnX, w, h) - pr(24, w, h);
        var lh = py(btnY + POP_BTN_H, w, h) - py(btnY, w, h) - pr(16, w, h);
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

    // mockup px -> screen px, then the shared pill
    hidden function drawButton(dc as Graphics.Dc, sw as Number, sh as Number, my as Number, label as String,
            fill as Number, edged as Boolean, font as Graphics.FontDefinition) as Void {
        var x = px(btnX, sw, sh);
        var y = py(my, sw, sh);
        var w = px(btnX + btnW, sw, sh) - x;
        var h = py(my + POP_BTN_H, sw, sh) - y;
        drawPill(dc, [x, y, w, h, pr(CARD_EDGE, sw, sh)] as Array<Number>, label, fill, edged, font);
    }
}

// pill button. box = [x, y, w, h, edge width], screen px. pop-up and tip
// screen both use it. box array keeps it under api 3's 9 arg limit
function drawPill(dc as Graphics.Dc, box as Array<Number>, label as String, fill as Number,
        edged as Boolean, font as Graphics.FontDefinition) as Void {
    var x = box[0];
    var y = box[1];
    var w = box[2];
    var h = box[3];
    var e = box[4];
    if (edged) {
        // dark on dark, the edge makes it read as a button
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
