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

// Checks that run against real Storage (the v1.4.0 re-roll, dose loading and
// archiving), so the keys they touch are saved first and put back afterwards,
// also when the check throws.
function withCleanRollupStorage(check) {
    var keys = ["dailyTotals", "lastRolledYmd", "localDayFix", "doses", "archDays"];
    var origDays = Application.Storage.getValue("archDays");
    if (origDays instanceof Array) {
        for (var i = 0; i < origDays.size(); i++) { keys.add("arch" + origDays[i]); }
    }
    var saved = [];
    for (var i = 0; i < keys.size(); i++) {
        saved.add(Application.Storage.getValue(keys[i]));
        Application.Storage.deleteValue(keys[i]);
    }
    var ok = false;
    try {
        ok = check.invoke();
    } catch (e) {
        ok = false;
    }
    var newDays = Application.Storage.getValue("archDays");
    if (newDays instanceof Array) {
        for (var i = 0; i < newDays.size(); i++) { Application.Storage.deleteValue("arch" + newDays[i]); }
    }
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

// The glance builds records only for doses that can still add to the level.
function checkLoadDosesSinceSkipsOlder() {
    var sm = new StorageManager();
    var now = Time.now().value();
    sm.saveDoses([
        {:mg => 80.0, :time => now - 5 * 86400, :name => "Old"},
        {:mg => 95.0, :time => now - 3600, :name => "New"}
    ]);
    var recent = sm.loadDosesSince(now - 86400);
    return recent.size() == 1 && recent[0][:name].equals("New")
        && sm.loadDoses().size() == 2;
}

(:test)
function testLoadDosesSinceSkipsOlderDoses(logger) {
    return withCleanRollupStorage(new Lang.Method($, :checkLoadDosesSinceSkipsOlder));
}

// Old doses leave the dose list for the archive; the day detail still finds them.
function checkArchiveMovesOldDoses() {
    var sm = new StorageManager();
    var now = Time.now().value();
    var day3 = noonDaysAgo(now, 3);
    var doses = [
        {:mg => 80.0, :time => day3, :name => "Old"},
        {:mg => 95.0, :time => now - 3600, :name => "New"}
    ];
    var recent = sm.archiveOldDoses(doses, now - 2 * 86400, now);
    var stored = sm.loadDoses();
    var archived = sm.loadArchivedDosesForDay(Util.ymdFromEpoch(day3));
    return recent.size() == 1 && recent[0][:name].equals("New")
        && stored.size() == 1 && stored[0][:name].equals("New")
        && archived.size() == 1 && archived[0][:name].equals("Old")
        && archived[0][:mg] == 80.0 && archived[0][:time] == day3;
}

(:test)
function testArchiveMovesOldDoses(logger) {
    return withCleanRollupStorage(new Lang.Method($, :checkArchiveMovesOldDoses));
}

// The archive keeps 14 days; each archiving pass drops what is older.
function checkArchiveKeepsFourteenDays() {
    var sm = new StorageManager();
    var now = Time.now().value();
    var day15 = noonDaysAgo(now, 15);
    var day5 = noonDaysAgo(now, 5);
    sm.archiveOldDoses([{:mg => 60.0, :time => day15, :name => "Ancient"}], now - 86400, now - 2 * 86400);
    sm.archiveOldDoses([{:mg => 70.0, :time => day5, :name => "Five"}], now - 86400, now);
    return sm.loadArchivedDosesForDay(Util.ymdFromEpoch(day15)).size() == 0
        && sm.loadArchivedDosesForDay(Util.ymdFromEpoch(day5)).size() == 1;
}

(:test)
function testArchiveKeepsFourteenDays(logger) {
    return withCleanRollupStorage(new Lang.Method($, :checkArchiveKeepsFourteenDays));
}

function checkArchiveLeavesRecentDosesAlone() {
    var sm = new StorageManager();
    var now = Time.now().value();
    var doses = [{:mg => 95.0, :time => now - 3600, :name => "New"}];
    // Nothing to move: the same list comes back and the dose list is not rewritten.
    return sm.archiveOldDoses(doses, now - 86400, now) == doses
        && Application.Storage.getValue("doses") == null;
}

(:test)
function testArchiveLeavesRecentDosesAlone(logger) {
    return withCleanRollupStorage(new Lang.Method($, :checkArchiveLeavesRecentDosesAlone));
}

// If the app dies after archiving but before the dose list is shortened, the
// next pass archives the same doses again; they must not double.
function checkArchiveTwiceDoesNotDouble() {
    var sm = new StorageManager();
    var now = Time.now().value();
    var day3 = noonDaysAgo(now, 3);
    var doses = [
        {:mg => 80.0, :time => day3, :name => "A"},
        {:mg => 60.0, :time => day3 + 3600, :name => "B"}
    ];
    sm.archiveOldDoses(doses, now - 2 * 86400, now);
    sm.archiveOldDoses(doses, now - 2 * 86400, now);
    return sm.loadArchivedDosesForDay(Util.ymdFromEpoch(day3)).size() == 2;
}

(:test)
function testArchiveTwiceDoesNotDouble(logger) {
    return withCleanRollupStorage(new Lang.Method($, :checkArchiveTwiceDoesNotDouble));
}

// Doses of an old day stay countable: rolled up first, then archived, and the
// day keeps its total row and its per-drink detail.
function checkRollUpThenArchiveKeepsDay() {
    var sm = new StorageManager();
    var now = Time.now().value();
    // Outside the recent window (up to 104 h at the 10 h maximum), even just after midnight.
    var day3 = noonDaysAgo(now, 6);
    sm.saveLastRolledYmd(Util.ymdFromEpoch(noonDaysAgo(now, 7)));
    Application.Storage.setValue("localDayFix", true);
    var doses = [
        {:mg => 80.0, :time => day3, :name => "Old"},
        {:mg => 95.0, :time => now - 60, :name => "New"}
    ];
    sm.rollUpYesterday(doses, now);
    var model = new CaffeineModel();
    var since = sm.recentWindowStart(now, model.getArchiveCutoff(now - 4 * 3600));
    var recent = sm.archiveOldDoses(doses, since, now);
    var ymd3 = Util.ymdFromEpoch(day3);
    var rows = sm.loadDailyTotals();
    var hasTotal = false;
    for (var i = 0; i < rows.size(); i++) {
        if (rows[i][0] == ymd3 && rows[i][1] == 80) { hasTotal = true; }
    }
    return hasTotal && recent.size() == 1
        && sm.loadArchivedDosesForDay(ymd3).size() == 1;
}

(:test)
function testRollUpThenArchiveKeepsDay(logger) {
    return withCleanRollupStorage(new Lang.Method($, :checkRollUpThenArchiveKeepsDay));
}

// The in-memory window always holds all of yesterday (replace-day phone sync),
// and reaches further back when the decay tail needs it.
(:test)
function testRecentWindowCoversYesterday(logger) {
    var sm = new StorageManager();
    var now = Time.now().value();
    var yesterdayStart = Util.midnightEpochFor(noonDaysAgo(now, 1));
    var shortHl = new CaffeineModel();
    shortHl.setHalfLifeSeconds(3 * 3600);
    var longHl = new CaffeineModel();
    longHl.setHalfLifeSeconds(10 * 3600);
    var longCutoff = longHl.getOldestCountedTime(now - 4 * 3600);
    return sm.recentWindowStart(now, shortHl.getOldestCountedTime(now - 4 * 3600)) == yesterdayStart
        && sm.recentWindowStart(now, longCutoff) == longCutoff;
}

// Memory on small watches: the archive boundary is 7 half-lives at the
// current setting (under 1 mg left of a 128 mg dose), or yesterday's
// midnight when that is earlier.
(:test)
function testArchiveCutoffIsSevenHalfLives(logger) {
    var sm = new StorageManager();
    var now = Time.now().value();
    var yesterdayStart = Util.midnightEpochFor(noonDaysAgo(now, 1));
    var shortHl = new CaffeineModel();
    shortHl.setHalfLifeSeconds(3 * 3600);
    var longHl = new CaffeineModel();
    longHl.setHalfLifeSeconds(10 * 3600);
    var longCutoff = now - 4 * 3600 - 7 * 36000;
    return longHl.getArchiveCutoff(now - 4 * 3600) == longCutoff
        && sm.recentWindowStart(now, longHl.getArchiveCutoff(now - 4 * 3600)) == longCutoff
        && sm.recentWindowStart(now, shortHl.getArchiveCutoff(now - 4 * 3600)) == yesterdayStart;
}

// Two drinks with the same mg and second but different names are both kept.
function checkArchiveKeepsSameTimeDifferentDrinks() {
    var sm = new StorageManager();
    var now = Time.now().value();
    var day3 = noonDaysAgo(now, 3);
    sm.archiveOldDoses([
        {:mg => 80.0, :time => day3, :name => "Coffee"},
        {:mg => 80.0, :time => day3, :name => "Tea"}
    ], now - 2 * 86400, now);
    return sm.loadArchivedDosesForDay(Util.ymdFromEpoch(day3)).size() == 2;
}

(:test)
function testArchiveKeepsSameTimeDifferentDrinks(logger) {
    return withCleanRollupStorage(new Lang.Method($, :checkArchiveKeepsSameTimeDifferentDrinks));
}
