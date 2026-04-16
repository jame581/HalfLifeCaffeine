using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;

class DrinkMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var presetIndex = item.getId() as Number;
        var app = Application.getApp() as HalfLifeCaffeineApp;
        app.logDrink(presetIndex);

        // Confirmation vibration
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 200)]);
        }

        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
