import Toybox.WatchUi;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

class SummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // SELECT button → open drink menu. Under each drink: its mg and the total
    // caffeine expected at the next bedtime if it is taken now.
    function onSelect() {
        var app = Application.getApp();
        var menu = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.MenuAddDrink)});
        var now = Time.now().value();
        var bedEpoch = Util.getBedtimeEpoch(now);
        var tplBed = WatchUi.loadResource(Rez.Strings.MenuBedPreview);
        for (var i = 0; i < app.drinkPresets.getPresetCount(); i++) {
            var preset = app.drinkPresets.getPresetAt(i);
            var sub = preset[:mg] + " mg";
            if (app.caffeineModel != null) {
                var bedMg = app.caffeineModel.getLevelWithDose(bedEpoch, preset[:mg], now);
                sub = Lang.format(tplBed, [preset[:mg], Util.formatMg(bedMg)]);
            }
            menu.addItem(new WatchUi.MenuItem(preset[:name], sub, i, {}));
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
