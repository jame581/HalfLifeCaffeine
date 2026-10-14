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
function testLogPagesOnOnlyPastLastRow(logger) {
    var view = new LogView();
    view.dayDoses = [{:mg => 95.0, :time => 0, :name => "A"}, {:mg => 63.0, :time => 0, :name => "B"}];
    view.selectedIndex = 1;
    var delegate = new LogDelegate(view);
    return delegate.isAtEnd(1) && !delegate.isAtEnd(-1);
}

(:test)
function testLogEmptyListPagesBothWays(logger) {
    var view = new LogView();
    view.dayDoses = [];
    var delegate = new LogDelegate(view);
    return delegate.isAtEnd(1) && delegate.isAtEnd(-1);
}

(:test)
function testHistoryPagesBackOnlyFromNewestDay(logger) {
    var view = new HistoryView();
    view.dayRows = [[20261014, 80], [20261013, 183]];
    var delegate = new HistoryDelegate(view);
    return delegate.isAtTop() && delegate.onKey(new WatchUi.KeyEvent(WatchUi.KEY_DOWN, WatchUi.PRESS_TYPE_ACTION))
        && !delegate.isAtTop();
}

// Taps: on touch watches a tap reaches onSelect first and onTap only when
// onSelect declines; START reaches onSelect, then onKey(KEY_ENTER).
(:test)
function testSelectBehaviorLeavesTapsAndEnterToHandlers(logger) {
    var history = new HistoryView();
    var log = new LogView();
    return new HistoryDelegate(history).onSelect() == false
        && new LogDelegate(log).onSelect() == false;
}

function historyWithRows(count) {
    var view = new HistoryView();
    var rows = [];
    for (var i = 0; i < count; i++) { rows.add([20261014 - i, 100]); }
    view.dayRows = rows;
    return view;
}

// 100x100 screen: list rows of 10 px from y 54 (3 visible), chart y 15-48,
// 14 bar slots of 5 px from x 12, newest on the right.
(:test)
function testHistoryTapOnListRow(logger) {
    var view = historyWithRows(20);
    return view.indexAt(50, 55, 100, 100) == 0
        && view.indexAt(50, 65, 100, 100) == 1
        && view.indexAt(50, 83, 100, 100) == 2
        && view.indexAt(50, 85, 100, 100) == -1;  // the scroll-down arrow
}

(:test)
function testHistoryTapOnScrolledList(logger) {
    var view = historyWithRows(20);
    view.selectedIndex = 6; // rows 4-6 visible
    return view.indexAt(50, 55, 100, 100) == 4 && view.indexAt(50, 75, 100, 100) == 6;
}

(:test)
function testHistoryTapOnChartBar(logger) {
    var view = historyWithRows(20);
    return view.indexAt(79, 30, 100, 100) == 0     // rightmost slot = today
        && view.indexAt(13, 30, 100, 100) == 13    // leftmost slot
        && view.indexAt(5, 30, 100, 100) == -1     // left of the chart
        && historyWithRows(3).indexAt(13, 30, 100, 100) == -1; // empty slot
}

(:test)
function testHistoryTapOnEmptyList(logger) {
    return historyWithRows(0).indexAt(50, 55, 100, 100) == -1;
}

function logWithDoses(count) {
    var view = new LogView();
    var doses = [];
    for (var i = 0; i < count; i++) { doses.add({:mg => 95.0, :time => i, :name => "D" + i}); }
    view.dayDoses = doses;
    return view;
}

// 100x100 screen: rows of 10 px centred from y 28 (5 visible).
(:test)
function testLogTapOnRow(logger) {
    var view = logWithDoses(3);
    return view.indexAt(28, 100) == 0 && view.indexAt(40, 100) == 1
        && view.indexAt(20, 100) == -1 && view.indexAt(60, 100) == -1;
}

(:test)
function testLogTapOnScrolledList(logger) {
    var view = logWithDoses(8);
    view.selectedIndex = 6; // rows 2-6 visible
    return view.indexAt(28, 100) == 2 && view.indexAt(68, 100) == 6
        && view.scrollStart(100) == 2;
}

// Edges of the chart: above it, in the gap above the list, and the leftover
// pixels right of the last slot. 200x100 (non-square, as on venusq2): chart
// x from 24, slots of 10 px; y 15-48; list from y 54.
(:test)
function testHistoryTapChartEdges(logger) {
    var view = historyWithRows(20);
    return view.indexAt(159, 30, 200, 100) == 0     // slot 13, today
        && view.indexAt(159, 15, 200, 100) == 0     // top edge counts
        && view.indexAt(159, 14, 200, 100) == -1    // above the chart
        && view.indexAt(159, 50, 200, 100) == -1    // gap between chart and list
        && view.indexAt(169, 30, 200, 100) == -1    // right of slot 13
        && view.indexAt(100, 55, 200, 100) == 0;    // list ignores x
}

// Scroll arrows: shown, and tappable, only where rows are hidden. A tap
// scrolls a page and leaves the cursor on the last row shown.
(:test)
function testHistoryArrowsScrollByPage(logger) {
    var view = historyWithRows(20); // 3 rows visible; arrows at y 48-54 and 84+
    if (view.arrowAt(50, 50, 100, 100) != 0 || view.arrowAt(50, 90, 100, 100) != 1) { return false; }
    view.scrollPage(1, 100);
    if (view.selectedIndex != 5 || view.arrowAt(50, 50, 100, 100) != -1) { return false; }
    for (var i = 0; i < 10; i++) { view.scrollPage(1, 100); }
    if (view.selectedIndex != 19 || view.arrowAt(50, 90, 100, 100) != 0) { return false; }
    view.scrollPage(-1, 100); // rows 14-16
    return view.selectedIndex == 16 && view.indexAt(50, 55, 100, 100) == 14;
}

(:test)
function testHistoryNoArrowsWhenAllRowsFit(logger) {
    var view = historyWithRows(3);
    return view.arrowAt(50, 50, 100, 100) == 0 && view.arrowAt(50, 90, 100, 100) == 0;
}

(:test)
function testLogArrowsScrollByPage(logger) {
    var view = logWithDoses(8); // 5 rows visible (y 23-73); arrows above 23 and from 73
    if (view.arrowAt(10, 100) != 0 || view.arrowAt(80, 100) != 1) { return false; }
    view.scrollPage(1, 100); // rows 3-7
    if (view.selectedIndex != 7 || view.scrollStart(100) != 3
            || view.arrowAt(10, 100) != -1 || view.arrowAt(80, 100) != 0) { return false; }
    view.scrollPage(-1, 100); // rows 0-4
    return view.selectedIndex == 4 && view.scrollStart(100) == 0;
}

(:test)
function testLogNoArrowsWhenAllRowsFit(logger) {
    var view = logWithDoses(3);
    return view.arrowAt(10, 100) == 0 && view.arrowAt(80, 100) == 0;
}
