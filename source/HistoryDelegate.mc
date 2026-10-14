import Toybox.WatchUi;
import Toybox.System;

class HistoryDelegate extends WatchUi.BehaviorDelegate {

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

    // Finger down → back to LogView. History is the last page, so a swipe up
    // is swallowed rather than falling off the end of the chain.
    function onSwipe(swipeEvent) {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_DOWN) { showLog(); return true; }
        return dir == WatchUi.SWIPE_UP;
    }

    // UP button → newer day (smaller index); on the newest day, back to LogView
    // so watches without touch can page back.
    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_UP) {
            if (isAtTop()) { showLog(); } else { _view.moveSelection(-1); }
            return true;
        }
        if (key == WatchUi.KEY_DOWN) {
            _view.moveSelection(1);
            return true;
        }
        if (key == WatchUi.KEY_ENTER) {
            openSelected();
            return true;
        }
        return false;
    }

    // Tap a list row or a chart bar → open that day; tap an arrow → scroll.
    function onTap(clickEvent) {
        var xy = clickEvent.getCoordinates();
        var settings = System.getDeviceSettings();
        var dir = _view.arrowAt(xy[0], xy[1], settings.screenWidth, settings.screenHeight);
        if (dir != 0) {
            _view.scrollPage(dir, settings.screenHeight);
            return true;
        }
        var idx = _view.indexAt(xy[0], xy[1], settings.screenWidth, settings.screenHeight);
        if (idx >= 0) {
            _view.selectedIndex = idx;
            openSelected();
        }
        return true;
    }

    function isAtTop() {
        return _view.selectedIndex <= 0;
    }

    private function showLog() {
        var view = new LogView();
        WatchUi.switchToView(view, new LogDelegate(view), WatchUi.SLIDE_DOWN);
    }

    // A tap on a touch screen and the START button both reach onSelect first;
    // declining passes the tap to onTap (with its position) and START to
    // onKey as KEY_ENTER.
    function onSelect() { return false; }

    // Drill into the selected day.
    private function openSelected() {
        var ymd = _view.getSelectedYmd();
        if (ymd <= 0) { return; }
        var view = new DayDetailView(ymd);
        WatchUi.pushView(view, new DayDetailDelegate(view), WatchUi.SLIDE_LEFT);
    }
}
