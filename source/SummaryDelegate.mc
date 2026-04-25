import Toybox.WatchUi;
import Toybox.Application;

class SummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // SELECT button → open drink menu
    function onSelect() {
        var app = Application.getApp();
        var menu = new WatchUi.Menu2({:title => "Add Drink"});
        for (var i = 0; i < app.drinkPresets.getPresetCount(); i++) {
            var preset = app.drinkPresets.getPresetAt(i);
            menu.addItem(new WatchUi.MenuItem(
                preset[:name],
                preset[:mg] + " mg",
                i,
                {}
            ));
        }
        WatchUi.pushView(menu, new DrinkMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    // Swipe down (touch) OR DOWN button (non-touch) → timeline view
    function onNextPage() {
        WatchUi.switchToView(new TimelineView(), new TimelineDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    // Some non-touch widgets (e.g. fenix 5 Plus without glance) don't
    // auto-route DOWN/UP buttons to onNextPage/onPreviousPage. Catch the
    // raw key events and dispatch manually.
    function onKey(keyEvent) {
        if (keyEvent.getKey() == WatchUi.KEY_DOWN) {
            return onNextPage();
        }
        return false;
    }
}
