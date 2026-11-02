import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// app shell. the test grid below is temporary, 4.2 swaps in the real screen

const IDLE_MS = 300000; // 5 min with no taps, then back to the watch face

// grid area, in percent of screen height
const GRID_TOP = 28;
const GRID_BOT = 96;

// 3x3 test grid, left to right, top to bottom. -1 = empty cell
const GRID_KEYS = [
    KEY_BACK, KEY_UP, KEY_HOME,
    KEY_LEFT, KEY_SELECT, KEY_RIGHT,
    KEY_PLAY, KEY_DOWN, -1
];
const GRID_LABELS = [
    "Back", "Up", "Home",
    "Left", "OK", "Right",
    "Play", "Down", ""
];

class RemoteApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new TestView(new RokuConnector());
        return [view, new TestDelegate(view)];
    }
}

// room name from settings, "Roku" if blank, max 20 chars
function roomName() as String {
    var name = Application.Properties.getValue("roomName");
    if (!(name instanceof String) || name.length() == 0) {
        return "Roku";
    }
    if (name.length() > 20) {
        name = name.substring(0, 20);
    }
    return name as String;
}

class TestView extends WatchUi.View {
    var roku as RokuConnector;
    var status as String = "Tap a key";
    var lastLabel as String = "";
    var sentAt as Number = 0;
    var idle as Timer.Timer;

    function initialize(r as RokuConnector) {
        View.initialize();
        roku = r;
        idle = new Timer.Timer();
    }

    function onShow() as Void {
        poke();
    }

    function onHide() as Void {
        idle.stop();
    }

    // any tap resets the idle clock
    function poke() as Void {
        idle.stop();
        idle.start(method(:bail), IDLE_MS, false);
    }

    function bail() as Void {
        System.exit();
    }

    function tap(x as Number, y as Number) as Void {
        poke();
        var w = System.getDeviceSettings().screenWidth;
        var h = System.getDeviceSettings().screenHeight;
        var top = h * GRID_TOP / 100;
        var bot = h * GRID_BOT / 100;
        if (y < top || y >= bot) {
            return;
        }
        var col = x * 3 / w;
        var row = (y - top) * 3 / (bot - top);
        if (col > 2) { col = 2; }
        if (row > 2) { row = 2; }
        var cell = row * 3 + col;
        var key = GRID_KEYS[cell];
        if (key < 0) {
            return;
        }
        var label = GRID_LABELS[cell];
        // set "Sending" first, onResult can fire inside send() and must win
        var prevStatus = status;
        var prevLabel = lastLabel;
        var prevAt = sentAt;
        lastLabel = label;
        sentAt = System.getTimer();
        status = "Sending · " + label;
        var res = roku.send(key, method(:onResult));
        if (res == SEND_BAD_IP) {
            status = "Set a home IP in settings";
        } else if (res == SEND_NO_PHONE) {
            status = "Phone not connected";
        } else if (res != SEND_STARTED) {
            // busy, tap dropped. put things back for the request still in flight
            status = prevStatus;
            lastLabel = prevLabel;
            sentAt = prevAt;
        }
        WatchUi.requestUpdate();
    }

    function onResult(result as Number) as Void {
        var ms = System.getTimer() - sentAt;
        if (result == RESULT_SENT) {
            status = "Sent · " + lastLabel + "  " + ms + " ms";
        } else if (result == RESULT_NO_PHONE) {
            status = "Phone not connected";
        } else if (result == RESULT_TIMED_OUT) {
            status = "Can't reach Roku";
        } else if (result == RESULT_HTTP_BLOCKED) {
            status = "Phone blocks HTTP";
        } else {
            status = "Failed";
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 4 / 100, Graphics.FONT_SMALL, roomName(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_XTINY, status, Graphics.TEXT_JUSTIFY_CENTER);

        var top = h * GRID_TOP / 100;
        var bot = h * GRID_BOT / 100;
        var cw = w / 3;
        var ch = (bot - top) / 3;
        for (var i = 0; i < 9; i++) {
            if (GRID_KEYS[i] < 0) {
                continue;
            }
            var x = (i % 3) * cw;
            var y = top + (i / 3) * ch;
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + 3, y + 3, cw - 6, ch - 6, 10);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + cw / 2, y + ch / 2, Graphics.FONT_XTINY, GRID_LABELS[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}

class TestDelegate extends WatchUi.BehaviorDelegate {
    var view as TestView;

    function initialize(v as TestView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    // back button keeps the default: pops the view and exits
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var xy = evt.getCoordinates();
        view.tap(xy[0], xy[1]);
        return true;
    }
}
