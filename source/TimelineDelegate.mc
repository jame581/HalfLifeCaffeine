import Toybox.WatchUi;

class TimelineDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Swipe down → log view
    function onNextPage() {
        WatchUi.switchToView(new LogView(), new LogDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    // Swipe up → back to summary
    function onPreviousPage() {
        WatchUi.switchToView(new SummaryView(), new SummaryDelegate(), WatchUi.SLIDE_DOWN);
        return true;
    }
}
