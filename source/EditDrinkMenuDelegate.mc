import Toybox.WatchUi;
import Toybox.Application;

class EditDrinkMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _doseIndex;

    function initialize(doseIndex) {
        Menu2InputDelegate.initialize();
        _doseIndex = doseIndex;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id.equals("edit_time")) {
            var menu = new WatchUi.Menu2({:title => "Edit Time"});
            menu.addItem(new WatchUi.MenuItem("-15 min",   null, -900,    {}));
            menu.addItem(new WatchUi.MenuItem("-30 min",   null, -1800,   {}));
            menu.addItem(new WatchUi.MenuItem("-1 hour",   null, -3600,   {}));
            menu.addItem(new WatchUi.MenuItem("-2 hours",  null, -7200,   {}));
            menu.addItem(new WatchUi.MenuItem("-3 hours",  null, -10800,  {}));
            menu.addItem(new WatchUi.MenuItem("+15 min",   null, 900,     {}));
            menu.addItem(new WatchUi.MenuItem("+30 min",   null, 1800,    {}));
            WatchUi.pushView(menu, new EditTimeMenuDelegate(_doseIndex), WatchUi.SLIDE_UP);
        } else if (id.equals("delete")) {
            Application.getApp().removeDose(_doseIndex);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
