import Toybox.Test;

(:test)
function testTimelineRangeIndexValid(logger) {
    return TimelineView.rangeIndex(0) == 0
        && TimelineView.rangeIndex(1) == 1
        && TimelineView.rangeIndex(2) == 2;
}

(:test)
function testTimelineRangeIndexFallsBackToDefault(logger) {
    return TimelineView.rangeIndex(null) == 1
        && TimelineView.rangeIndex(-1) == 1
        && TimelineView.rangeIndex(3) == 1
        && TimelineView.rangeIndex(1.0) == 1
        && TimelineView.rangeIndex("2") == 1;
}

(:test)
function testTimelineNextRangeWraps(logger) {
    return TimelineView.nextRange(0) == 1
        && TimelineView.nextRange(1) == 2
        && TimelineView.nextRange(2) == 0;
}

(:test)
function testTimelineRangesTable(logger) {
    var r = TimelineView.RANGES;
    return r.size() == 3
        && r[0][0] == 2 && r[0][1] == 4 && r[0][2] == 10
        && r[1][0] == 4 && r[1][1] == 8 && r[1][2] == 15
        && r[2][0] == 6 && r[2][1] == 12 && r[2][2] == 20;
}
