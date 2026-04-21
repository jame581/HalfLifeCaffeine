import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:glance)
class CaffeineModel {

    // Half-life of caffeine in seconds (5.7 hours)
    private const HALF_LIFE_SECONDS = 20520;
    // Minimum mg before a dose is considered cleared
    private const MIN_DOSE_MG = 1.0;

    // Array of active doses: each is {:mg => Float, :time => Number, :name => String}
    private var _doses;

    function initialize() {
        _doses = [];
    }

    // Add a new caffeine dose
    function addDose(mg, timeEpoch, name) {
        _doses.add({:mg => mg.toFloat(), :time => timeEpoch, :name => name});
    }

    // Get total caffeine level at any point in time.
    // For historical queries, doses taken after the given time don't count.
    function getCurrentLevel(epoch) {
        var total = 0.0;
        for (var i = 0; i < _doses.size(); i++) {
            var dose = _doses[i];
            if (dose[:time] > epoch) { continue; }
            total += decayedAmount(dose[:mg], dose[:time], epoch);
        }
        return total;
    }

    // Call periodically to clean up expired doses (only with real current time)
    function pruneExpiredDoses(nowEpoch) {
        pruneExpired(nowEpoch);
    }

    // Get total caffeine consumed today (sum of original doses, not decayed)
    function getDailyIntake(nowEpoch) {
        var todayStart = getMidnightEpoch(nowEpoch);
        var total = 0;
        for (var i = 0; i < _doses.size(); i++) {
            var dose = _doses[i];
            if (dose[:time] >= todayStart) {
                total += dose[:mg].toNumber();
            }
        }
        return total;
    }

    // Get minutes until total caffeine drops below safeLevel mg
    // Returns 0 if already below
    function getMinutesToSafe(nowEpoch, safeLevel) {
        var currentLevel = getCurrentLevel(nowEpoch);
        if (currentLevel <= safeLevel) {
            return 0;
        }
        // Binary search: check in 1-minute increments over next 24 hours
        var low = 0;
        var high = 1440; // 24 hours in minutes
        while (low < high) {
            var mid = ((low + high) / 2).toNumber();
            var futureEpoch = nowEpoch + (mid * 60);
            var futureLevel = getCurrentLevel(futureEpoch);
            if (futureLevel <= safeLevel) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return low;
    }

    // Get array of projected levels for the next `hours` hours, sampled every 30 min
    // Returns array of {:minutesFromNow => Number, :mg => Float}
    function getProjection(nowEpoch, hours) {
        var points = [];
        var intervalMinutes = 30;
        var totalMinutes = hours * 60;
        for (var m = 0; m <= totalMinutes; m += intervalMinutes) {
            var futureEpoch = nowEpoch + (m * 60);
            points.add({:minutesFromNow => m, :mg => getCurrentLevel(futureEpoch)});
        }
        return points;
    }

    // Get all doses (for storage serialization)
    function getDoses() {
        return _doses;
    }

    // Load doses from storage (deserialization)
    function setDoses(doses) {
        _doses = doses;
    }

    // Get today's drink log: array of {:mg, :time} for doses logged today
    function getTodayLog(nowEpoch) {
        var todayStart = getMidnightEpoch(nowEpoch);
        var log = [];
        for (var i = 0; i < _doses.size(); i++) {
            var dose = _doses[i];
            if (dose[:time] >= todayStart) {
                log.add(dose);
            }
        }
        return log;
    }

    // Calculate decayed amount for a single dose
    private function decayedAmount(originalMg, doseTimeEpoch, nowEpoch) {
        var elapsedSeconds = nowEpoch - doseTimeEpoch;
        if (elapsedSeconds <= 0) {
            return originalMg;
        }
        // mg * e^(decay_constant * elapsed_seconds)
        // equivalent to: mg * 0.5^(elapsed / half_life)
        var remaining = originalMg * Math.pow(0.5, elapsedSeconds.toFloat() / HALF_LIFE_SECONDS.toFloat());
        return remaining;
    }

    // Remove doses that have decayed below MIN_DOSE_MG
    private function pruneExpired(nowEpoch) {
        var kept = [];
        for (var i = 0; i < _doses.size(); i++) {
            var dose = _doses[i];
            if (decayedAmount(dose[:mg], dose[:time], nowEpoch) >= MIN_DOSE_MG) {
                kept.add(dose);
            }
        }
        _doses = kept;
    }

    // Get epoch seconds for midnight today (local time)
    private function getMidnightEpoch(nowEpoch) {
        var moment = new Time.Moment(nowEpoch);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        var midnight = Gregorian.moment({
            :year => info.year,
            :month => info.month,
            :day => info.day,
            :hour => 0,
            :minute => 0,
            :second => 0
        });
        return midnight.value();
    }
}
