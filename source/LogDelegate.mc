import Toybox.WatchUi;
import Toybox.System;

class LogDelegate extends WatchUi.BehaviorDelegate {

    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Watches whose UP/DOWN buttons carry the previousPage/nextPage behaviors
    // (fr255s, fenix 7, ...) call these first and pass the key on to onKey only
    // when they return false. Here the buttons move the cursor, so both decline
    // and swipes change page in onSwipe instead.
    function onPreviousPage() { return false; }
    function onNextPage() { return false; }

    // Finger down → back to timeline; finger up → history view.
    function onSwipe(swipeEvent) {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_DOWN) { showTimeline(); return true; }
        if (dir == WatchUi.SWIPE_UP)   { showHistory();  return true; }
        return false;
    }

    // UP/DOWN buttons move the cursor; past the first or last drink they page
    // on, so watches without touch still reach the timeline and history.
    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_UP) {
            if (isAtEnd(-1)) { showTimeline(); } else { _view.moveSelection(-1); }
            return true;
        }
        if (key == WatchUi.KEY_DOWN) {
            if (isAtEnd(1)) { showHistory(); } else { _view.moveSelection(1); }
            return true;
        }
        if (key == WatchUi.KEY_ENTER) {
            openSelected();
            return true;
        }
        return false;
    }

    // Tap a drink → its action menu.
    function onTap(clickEvent) {
        var idx = _view.indexAt(clickEvent.getCoordinates()[1], System.getDeviceSettings().screenHeight);
        if (idx >= 0) {
            _view.selectedIndex = idx;
            openSelected();
        }
        return true;
    }

    // True when the cursor cannot move further in direction (-1 up, 1 down).
    function isAtEnd(direction) {
        var count = _view.dayDoses.size();
        if (count == 0) { return true; }
        return (direction < 0) ? _view.selectedIndex <= 0 : _view.selectedIndex >= count - 1;
    }

    private function showTimeline() {
        WatchUi.switchToView(new TimelineView(), new TimelineDelegate(), WatchUi.SLIDE_DOWN);
    }

    private function showHistory() {
        var view = new HistoryView();
        WatchUi.switchToView(view, new HistoryDelegate(view), WatchUi.SLIDE_UP);
    }

    // A tap on a touch screen and the START button both reach onSelect first;
    // declining passes the tap to onTap (with its position) and START to
    // onKey as KEY_ENTER.
    function onSelect() { return false; }

    // Open the action menu for the highlighted drink.
    private function openSelected() {
        var doseIndex = _view.getSelectedDoseIndex();
        if (doseIndex < 0) { return; } // empty list — no-op

        var menu = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.MenuEditDrink)});
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.ItemEditTime), null, "edit_time", {}));
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.ItemDelete), null, "delete", {}));
        WatchUi.pushView(menu, new EditDrinkMenuDelegate(doseIndex), WatchUi.SLIDE_UP);
    }
}
