import Toybox.WatchUi;
import Toybox.System;

class DayDetailDelegate extends WatchUi.BehaviorDelegate {

    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // BACK pops back to HistoryView (default behavior, but make it explicit).
    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // UP/DOWN buttons and swipes scroll the drinks a page at a time; this
    // modal screen has no other page to go to.
    function onPreviousPage() {
        _view.scrollPage(-1, System.getDeviceSettings().screenHeight);
        return true;
    }

    function onNextPage() {
        _view.scrollPage(1, System.getDeviceSettings().screenHeight);
        return true;
    }

    // Watches whose UP/DOWN buttons carry no page behavior send raw keys.
    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_UP) { return onPreviousPage(); }
        if (key == WatchUi.KEY_DOWN) { return onNextPage(); }
        return false;
    }

    // Tap an arrow → scroll.
    function onTap(clickEvent) {
        var height = System.getDeviceSettings().screenHeight;
        var dir = _view.arrowAt(clickEvent.getCoordinates()[1], height);
        if (dir == 0) { return false; }
        _view.scrollPage(dir, height);
        return true;
    }
}
