import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// app shell. the remote screen lives in MainView.mc

class RemoteApp extends Application.AppBase {
    hidden var view as MainView or Null = null; // kept so settings changes reach the view

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var v = new MainView(new RokuConnector());
        view = v;
        return [v, new MainDelegate(v)];
    }

    // settings edited in the phone app while we're open: new room name and
    // volume layout. the ip needs nothing, the connector reads it on every send
    function onSettingsChanged() as Void {
        var v = view;
        if (v != null) {
            v.refreshSettings();
        }
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
