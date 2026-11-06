import Toybox.Application;
import Toybox.Lang;

// settings page (from the gear) and the device page under it. plain lists
// (ListView.mc). they write nothing and send nothing, the picker saves

// keep in step with manifest.xml, connect iq can't read it
const APP_VERSION = "0.1.16";

class SettingsView extends ListView {
    function initialize() {
        ListView.initialize("Settings");
        load();
    }

    // device line: room name, else the ip (only a real home one), else not set.
    // "Devices" in v2
    function load() as Void {
        var sub = "Not set";
        var name = roomNameSet();
        if (name != null) {
            sub = name;
        } else if (homeIpSet()) {
            sub = Application.Properties.getValue("rokuIp") as String;
        }
        rows = [
            ["Device", sub, true],
            ["Tip jar", "Buy me a coffee", true],
            ["App version", APP_VERSION, false]
        ] as Array<Array>;
    }

    // app version has no chevron, so only 0 and 1 get here
    function open(i as Number) as Void {
        getRemoteApp().open(i == 0 ? PAGE_DEVICE : PAGE_TIP);
    }
}

// room name help. it shows in the remote's header, so keep it generic
const NAME_STEPS = [
    "On your phone, open the Connect IQ app.",
    "Device › My Device Apps › Roku Remote › Settings.",
    "Change Room name, then tap Save.",
    "Keep it generic, like Living room. No personal names."
];

// one roku: ip, name, type. v2 reuses this per device
class DeviceView extends ListView {
    function initialize() {
        ListView.initialize("Device");
        load();
    }

    // only a real home ip gets drawn
    function load() as Void {
        var ip = "Not set";
        if (homeIpSet()) {
            ip = Application.Properties.getValue("rokuIp") as String;
        }
        var name = roomNameSet();
        rows = [
            ["IP", ip, true],
            ["Name", name != null ? name : "Not set", true],
            ["Device type", TYPE_TITLES[deviceType()] as String, true]
        ] as Array<Array>;
    }

    function open(i as Number) as Void {
        var pages = [PAGE_IP, PAGE_NAME, PAGE_TYPE];
        getRemoteApp().open(pages[i] as Number);
    }
}
