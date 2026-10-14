import Toybox.Test;
import Toybox.Application;
import Toybox.Lang;
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
    // lastRolled = 20260422, today = 20260424 -> rolls the one completed day, 20260423
    var result = sm.computeRollup(doses, [], 20260422, 20260424);
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
    var result = sm.computeRollup(doses, existing, 20260421, 20260424);
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

// A day that already has a row keeps it and is not listed twice: the doses
// behind it may have been pruned since (they go once they decay below 1 mg).
(:test)
function testRollupKeepsExistingRowForSameDay(logger) {
    var sm = new StorageManager();
    var y = Gregorian.moment({
        :year => 2026, :month => 4, :day => 23,
        :hour => 10, :minute => 0, :second => 0
    }).value();
    var doses = [{:mg => 80.0, :time => y, :name => "RedBull"}];
    var existing = [[20260422, 200, 3], [20260423, 999, 9]];
    var result = sm.computeRollup(doses, existing, 20260422, 20260424);
    if (result.size() != 2) { return false; }
    return (result[0][0] == 20260422) && (result[0][1] == 200)
        && (result[1][0] == 20260423) && (result[1][1] == 999) && (result[1][2] == 9);
}

// Rolling several days at once gives one row per day, each with its own doses.
(:test)
function testRollupSeveralDaysGivesOneRowPerDay(logger) {
    var sm = new StorageManager();
    var doses = [];
    for (var d = 20; d <= 23; d++) {
        var t = Gregorian.moment({
            :year => 2026, :month => 4, :day => d,
            :hour => 10, :minute => 0, :second => 0
        }).value();
        doses.add({:mg => d.toFloat(), :time => t, :name => "Coffee"});
    }
    var result = sm.computeRollup(doses, [], 20260419, 20260424);
    if (result.size() != 4) { return false; }
    for (var i = 0; i < 4; i++) {
        if (result[i][0] != 20260420 + i || result[i][1] != 20 + i || result[i][2] != 1) { return false; }
    }
    return true;
}

// Regression: a day runs from local midnight to local midnight.
(:test)
function testDosesForDayUsesLocalMidnight(logger) {
    var sm = new StorageManager();
    // Midnight worked out here, not by the code under test (an hour off on a
    // clock-change day, which the margins below absorb).
    var now = Time.now().value();
    var info = Gregorian.info(new Time.Moment(now), Time.FORMAT_SHORT);
    var midnight = now - (info.hour * 3600 + info.min * 60 + info.sec);
    var doses = [
        {:mg => 100.0, :time => midnight - 7200, :name => "LateYesterday"},
        {:mg => 63.0, :time => midnight + 5400, :name => "EarlyToday"},
        {:mg => 80.0, :time => midnight + 79200, :name => "LateToday"}
    ];
    var today = sm.getDosesForDay(doses, Util.ymdFromEpoch(now));
    return today.size() == 2 && today[0][:mg] == 63.0 && today[1][:mg] == 80.0;
}

// rollUpYesterday with the one-time v1.4.0 re-roll. Runs against real Storage,
// so the keys it touches are saved first and put back afterwards.
function withCleanRollupStorage(check) {
    var keys = ["dailyTotals", "lastRolledYmd", "localDayFix"];
    var saved = [];
    for (var i = 0; i < keys.size(); i++) {
        saved.add(Application.Storage.getValue(keys[i]));
        Application.Storage.deleteValue(keys[i]);
    }
    var ok = check.invoke();
    for (var i = 0; i < keys.size(); i++) {
        if (saved[i] == null) {
            Application.Storage.deleteValue(keys[i]);
        } else {
            Application.Storage.setValue(keys[i], saved[i]);
        }
    }
    return ok;
}

// Noon of the local day "back" days before today, worked out without the
// roll-up code.
function noonDaysAgo(now, back) {
    var t = Util.midnightEpochFor(now) - 43200;
    for (var i = 1; i < back; i++) {
        t = Util.midnightEpochFor(t) - 43200;
    }
    return Util.localTimeOnDay(t, 43200);
}

// West of UTC old builds marked a day as rolled without a row for it; the
// re-roll adds it, once.
function checkMigrationAddsMissingMarkedDay() {
    var sm = new StorageManager();
    var now = Time.now().value();
    var y1 = noonDaysAgo(now, 1);
    var y2 = noonDaysAgo(now, 2);
    var y3 = noonDaysAgo(now, 3);
    sm.saveDailyTotals([[Util.ymdFromEpoch(y3), 300, 3]]);
    sm.saveLastRolledYmd(Util.ymdFromEpoch(y2));
    var doses = [
        {:mg => 50.0, :time => y2, :name => "Coffee"},
        {:mg => 70.0, :time => y1, :name => "Tea"}
    ];
    sm.rollUpYesterday(doses, now);
    var rows = sm.loadDailyTotals();
    var ok = rows.size() == 3
        && rows[1][0] == Util.ymdFromEpoch(y2) && rows[1][1] == 50
        && rows[2][0] == Util.ymdFromEpoch(y1) && rows[2][1] == 70
        && sm.getLastRolledYmd() == Util.ymdFromEpoch(y1)
        && Application.Storage.getValue("localDayFix") == true;
    // A second open changes nothing.
    sm.saveLastRolledYmd(Util.ymdFromEpoch(y2));
    sm.rollUpYesterday(doses, now);
    return ok && sm.loadDailyTotals().size() == 3;
}

(:test)
function testRollUpMigrationAddsMissingMarkedDay(logger) {
    return withCleanRollupStorage(new Lang.Method($, :checkMigrationAddsMissingMarkedDay));
}

// East of UTC the marked day already has a row; the re-roll must not lower it
// with doses that have been pruned since.
function checkMigrationKeepsExistingRow() {
    var sm = new StorageManager();
    var now = Time.now().value();
    var y1 = noonDaysAgo(now, 1);
    var y2 = noonDaysAgo(now, 2);
    sm.saveDailyTotals([[Util.ymdFromEpoch(y2), 400, 4]]);
    sm.saveLastRolledYmd(Util.ymdFromEpoch(y2));
    var doses = [{:mg => 50.0, :time => y2, :name => "Coffee"}];
    sm.rollUpYesterday(doses, now);
    var rows = sm.loadDailyTotals();
    return rows.size() == 1 && rows[0][1] == 400 && rows[0][2] == 4
        && sm.getLastRolledYmd() == Util.ymdFromEpoch(y1);
}

(:test)
function testRollUpMigrationKeepsExistingRow(logger) {
    return withCleanRollupStorage(new Lang.Method($, :checkMigrationKeepsExistingRow));
}
