import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// app shell. the remote screen lives in MainView.mc, first run in Onboarding.mc

const IDLE_MS = 300000; // 5 min with no taps, then back to the watch face

// pages on the settings path. back always goes up one level
enum {
    PAGE_REMOTE,
    PAGE_SETTINGS,
    PAGE_DEVICE,
    PAGE_IP,
    PAGE_NAME,
    PAGE_TYPE
}

class RemoteApp extends Application.AppBase {
    // whichever screen is up, so settings changes reach it
    hidden var view as MainView or Null = null;
    hidden var onboard as OnboardView or Null = null;
    // settings path: which page is up, and its view if it can refresh
    hidden var page as Number = PAGE_REMOTE;
    hidden var cur as WatchUi.View or Null = null;
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
        var o = new OnboardView(ipOk ? STEP_TYPE : STEP_SETUP, false);
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

    // a settings page takes the current one's place, so there's only ever
    // one view on the stack. each open reads the settings fresh
    function open(p as Number) as Void {
        page = p;
        cur = null;
        if (p == PAGE_SETTINGS || p == PAGE_DEVICE) {
            var l = (p == PAGE_SETTINGS ? new SettingsView() : new DeviceView()) as ListView;
            cur = l;
            WatchUi.switchToView(l, new ListDelegate(l), WatchUi.SLIDE_IMMEDIATE);
        } else if (p == PAGE_IP || p == PAGE_NAME) {
            var hv = new HelpView(HELP_PAGE);
            if (p == PAGE_IP) {
                hv.page("Roku IP", POP_STEPS[POP_BAD_IP] as Array<String>);
            } else {
                hv.page("Room name", NAME_STEPS as Array<String>);
            }
            WatchUi.switchToView(hv, new HelpDelegate(hv), WatchUi.SLIDE_IMMEDIATE);
        } else if (p == PAGE_TYPE) {
            // not kept as onboard, so settings changes still reach the remote
            var o = new OnboardView(STEP_TYPE, true);
            WatchUi.switchToView(o, new OnboardDelegate(o), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    // one level up: help pages and the picker -> device -> settings ->
    // the same remote, which reloads its mode in onShow
    function up() as Void {
        if (page == PAGE_IP || page == PAGE_NAME || page == PAGE_TYPE) {
            open(PAGE_DEVICE);
        } else if (page == PAGE_DEVICE) {
            open(PAGE_SETTINGS);
        } else if (page == PAGE_SETTINGS) {
            page = PAGE_REMOTE;
            cur = null;
            var v = view;
            if (v == null) {
                v = new MainView(roku);
                view = v;
            }
            WatchUi.switchToView(v, new MainDelegate(v), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    // settings edited in the phone app while we're open: new ip, room name or
    // volume layout. the connector reads the ip on every send
    function onSettingsChanged() as Void {
        var o = onboard;
        if (o != null) {
            o.refreshSettings();
            return;
        }
        var c = cur;
        if (c instanceof ListView) {
            c.refresh();
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
    var name = roomNameSet();
    return name != null ? name : "Roku";
}

// same, but null if blank. settings shows "Not set" instead
function roomNameSet() as String or Null {
    var name = Application.Properties.getValue("roomName");
    if (!(name instanceof String) || name.length() == 0) {
        return null;
    }
    if (name.length() > 20) {
        name = name.substring(0, 20);
    }
    return name as String;
}
