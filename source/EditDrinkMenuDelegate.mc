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
            var menu = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.MenuEditTime)});
            menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.OffsetMinus15m), null, -900,   {}));
            menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.OffsetMinus30m), null, -1800,  {}));
            menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.OffsetMinus1h),  null, -3600,  {}));
            menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.OffsetMinus2h),  null, -7200,  {}));
            menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.OffsetMinus3h),  null, -10800, {}));
            menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.OffsetPlus15m),  null, 900,    {}));
            menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.OffsetPlus30m),  null, 1800,   {}));
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
