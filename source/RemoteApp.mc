import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// app shell. the remote screen lives in MainView.mc, first run in Onboarding.mc

const IDLE_MS = 300000; // 5 min with no taps, then back to the watch face

class RemoteApp extends Application.AppBase {
    // whichever screen is up, so settings changes reach it
    hidden var view as MainView or Null = null;
    hidden var onboard as OnboardView or Null = null;
    hidden var roku as RokuConnector;
    hidden var idle as Timer.Timer; // one for the whole app, every screen pokes it

    function initialize() {
        AppBase.initialize();
        roku = new RokuConnector();
        idle = new Timer.Timer();
    }

    // remote if we're set up, otherwise onboarding (setup if no ip yet)
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        poke();
        var ipOk = homeIpSet();
        if (ipOk && isOnboarded()) {
            var v = new MainView(roku);
            view = v;
            return [v, new MainDelegate(v)];
        }
        var o = new OnboardView(ipOk ? STEP_TYPE : STEP_SETUP);
        onboard = o;
        return [o, new OnboardDelegate(o)];
    }

    // onboarding done, swap in the remote
    function showRemote() as Void {
        onboard = null;
        var v = new MainView(roku);
        view = v;
        WatchUi.switchToView(v, new MainDelegate(v), WatchUi.SLIDE_IMMEDIATE);
    }

    // settings edited in the phone app while we're open: new ip, room name or
    // volume layout. the connector reads the ip on every send
    function onSettingsChanged() as Void {
        var o = onboard;
        if (o != null) {
            o.refreshSettings();
            return;
        }
        var v = view;
        if (v != null) {
            v.refreshSettings();
        }
    }

    // any tap resets the idle clock
    function poke() as Void {
        idle.stop();
        idle.start(method(:bail), IDLE_MS, false);
    }

    function bail() as Void {
        System.exit();
    }
}

function getRemoteApp() as RemoteApp {
    return Application.getApp() as RemoteApp;
}

// a usable home ip in settings. same check the connector does
function homeIpSet() as Boolean {
    var ip = Application.Properties.getValue("rokuIp");
    return ip instanceof String && isPrivateIp(ip);
}

// set at the end of onboarding (5.4). watch only, never sent
function isOnboarded() as Boolean {
    var v = Application.Storage.getValue("onboarded");
    if (v instanceof Boolean) {
        return v;
    }
    return false;
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
