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

    // Swipe down → timeline view
    function onNextPage() {
        WatchUi.switchToView(new TimelineView(), new TimelineDelegate(), WatchUi.SLIDE_UP);
        return true;
    }
}
