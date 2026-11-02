import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// app shell. the remote screen lives in MainView.mc

class RemoteApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new MainView(new RokuConnector());
        return [view, new MainDelegate(view)];
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
