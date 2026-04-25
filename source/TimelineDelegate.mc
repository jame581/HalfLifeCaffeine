import Toybox.WatchUi;

class TimelineDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Swipe down (touch) OR DOWN button (non-touch) → log view
    function onNextPage() {
        WatchUi.switchToView(new LogView(), new LogDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    // Swipe up (touch) OR UP button (non-touch) → back to summary
    function onPreviousPage() {
        WatchUi.switchToView(new SummaryView(), new SummaryDelegate(), WatchUi.SLIDE_DOWN);
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
