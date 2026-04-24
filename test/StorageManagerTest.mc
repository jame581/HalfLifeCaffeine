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
