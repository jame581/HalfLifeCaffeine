import Toybox.Test;
import Toybox.WatchUi;

// Watches whose UP/DOWN buttons carry the previousPage/nextPage behaviors
// (fr255s, fenix 7, ...) call onPreviousPage/onNextPage first and pass the
// key to onKey only when those return false. On the log and history the
// buttons move the cursor, so the page handlers must decline; swipes page
// through onSwipe instead.

(:test)
function testHistoryPageBehaviorsLeaveButtonsToCursor(logger) {
    var view = new HistoryView();
    var delegate = new HistoryDelegate(view);
    return delegate.onNextPage() == false && delegate.onPreviousPage() == false;
}

(:test)
function testHistoryDownButtonMovesCursor(logger) {
    var view = new HistoryView();
    view.dayRows = [[20261014, 80], [20261013, 183], [20261012, 186]];
    var delegate = new HistoryDelegate(view);
    delegate.onKey(new WatchUi.KeyEvent(WatchUi.KEY_DOWN, WatchUi.PRESS_TYPE_ACTION));
    delegate.onKey(new WatchUi.KeyEvent(WatchUi.KEY_DOWN, WatchUi.PRESS_TYPE_ACTION));
    delegate.onKey(new WatchUi.KeyEvent(WatchUi.KEY_UP, WatchUi.PRESS_TYPE_ACTION));
    return view.selectedIndex == 1;
}

(:test)
function testLogPageBehaviorsLeaveButtonsToCursor(logger) {
    var view = new LogView();
    var delegate = new LogDelegate(view);
    return delegate.onNextPage() == false && delegate.onPreviousPage() == false;
}

(:test)
function testLogDownButtonMovesCursor(logger) {
    var view = new LogView();
    view.dayDoses = [{:mg => 95.0, :time => 0, :name => "A"}, {:mg => 63.0, :time => 0, :name => "B"}];
    var delegate = new LogDelegate(view);
    delegate.onKey(new WatchUi.KeyEvent(WatchUi.KEY_DOWN, WatchUi.PRESS_TYPE_ACTION));
    return view.selectedIndex == 1;
}

// Past either end of the list the buttons page on, so History stays reachable
// on watches without touch.
(:test)
function testLogDownOnLastRowLeavesCursor(logger) {
    var view = new LogView();
    view.dayDoses = [{:mg => 95.0, :time => 0, :name => "A"}, {:mg => 63.0, :time => 0, :name => "B"}];
    view.selectedIndex = 1;
    var delegate = new LogDelegate(view);
    return delegate.isAtEnd(1) && !delegate.isAtEnd(-1)
        && delegate.onKey(new WatchUi.KeyEvent(WatchUi.KEY_DOWN, WatchUi.PRESS_TYPE_ACTION))
        && view.selectedIndex == 1;
}

(:test)
function testLogEmptyListPagesBothWays(logger) {
    var view = new LogView();
    view.dayDoses = [];
    var delegate = new LogDelegate(view);
    return delegate.isAtEnd(1) && delegate.isAtEnd(-1);
}

(:test)
function testHistoryUpOnNewestDayLeavesCursor(logger) {
    var view = new HistoryView();
    view.dayRows = [[20261014, 80], [20261013, 183]];
    var delegate = new HistoryDelegate(view);
    return delegate.isAtTop() && delegate.onKey(new WatchUi.KeyEvent(WatchUi.KEY_DOWN, WatchUi.PRESS_TYPE_ACTION))
        && !delegate.isAtTop();
}
