import Toybox.WatchUi;

class LogDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Swipe up → back to timeline
    function onPreviousPage() {
        WatchUi.switchToView(new TimelineView(), new TimelineDelegate(), WatchUi.SLIDE_DOWN);
        return true;
    }

    // Swipe down → history view
    function onNextPage() {
        var view = new HistoryView();
        WatchUi.switchToView(view, new HistoryDelegate(view), WatchUi.SLIDE_UP);
        return true;
    }
}
