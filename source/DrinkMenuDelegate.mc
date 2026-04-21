import Toybox.WatchUi;
import Toybox.Application;
import Toybox.Attention;

class DrinkMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var presetIndex = item.getId();
        var app = Application.getApp();
        app.logDrink(presetIndex);

        // Confirmation vibration
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 200)]);
        }

        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
