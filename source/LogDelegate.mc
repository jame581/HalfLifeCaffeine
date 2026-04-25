import Toybox.WatchUi;

class LogDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Swipe up (touch) OR UP button (non-touch) → back to timeline
    function onPreviousPage() {
        WatchUi.switchToView(new TimelineView(), new TimelineDelegate(), WatchUi.SLIDE_DOWN);
        return true;
    }

    // Swipe down (touch) OR DOWN button (non-touch) → history view
    function onNextPage() {
        var view = new HistoryView();
        WatchUi.switchToView(view, new HistoryDelegate(view), WatchUi.SLIDE_UP);
        return true;
    }

    // Non-touch widgets that don't auto-route DOWN/UP to next/prev page —
    // catch raw key events and dispatch manually.
    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN) { return onNextPage(); }
        if (key == WatchUi.KEY_UP)   { return onPreviousPage(); }
        return false;
    }
}
