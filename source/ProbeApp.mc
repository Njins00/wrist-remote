import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// throwaway probe: can the watch read roku device-info, and does a keypress
// come back as a success? not the real app.

const IDLE_MS = 300000; // 5 min with no taps, then back to the watch face

// button zones, in percent of screen height. drawing and tapping both use these
const BTN1_TOP = 52;
const BTN1_BOT = 72;
const BTN2_TOP = 76;
const BTN2_BOT = 96;

class ProbeApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new ProbeView();
        return [view, new ProbeDelegate(view)];
    }
}

// only 10.x, 172.16-31.x, 192.168.x. digits and dots only, 4 parts, 0-255
function isPrivateIp(s as String) as Boolean {
    if (s.length() < 7 || s.length() > 15) {
        return false;
    }
    var parts = [] as Array<Number>;
    var cur = 0;
    var digits = 0;
    var chars = s.toCharArray();
    for (var i = 0; i < chars.size(); i++) {
        var n = chars[i].toNumber();
        if (n == 46) { // '.'
            if (digits == 0) {
                return false;
            }
            parts.add(cur);
            cur = 0;
            digits = 0;
        } else if (n >= 48 && n <= 57) { // '0'-'9'
            digits++;
            cur = cur * 10 + (n - 48);
            if (digits > 3 || cur > 255) {
                return false;
            }
        } else {
            return false;
        }
    }
    if (digits == 0) {
        return false;
    }
    parts.add(cur);
    if (parts.size() != 4) {
        return false;
    }
    var a = parts[0];
    var b = parts[1];
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
}

// grab the text inside <name>...</name>, cut short. "?" if missing
function xmlTag(xml as String, name as String) as String {
    var open = "<" + name + ">";
    var i = xml.find(open);
    if (i == null) {
        return "?";
    }
    var rest = xml.substring(i + open.length(), xml.length());
    if (rest == null) {
        return "?";
    }
    var j = rest.find("</" + name + ">");
    if (j == null) {
        return "?";
    }
    var v = rest.substring(0, j);
    if (v == null) {
        return "?";
    }
    if (v.length() > 24) {
        v = v.substring(0, 24);
    }
    return v;
}

// the one place that talks to the roku. fixed actions only
module Roku {
    enum {
        DEVICE_INFO,
        PRESS_HOME
    }

    function send(action as Number, ip as String, cb as Method) as Void {
        var path;
        var verb;
        if (action == DEVICE_INFO) {
            path = "/query/device-info";
            verb = Communications.HTTP_REQUEST_METHOD_GET;
        } else if (action == PRESS_HOME) {
            path = "/keypress/Home";
            verb = Communications.HTTP_REQUEST_METHOD_POST;
        } else {
            return;
        }
        // text/plain so xml and empty bodies don't get parsed as json
        var opts = {
            :method => verb,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
        };
        Communications.makeWebRequest("http://" + ip + ":8060" + path, null, opts, cb);
    }
}

function errLabel(code as Number) as String {
    if (code == -1001) { return "Needs HTTPS"; }
    if (code == -400) { return "Bad body type"; }
    if (code == -402) { return "Reply too big"; }
    if (code == -403) { return "Out of memory"; }
    if (code == -104) { return "Phone not connected"; }
    if (code == -300) { return "Timed out"; }
    if (code > 0) { return "HTTP error"; }
    return "Error " + code;
}

class ProbeView extends WatchUi.View {
    var status as String = "Tap a button";
    var lines as Array<String> = [] as Array<String>;
    var busy as Boolean = false;
    var lastAction as Number = Roku.DEVICE_INFO;
    var idle as Timer.Timer;

    function initialize() {
        View.initialize();
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

    function press(action as Number) as Void {
        poke();
        if (busy) {
            return; // one request at a time
        }
        var ip = Application.Properties.getValue("rokuIp");
        if (!(ip instanceof String) || !isPrivateIp(ip)) {
            status = "Set a private IP";
            lines = ["in Garmin Connect settings"];
            WatchUi.requestUpdate();
            return;
        }
        busy = true;
        lastAction = action;
        status = "Sending...";
        lines = [];
        WatchUi.requestUpdate();
        Roku.send(action, ip, method(:onReply));
    }

    function onReply(code as Number, data) as Void {
        busy = false;
        status = "Code " + code;
        if (code == 200 && lastAction == Roku.DEVICE_INFO) {
            if (data instanceof String) {
                lines = [
                    "tv: " + xmlTag(data, "is-tv"),
                    "name: " + xmlTag(data, "user-device-name"),
                    "model: " + xmlTag(data, "model-name")
                ];
            } else {
                lines = ["200 but no text"];
            }
        } else if (code == 200) {
            var len = (data instanceof String) ? data.length() : 0;
            lines = ["Home sent", "body: " + len + " chars"];
        } else {
            lines = [errLabel(code)];
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // result area
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 6 / 100, Graphics.FONT_SMALL, status, Graphics.TEXT_JUSTIFY_CENTER);
        var y = h * 18 / 100;
        var lh = dc.getFontHeight(Graphics.FONT_XTINY) + 2;
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(w / 2, y, Graphics.FONT_XTINY, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lh;
        }

        drawButton(dc, w, h, BTN1_TOP, BTN1_BOT, "Device info");
        drawButton(dc, w, h, BTN2_TOP, BTN2_BOT, "Press Home");
    }

    function drawButton(dc as Graphics.Dc, w as Number, h as Number, top as Number, bot as Number, label as String) as Void {
        var y1 = h * top / 100;
        var y2 = h * bot / 100;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(w * 10 / 100, y1, w * 80 / 100, y2 - y1, 12);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (y1 + y2) / 2, Graphics.FONT_SMALL, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class ProbeDelegate extends WatchUi.BehaviorDelegate {
    var view as ProbeView;

    function initialize(v as ProbeView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    // back button keeps the default: pops the view and exits
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var y = evt.getCoordinates()[1];
        var h = System.getDeviceSettings().screenHeight;
        if (y >= h * BTN1_TOP / 100 && y < h * BTN1_BOT / 100) {
            view.press(Roku.DEVICE_INFO);
        } else if (y >= h * BTN2_TOP / 100 && y < h * BTN2_BOT / 100) {
            view.press(Roku.PRESS_HOME);
        } else {
            view.poke();
        }
        return true;
    }
}
