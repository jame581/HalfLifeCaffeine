import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:glance)
class StorageManager {

    private const DOSES_KEY = "doses";
    private const ARCHIVE_PREFIX = "arch";
    private const ARCHIVE_DAYS_KEY = "archDays";
    private const RETENTION_SECONDS = 1209600; // 14 * 24 * 60 * 60
    private const DAILY_TOTALS_KEY = "dailyTotals";
    private const LAST_ROLLED_YMD_KEY = "lastRolledYmd";
    private const DAILY_TOTALS_RETENTION_DAYS = 90;
    private const LOCAL_DAY_FIX_KEY = "localDayFix";

    // Save the recent doses (see archiveOldDoses) to storage
    // doses: Array of {:mg => Float, :time => Number, :name => String}
    function saveDoses(doses) {
        var storable = [];
        for (var i = 0; i < doses.size(); i++) {
            storable.add(toStorable(doses[i]));
        }
        Application.Storage.setValue(DOSES_KEY, storable);
    }

    // Load the recent doses from storage
    // Returns Array of {:mg => Float, :time => Number, :name => String}
    function loadDoses() {
        return loadDosesSince(0);
    }

    // Load only the recent doses taken at or after sinceEpoch. The glance uses
    // it to skip building records for doses that no longer add to the level.
    function loadDosesSince(sinceEpoch) {
        return fromStorable(Application.Storage.getValue(DOSES_KEY), sinceEpoch);
    }

    // Start of the doses kept in memory: the earlier of yesterday's local
    // midnight and levelCutoff (where the level math stops looking). Yesterday
    // must stay whole: an edit across midnight sends it to the phone as a
    // replace-day list, which would drop archived doses from the phone.
    function recentWindowStart(nowEpoch, levelCutoff) {
        var yesterdayStart = Util.midnightEpochFor(Util.midnightEpochFor(nowEpoch) - 43200);
        return (levelCutoff < yesterdayStart) ? levelCutoff : yesterdayStart;
    }

    // Move doses taken before sinceEpoch from the dose list to the archive and
    // return the rest, so the glance and the model hold only recent doses. The
    // archive is one Storage key per local day ("arch" + ymd, listed in
    // "archDays"), so the day detail reads a single day; days older than 14 are
    // deleted here. Call after rollUpYesterday: the roll-up reads the dose list,
    // not the archive.
    function archiveOldDoses(doses, sinceEpoch, nowEpoch) {
        var recent = [];
        var old = [];
        for (var i = 0; i < doses.size(); i++) {
            if (doses[i][:time] < sinceEpoch) {
                old.add(doses[i]);
            } else {
                recent.add(doses[i]);
            }
        }

        var cutoffYmd = Util.ymdFromEpoch(nowEpoch - RETENTION_SECONDS);
        var days = loadArchiveDays();
        var kept = [];
        for (var i = 0; i < days.size(); i++) {
            if (days[i] < cutoffYmd) {
                Application.Storage.deleteValue(ARCHIVE_PREFIX + days[i]);
            } else {
                kept.add(days[i]);
            }
        }
        var daysChanged = kept.size() != days.size();
        days = kept;

        // Archive first, then shorten the dose list. If the app dies between
        // the two writes the doses are archived again next time; rows that are
        // already in their day are skipped, so nothing doubles.
        var done = new [old.size()];
        for (var i = 0; i < old.size(); i++) {
            if (done[i] != null) { continue; }
            var ymd = Util.ymdFromEpoch(old[i][:time]);
            if (ymd < cutoffYmd) { continue; }
            var rows = Application.Storage.getValue(ARCHIVE_PREFIX + ymd);
            if (rows == null || !(rows instanceof Array)) { rows = []; }
            for (var j = i; j < old.size(); j++) {
                if (done[j] != null || Util.ymdFromEpoch(old[j][:time]) != ymd) { continue; }
                done[j] = true;
                if (!hasRow(rows, old[j])) { rows.add(toStorable(old[j])); }
            }
            Application.Storage.setValue(ARCHIVE_PREFIX + ymd, rows);
            if (days.indexOf(ymd) < 0) {
                days.add(ymd);
                daysChanged = true;
            }
        }
        if (daysChanged) {
            Application.Storage.setValue(ARCHIVE_DAYS_KEY, days);
        }
        if (old.size() == 0) { return doses; }
        saveDoses(recent);
        return recent;
    }

    // Archived doses of one local day, in stored order.
    function loadArchivedDosesForDay(ymd) {
        return fromStorable(Application.Storage.getValue(ARCHIVE_PREFIX + ymd), 0);
    }

    private function loadArchiveDays() {
        var days = Application.Storage.getValue(ARCHIVE_DAYS_KEY);
        return (days != null && days instanceof Array) ? days : [];
    }

    // True when the day's archive already holds this dose (same mg, second and
    // name). Two such doses would be indistinguishable anyway; the check is
    // what makes re-archiving after a crash harmless.
    private function hasRow(rows, dose) {
        for (var i = 0; i < rows.size(); i++) {
            var row = rows[i];
            if (row instanceof Array && row.size() >= 3
                    && row[1] == dose[:time] && row[0] == dose[:mg]
                    && row[2].equals(toStorable(dose)[2])) {
                return true;
            }
        }
        return false;
    }

    private function toStorable(dose) {
        var name = dose.hasKey(:name) ? dose[:name] : "";
        return [dose[:mg], dose[:time], name];
    }

    // Rehydrate stored [mg, time, name] rows taken at or after fromEpoch.
    private function fromStorable(storable, fromEpoch) {
        var doses = [];
        if (storable != null && storable instanceof Array) {
            for (var i = 0; i < storable.size(); i++) {
                var entry = storable[i];
                if (!(entry instanceof Array) || entry.size() < 2) { continue; }
                var time = entry[1].toNumber();
                if (time < fromEpoch) { continue; }
                var name = (entry.size() >= 3) ? entry[2].toString() : "";
                doses.add({:mg => entry[0].toFloat(), :time => time, :name => name});
            }
        }
        return doses;
    }

    // Load daily totals from storage. Returns array of [ymd, totalMg, doseCount].
    function loadDailyTotals() {
        var raw = Application.Storage.getValue(DAILY_TOTALS_KEY);
        var result = [];
        if (raw != null && raw instanceof Array) {
            for (var i = 0; i < raw.size(); i++) {
                var row = raw[i];
                if (row instanceof Array && row.size() >= 3) {
                    result.add([row[0].toNumber(), row[1].toNumber(), row[2].toNumber()]);
                }
            }
        }
        return result;
    }

    function saveDailyTotals(totals) {
        Application.Storage.setValue(DAILY_TOTALS_KEY, totals);
    }

    function getLastRolledYmd() {
        var v = Application.Storage.getValue(LAST_ROLLED_YMD_KEY);
        if (v != null && v instanceof Number) {
            return v;
        }
        return 0;
    }

    function saveLastRolledYmd(ymd) {
        Application.Storage.setValue(LAST_ROLLED_YMD_KEY, ymd);
    }

    // Compute and persist roll-up of doses into daily totals for any completed
    // days since lastRolledYmd. Idempotent — safe to call on every widget open.
    function rollUpYesterday(doses, nowEpoch) {
        var todayYmd = Util.ymdFromEpoch(nowEpoch);
        var lastRolledYmd = getLastRolledYmd();
        // Before v1.4.0 days were cut at 00:00 UTC instead of local midnight, and
        // west of UTC the roll-up ran a day behind its own marker, so the marked
        // day may have no row. Once, roll the last marked day again; a row that
        // exists is kept.
        if (Application.Storage.getValue(LOCAL_DAY_FIX_KEY) == null) {
            if (lastRolledYmd != 0) {
                lastRolledYmd = Util.ymdFromEpoch(epochForYmd(lastRolledYmd) - 43200);
            }
            Application.Storage.setValue(LOCAL_DAY_FIX_KEY, true);
        }
        // Noon of the previous local day; "now - 24 h" is still today late on a 25 h day.
        var yesterdayYmd = Util.ymdFromEpoch(Util.midnightEpochFor(nowEpoch) - 43200);
        if (lastRolledYmd >= yesterdayYmd) {
            return; // Nothing to do
        }
        var existing = loadDailyTotals();
        var updated = computeRollup(doses, existing, lastRolledYmd, todayYmd);
        updated = pruneDailyTotals(updated, DAILY_TOTALS_RETENTION_DAYS);
        saveDailyTotals(updated);
        saveLastRolledYmd(yesterdayYmd);
    }

    // Filter doses to those falling within a specific local-day ymd.
    // Returns array of dose dicts (unmodified, so :mg/:time/:name are preserved).
    function getDosesForDay(doses, ymd) {
        var startEpoch = epochForYmdPublic(ymd);
        var endEpoch = Util.midnightEpochFor(startEpoch + 129600); // next local midnight
        var result = [];
        for (var i = 0; i < doses.size(); i++) {
            var dose = doses[i];
            if (dose[:time] >= startEpoch && dose[:time] < endEpoch) {
                result.add(dose);
            }
        }
        return result;
    }

    // Public mirror of private epochForYmd — needed by getDosesForDay which is public.
    // Kept separate so the private version stays callable from computeRollup without
    // going through a public method.
    function epochForYmdPublic(ymd) {
        return epochForYmd(ymd);
    }

    // Pure function: given doses, existing daily totals, lastRolled ymd, and today's ymd,
    // return new daily totals array with any newly-completed days appended. A day
    // that already has a row is left as it is, so no ymd appears twice.
    // Does NOT mutate inputs; does NOT touch Storage.
    function computeRollup(doses, existingTotals, lastRolledYmd, todayYmd) {
        var result = [];
        for (var i = 0; i < existingTotals.size(); i++) {
            result.add(existingTotals[i]);
        }
        if (lastRolledYmd >= todayYmd - 1) {
            // Nothing to roll (we only roll completed days = yesterday and before)
            if (lastRolledYmd == todayYmd) { return result; }
            // lastRolledYmd == todayYmd - 1 means yesterday already rolled
            if (lastRolledYmd == todayYmd - 1) { return result; }
        }
        // Roll every completed day from the day after lastRolledYmd up to (not including) today.
        // We hop from local midnight to local midnight; ymd arithmetic (+/- 1) is NOT
        // calendar-safe, and adding 86400 is not either: a day is 23 or 25 h long when
        // the clocks change. Midnight + 36 h is always inside the next day.
        var endEpoch = epochForYmd(todayYmd); // today's local midnight
        // Fresh install (lastRolledYmd == 0): no completed day to roll. Do NOT use
        // epochForYmd(todayYmd - 1): on the 1st of a month todayYmd - 1 ends in 00 (day 0)
        // and Gregorian.moment throws "Invalid Value", which crashed fresh installs
        // opened on the 1st of any month.
        var dayStart = endEpoch;
        if (lastRolledYmd != 0) {
            dayStart = Util.midnightEpochFor(epochForYmd(lastRolledYmd) + 129600);
        }
        while (dayStart < endEpoch) {
            var dayYmd = Util.ymdFromEpoch(dayStart);
            var dayEnd = Util.midnightEpochFor(dayStart + 129600);
            var totalMg = 0;
            var count = 0;
            for (var i = 0; i < doses.size(); i++) {
                var dose = doses[i];
                if (dose[:time] >= dayStart && dose[:time] < dayEnd) {
                    totalMg += dose[:mg].toNumber();
                    count += 1;
                }
            }
            // A day that already has a row keeps it: the roll-up reads only the
            // recent dose list, so rolling an archived day again would count fewer.
            var hasRow = false;
            for (var i = 0; i < result.size(); i++) {
                if (result[i][0] == dayYmd) { hasRow = true; }
            }
            if (totalMg > 0 && !hasRow) {
                result.add([dayYmd, totalMg, count]);
            }
            dayStart = dayEnd;
        }
        return result;
    }

    // Trim daily totals to at most maxDays entries (drops oldest from front).
    function pruneDailyTotals(totals, maxDays) {
        if (totals.size() <= maxDays) { return totals; }
        var start = totals.size() - maxDays;
        var result = [];
        for (var i = start; i < totals.size(); i++) {
            result.add(totals[i]);
        }
        return result;
    }

    // Convert a ymd (YYYYMMDD int) to the local-midnight epoch at the START of that day.
    private function epochForYmd(ymd) {
        var year = (ymd / 10000).toNumber();
        var month = ((ymd / 100) % 100).toNumber();
        var day = (ymd % 100).toNumber();
        // Gregorian.moment reads its fields as UTC. Noon UTC falls on the same
        // local date everywhere except UTC+12 and beyond, where it is already tomorrow.
        var noon = Gregorian.moment({
            :year => year,
            :month => month,
            :day => day,
            :hour => 12,
            :minute => 0,
            :second => 0
        }).value();
        if (Util.ymdFromEpoch(noon) != ymd) { noon -= 43200; }
        return Util.midnightEpochFor(noon);
    }
}
