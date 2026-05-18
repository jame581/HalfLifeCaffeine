import Toybox.WatchUi;

class LogDelegate extends WatchUi.BehaviorDelegate {

    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Swipe up (touch) → back to timeline
    function onPreviousPage() {
        WatchUi.switchToView(new TimelineView(), new TimelineDelegate(), WatchUi.SLIDE_DOWN);
        return true;
    }

    // Swipe down (touch) → history view
    function onNextPage() {
        var view = new HistoryView();
        WatchUi.switchToView(view, new HistoryDelegate(view), WatchUi.SLIDE_UP);
        return true;
    }

    // Non-touch UP/DOWN now drives the cursor on LogView, not page navigation.
    // Trade-off documented in spec: non-touch users leave LogView via BACK.
    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_UP)   { _view.moveSelection(-1); return true; }
        if (key == WatchUi.KEY_DOWN) { _view.moveSelection(1);  return true; }
        return false;
    }

    // SELECT → open action menu for the highlighted drink.
    function onSelect() {
        var doseIndex = _view.getSelectedDoseIndex();
        if (doseIndex < 0) { return true; } // empty list — no-op

        var menu = new WatchUi.Menu2({:title => "Edit Drink"});
        menu.addItem(new WatchUi.MenuItem("Edit time", null, "edit_time", {}));
        menu.addItem(new WatchUi.MenuItem("Delete", null, "delete", {}));
        WatchUi.pushView(menu, new EditDrinkMenuDelegate(doseIndex), WatchUi.SLIDE_UP);
        return true;
    }
}
