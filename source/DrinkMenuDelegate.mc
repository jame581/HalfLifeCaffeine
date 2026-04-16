using Toybox.WatchUi;
using Toybox.Application;

class DrinkMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var presetIndex = item.getId() as Number;
        var app = Application.getApp() as HalfLifeCaffeineApp;
        app.logDrink(presetIndex);

        // Pop back to summary
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
