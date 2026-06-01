import Toybox.Test;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:test)
function testRollupIsNoopWhenNoDaysToRoll(logger) {
    var sm = new StorageManager();
    var doses = [];
    var totals = [];
    // lastRolled is today → nothing to roll
    var todayYmd = 20260424;
    var result = sm.computeRollup(doses, totals, todayYmd, todayYmd);
    return (result.size() == 0);
}

(:test)
function testRollupAggregatesDosesForYesterday(logger) {
    var sm = new StorageManager();
    // Two doses on 2026-04-23: 100 mg + 50 mg
    var y_start = Gregorian.moment({
        :year => 2026, :month => 4, :day => 23,
        :hour => 8, :minute => 0, :second => 0
    }).value();
    var y_late = Gregorian.moment({
        :year => 2026, :month => 4, :day => 23,
        :hour => 15, :minute => 0, :second => 0
    }).value();
    var doses = [
        {:mg => 100.0, :time => y_start, :name => "Coffee"},
        {:mg => 50.0, :time => y_late, :name => "Tea"}
    ];
    // Roll forward from lastRolled=20260422 through yesterday=20260423
    var result = sm.computeRollup(doses, [], 20260422, 20260423);
    // One daily totals row for 20260423: [20260423, 150, 2]
    if (result.size() != 1) { return false; }
    var row = result[0];
    return (row[0] == 20260423) && (row[1] == 150) && (row[2] == 2);
}

(:test)
function testRollupAppendsToExistingTotals(logger) {
    var sm = new StorageManager();
    var y = Gregorian.moment({
        :year => 2026, :month => 4, :day => 23,
        :hour => 10, :minute => 0, :second => 0
    }).value();
    var doses = [{:mg => 80.0, :time => y, :name => "RedBull"}];
    var existing = [[20260420, 200, 3], [20260421, 150, 2]];
    var result = sm.computeRollup(doses, existing, 20260421, 20260423);
    // Existing two rows + new row for 20260423 (20260422 had no doses, skipped)
    if (result.size() != 3) { return false; }
    var last = result[2];
    return (last[0] == 20260423) && (last[1] == 80) && (last[2] == 1);
}

(:test)
function testRollupSkipsDaysWithNoDoses(logger) {
    var sm = new StorageManager();
    var doses = []; // No doses at all
    var result = sm.computeRollup(doses, [], 20260420, 20260423);
    return (result.size() == 0);
}

(:test)
function testRollupPrunesToNinetyDays(logger) {
    var sm = new StorageManager();
    // Pre-fill with 95 rows (all dated before today)
    var existing = [];
    for (var i = 0; i < 95; i++) {
        existing.add([20260100 + i, 100, 1]); // placeholder ymds
    }
    // Empty doses, no new days to roll
    var result = sm.computeRollup([], existing, 20260423, 20260423);
    // pruneDailyTotals should cap at 90
    var pruned = sm.pruneDailyTotals(existing, 90);
    return (pruned.size() == 90) && (pruned[0][0] == existing[5][0]);
}

// Regression: fresh install (lastRolledYmd == 0) opened on the 1st of a month.
// Before the fix, computeRollup called epochForYmd(todayYmd - 1) = epochForYmd(20260600),
// i.e. day 00, and Gregorian.moment threw "Invalid Value" — crashing the widget on
// tap-through. A fresh install has no completed prior day to roll, so the result is empty.
(:test)
function testRollupFreshInstallOnFirstOfMonthDoesNotCrash(logger) {
    var sm = new StorageManager();
    var result = sm.computeRollup([], [], 0, 20260601);
    return (result.size() == 0);
}

// Regression: rolling a completed day across a month boundary (non-fresh install).
// Exercises the epoch-day iteration over the May 31 -> June 1 transition; ymd +/- 1
// arithmetic would mis-handle the boundary, but iterating by epoch is calendar-safe.
(:test)
function testRollupCrossesMonthBoundary(logger) {
    var sm = new StorageManager();
    var may31 = Gregorian.moment({
        :year => 2026, :month => 5, :day => 31,
        :hour => 9, :minute => 0, :second => 0
    }).value();
    var doses = [{:mg => 120.0, :time => may31, :name => "Coffee"}];
    // lastRolled = 20260530, today = 20260601 -> must roll exactly 20260531.
    var result = sm.computeRollup(doses, [], 20260530, 20260601);
    if (result.size() != 1) { return false; }
    var row = result[0];
    return (row[0] == 20260531) && (row[1] == 120) && (row[2] == 1);
}
