import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:glance)
class StorageManager {

    private const DOSES_KEY = "doses";
    private const LAST_SYNC_KEY = "lastSync";
    private const RETENTION_SECONDS = 1209600; // 14 * 24 * 60 * 60

    // Save all active doses to storage
    // doses: Array of {:mg => Float, :time => Number}
    function saveDoses(doses) {
        var storable = [];
        for (var i = 0; i < doses.size(); i++) {
            var dose = doses[i];
            var name = dose.hasKey(:name) ? dose[:name] : "";
            storable.add([dose[:mg], dose[:time], name]);
        }
        Application.Storage.setValue(DOSES_KEY, storable);
    }

    // Load doses from storage
    // Returns Array of {:mg => Float, :time => Number}
    function loadDoses() {
        var storable = Application.Storage.getValue(DOSES_KEY);
        var doses = [];
        if (storable != null && storable instanceof Array) {
            for (var i = 0; i < storable.size(); i++) {
                var entry = storable[i];
                if (entry instanceof Array && entry.size() >= 2) {
                    var name = (entry.size() >= 3) ? entry[2].toString() : "";
                    doses.add({:mg => entry[0].toFloat(), :time => entry[1].toNumber(), :name => name});
                }
            }
        }
        return doses;
    }

    // Remove doses older than 14 days
    function pruneOldDoses(doses, nowEpoch) {
        var cutoff = nowEpoch - RETENTION_SECONDS;
        var kept = [];
        for (var i = 0; i < doses.size(); i++) {
            if (doses[i][:time] >= cutoff) {
                kept.add(doses[i]);
            }
        }
        return kept;
    }

    // Save the epoch of the last successful sync to phone
    function saveLastSyncTime(epochSeconds) {
        Application.Storage.setValue(LAST_SYNC_KEY, epochSeconds);
    }

    // Get the epoch of the last successful sync
    function getLastSyncTime() {
        var value = Application.Storage.getValue(LAST_SYNC_KEY);
        if (value != null && value instanceof Number) {
            return value;
        }
        return 0;
    }

    // Get doses added since a given epoch (for incremental sync)
    function getDosesSince(doses, sinceEpoch) {
        var result = [];
        for (var i = 0; i < doses.size(); i++) {
            if (doses[i][:time] > sinceEpoch) {
                result.add(doses[i]);
            }
        }
        return result;
    }

    // Pure function: given doses, existing daily totals, lastRolled ymd, and today's ymd,
    // return new daily totals array with any newly-completed days appended.
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
        // Roll every day from lastRolledYmd+1 through todayYmd-1 (inclusive)
        // Note: ymd arithmetic (+1) is NOT calendar-safe; we iterate by epoch-day.
        var startEpoch = epochForYmd(lastRolledYmd == 0 ? todayYmd - 1 : lastRolledYmd);
        var endEpoch = epochForYmd(todayYmd);
        var dayEpoch = startEpoch + 86400; // day AFTER lastRolledYmd (or yesterday if lastRolled==0)
        while (dayEpoch < endEpoch) {
            var dayYmd = Util.ymdFromEpoch(dayEpoch);
            var dayStart = Util.midnightEpochFor(dayEpoch);
            var dayEnd = dayStart + 86400;
            var totalMg = 0;
            var count = 0;
            for (var i = 0; i < doses.size(); i++) {
                var dose = doses[i];
                if (dose[:time] >= dayStart && dose[:time] < dayEnd) {
                    totalMg += dose[:mg].toNumber();
                    count += 1;
                }
            }
            if (totalMg > 0) {
                result.add([dayYmd, totalMg, count]);
            }
            dayEpoch += 86400;
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
        var moment = Gregorian.moment({
            :year => year,
            :month => month,
            :day => day,
            :hour => 0,
            :minute => 0,
            :second => 0
        });
        return moment.value();
    }
}
