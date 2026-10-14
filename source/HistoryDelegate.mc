import Toybox.WatchUi;

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
        return false;
    }

    function isAtTop() {
        return _view.selectedIndex <= 0;
    }

    private function showLog() {
        var view = new LogView();
        WatchUi.switchToView(view, new LogDelegate(view), WatchUi.SLIDE_DOWN);
    }

    // SELECT → drill into selected day
    function onSelect() {
        var ymd = _view.getSelectedYmd();
        if (ymd <= 0) { return true; }
        WatchUi.pushView(new DayDetailView(ymd), new DayDetailDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }
}
