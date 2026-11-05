import Toybox.Application;
import Toybox.Lang;

// settings page, opened from the gear. a plain list (ListView.mc).
// writes nothing, sends nothing

// keep in step with manifest.xml, connect iq can't read it
const APP_VERSION = "0.1.14";

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
            ["App version", APP_VERSION, false]
        ] as Array<Array>;
    }

    // device page comes in 7.1b
    function open(i as Number) as Void {
    }
}
