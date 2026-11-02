import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Timer;

// the only place that talks to the roku. fixed keys only, nothing from free text

// keys we're allowed to send. order matches KEY_PATHS below
enum {
    KEY_UP,
    KEY_DOWN,
    KEY_LEFT,
    KEY_RIGHT,
    KEY_SELECT,
    KEY_BACK,
    KEY_HOME,
    KEY_PLAY,
    KEY_VOL_UP,
    KEY_VOL_DOWN,
    KEY_MUTE
}

// what send() says right away
enum {
    SEND_STARTED,
    SEND_BAD_IP,
    SEND_BUSY,
    SEND_BAD_KEY,
    SEND_NO_PHONE
}

// what comes back once the request is done
enum {
    RESULT_SENT,
    RESULT_NO_PHONE,
    RESULT_TIMED_OUT,
    RESULT_HTTP_BLOCKED,
    RESULT_FAILED
}

const KEY_PATHS = [
    "/keypress/Up",
    "/keypress/Down",
    "/keypress/Left",
    "/keypress/Right",
    "/keypress/Select",
    "/keypress/Back",
    "/keypress/Home",
    "/keypress/Play",
    "/keypress/VolumeUp", // tv only, sticks ignore volume
    "/keypress/VolumeDown",
    "/keypress/VolumeMute"
];

const REPLY_TIMEOUT_MS = 5000; // give up after 5 s, no retry

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

class RokuConnector {
    hidden var busy as Boolean = false;
    hidden var done as Method? = null;
    hidden var reqId as Number = 0;
    hidden var timer as Timer.Timer;

    function initialize() {
        timer = new Timer.Timer();
    }

    // fires one keypress. done gets a RESULT_* later, only if this returns SEND_STARTED
    function send(key as Number, cb as Method) as Number {
        if (key < 0 || key >= KEY_PATHS.size()) {
            return SEND_BAD_KEY;
        }
        if (busy) {
            return SEND_BUSY; // one at a time, extra taps get dropped
        }
        // check the ip every time, settings can change while we're open
        var ip = Application.Properties.getValue("rokuIp");
        if (!(ip instanceof String) || !isPrivateIp(ip)) {
            return SEND_BAD_IP;
        }
        // no phone, no point trying. web requests go through the phone
        if (!System.getDeviceSettings().phoneConnected) {
            return SEND_NO_PHONE;
        }
        busy = true;
        done = cb;
        reqId++;
        // text/plain so the empty reply isn't parsed as json. we never read it anyway
        var opts = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
        };
        // timer first, cb can fire before send() returns
        timer.start(method(:onTimeout), REPLY_TIMEOUT_MS, false);
        // we don't keep the RokuReply, only makeWebRequest holds it. no ref cycle
        Communications.makeWebRequest("http://" + ip + ":8060" + KEY_PATHS[key], null, opts,
            new RokuReply(self, reqId).method(:onReply));
        return SEND_STARTED;
    }

    // called by RokuReply. anything that isn't the current request gets dropped
    function reply(id as Number, responseCode as Number) as Void {
        if (!busy || id != reqId) {
            return;
        }
        timer.stop();
        busy = false;
        var result = RESULT_FAILED;
        if (responseCode == 200 || responseCode == -400) {
            result = RESULT_SENT; // -400 is the empty reply, the tv still got it
        } else if (responseCode == -104) {
            result = RESULT_NO_PHONE;
        } else if (responseCode == -300) {
            result = RESULT_TIMED_OUT;
        } else if (responseCode == -1001) {
            result = RESULT_HTTP_BLOCKED;
        }
        finish(result);
    }

    // roku took too long. bump the id first so a late reply gets ignored
    function onTimeout() as Void {
        if (!busy) {
            return;
        }
        reqId++;
        busy = false;
        Communications.cancelAllRequests();
        finish(RESULT_TIMED_OUT);
    }

    hidden function finish(result as Number) as Void {
        var cb = done;
        done = null;
        if (cb != null) {
            cb.invoke(result);
        }
    }
}

// one per request, remembers which one it was
class RokuReply {
    hidden var conn as RokuConnector;
    hidden var id as Number;

    function initialize(c as RokuConnector, i as Number) {
        conn = c;
        id = i;
    }

    // only the code matters, the body is ignored
    function onReply(responseCode as Number, data as Null or ByteArray or Dictionary or String or PersistedContent.Iterator) as Void {
        conn.reply(id, responseCode);
    }
}
