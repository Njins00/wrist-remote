import Toybox.Graphics;
import Toybox.Lang;

// page 2: rewind, play/pause, fast forward, then replay and options.
// swipe up from the remote. MainView draws it and sends the keys

// play first, it's the circle (same trick as OK on page 1)
const P2_KEYS = [KEY_PLAY, KEY_REV, KEY_FWD, KEY_REPLAY, KEY_INFO];

// square, 320x360 mockup px: x, y, w, h, radius. play is its circle's box.
// centred between the header (56) and 346
const P2_RECTS = [
    [121, 129, 78, 78, 39],
    [45, 133, 62, 70, 20],
    [213, 133, 62, 70, 20],
    [35, 223, 120, 50, 16],
    [165, 223, 120, 50, 16]
];

// round sizes, 416 mockup px: rev/fwd w, h, r, play, gap between them,
// bottom grid w, its gap, row h, row r, gap between the rows,
// header bottom, lowest y the grid fits the circle
const P2_RND = [62, 70, 20, 78, 12, 250, 10, 52, 18, 16, 80, 366];

// small round screens: nothing under these, screen px
const P2_MIN_SIDE_W = 44;
const P2_MIN_SIDE_H = 50;
const P2_MIN_PLAY = 54;
const P2_MIN_ROW_H = 44;
const P2_MIN_GAP = 4;

// page dots on the right edge, both pages: x, page 1 y, page 2 y, radius.
// mockup px, square then round. clear of page 1's rocker
const DOTS_SQ = [310, 172, 188, 3];
const DOTS_RND = [396, 200, 216, 4];
const DOT_MIN_R = 3; // round, so they don't vanish on 218
const COL_DOT_OFF = 0x5A6268;
const COL_DOT_OFF_DIM = 0x2D3134;

// icons are drawn for a 70 px tall side button and scale with it
const P2_ICON_REF = 70;

function p2Min(v as Number, m as Number) as Number {
    return v < m ? m : v;
}

// round layout in screen px, inside the sm circle at 0,0 (caller adds the
// offsets). scaled from 416, then the floors, then the block gets centred
function p2Round(sm as Number) as Array<Array<Number>> {
    var t = P2_RND;
    var sideW = p2Min(t[0] * sm / RND_MOCK, P2_MIN_SIDE_W);
    var sideH = p2Min(t[1] * sm / RND_MOCK, P2_MIN_SIDE_H);
    var sideR = p2Min(t[2] * sm / RND_MOCK, 1);
    var play = p2Min(t[3] * sm / RND_MOCK, P2_MIN_PLAY);
    var gap = p2Min(t[4] * sm / RND_MOCK, P2_MIN_GAP);
    var gridW = t[5] * sm / RND_MOCK;
    var gridGap = p2Min(t[6] * sm / RND_MOCK, P2_MIN_GAP);
    var rowW = (gridW - gridGap) / 2;
    var rowH = p2Min(t[7] * sm / RND_MOCK, P2_MIN_ROW_H);
    var rowR = p2Min(t[8] * sm / RND_MOCK, 1);
    var vGap = p2Min(t[9] * sm / RND_MOCK, 6);
    var hdr = t[10] * sm / RND_MOCK;
    var bot = t[11] * sm / RND_MOCK;

    var block = play + vGap + rowH;
    var top = (hdr + bot) / 2 - block / 2;
    if (top < hdr + 2) {
        top = hdr + 2;
    }
    var cx = sm / 2;
    var sideY = top + (play - sideH) / 2;
    var rowY = top + play + vGap;
    return [
        [cx - play / 2, top, play, play, play / 2],
        [cx - play / 2 - gap - sideW, sideY, sideW, sideH, sideR],
        [cx + play / 2 + gap, sideY, sideW, sideH, sideR],
        [cx - gridW / 2, rowY, rowW, rowH, rowR],
        [cx + gridW / 2 - rowW, rowY, rowW, rowH, rowR]
    ] as Array<Array<Number>>;
}

// design px (70 px button) -> screen px
function p2s(v as Number, q as Number) as Number {
    return v * q / P2_ICON_REF;
}

// pens never go under 1
function p2Pen(v as Number, q as Number) as Number {
    var p = p2s(v, q);
    return p < 1 ? 1 : p;
}

// icons for page 2, current colour, centred on cx,cy. q = side button height
function p2Icon(dc as Graphics.Dc, key as Number, cx as Number, cy as Number, q as Number) as Void {
    var a = p2s(11, q);
    var b = p2s(9, q);
    if (key == KEY_REV) {
        // two triangles pointing left
        dc.fillPolygon([[cx - a, cy], [cx, cy - b], [cx, cy + b]]);
        dc.fillPolygon([[cx, cy], [cx + a, cy - b], [cx + a, cy + b]]);
    } else if (key == KEY_FWD) {
        dc.fillPolygon([[cx + a, cy], [cx, cy - b], [cx, cy + b]]);
        dc.fillPolygon([[cx, cy], [cx - a, cy - b], [cx - a, cy + b]]);
    } else if (key == KEY_PLAY) {
        // triangle + two bars, a bit bigger than page 1's
        var s = p2s(12, q);
        var h = s * 3 / 4;
        dc.fillPolygon([[cx - s, cy - h], [cx - s, cy + h], [cx, cy]]);
        dc.fillRectangle(cx + s / 4, cy - h, s / 4 + 1, h * 2);
        dc.fillRectangle(cx + s * 3 / 4, cy - h, s / 4 + 1, h * 2);
    } else if (key == KEY_REPLAY) {
        // open circle going anticlockwise, head at 1 o'clock pointing back up
        dc.setPenWidth(p2Pen(3, q));
        dc.drawArc(cx, cy, p2s(10, q), Graphics.ARC_COUNTER_CLOCKWISE, 80, 30);
        dc.fillPolygon([[cx + p2s(6, q), cy - p2s(9, q)],
            [cx + p2s(13, q), cy - p2s(7, q)],
            [cx + p2s(5, q), cy - p2s(3, q)]]);
    } else if (key == KEY_INFO) {
        // roku's options star, three lines
        var dx = p2s(9, q);
        var dy = p2s(5, q);
        dc.setPenWidth(p2Pen(4, q));
        dc.drawLine(cx, cy - p2s(10, q), cx, cy + p2s(10, q));
        dc.drawLine(cx - dx, cy - dy, cx + dx, cy + dy);
        dc.drawLine(cx - dx, cy + dy, cx + dx, cy - dy);
    }
    dc.setPenWidth(1);
}
