import Toybox.WatchUi;

class HistoryDelegate extends WatchUi.BehaviorDelegate {

    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Swipe up → back to LogView
    function onPreviousPage() {
        WatchUi.switchToView(new LogView(), new LogDelegate(), WatchUi.SLIDE_DOWN);
        return true;
    }

    // D-pad / touch-up arrow → move selection up in day list
    function onNextPage() {
        // NOTE: The existing chain maps swipe DOWN to onNextPage (see SummaryDelegate).
        // History is the terminal step; onNextPage is a no-op so the user doesn't
        // fall off the end of the chain.
        return true;
    }

    // UP button → scroll to newer day (smaller index)
    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_UP) {
            _view.moveSelection(-1);
            return true;
        }
        if (key == WatchUi.KEY_DOWN) {
            _view.moveSelection(1);
            return true;
        }
        return false;
    }

    // SELECT → drill into selected day
    function onSelect() {
        var ymd = _view.getSelectedYmd();
        if (ymd <= 0) { return true; }
        WatchUi.pushView(new DayDetailView(ymd), new DayDetailDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }
}
