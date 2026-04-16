using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;

class CaffeineModel {

    // Half-life of caffeine in seconds (5.7 hours)
    private const HALF_LIFE_SECONDS = 20520;
    // ln(0.5) precomputed for decay formula
    private const LN_HALF = -0.6931471805599453d;
    // Decay constant: ln(0.5) / half_life
    private const DECAY_CONSTANT = -0.00003377d; // LN_HALF / 20520
    // Minimum mg before a dose is considered cleared
    private const MIN_DOSE_MG = 1.0;

    // Array of active doses: each is {:mg => Float, :time => Number (epoch seconds)}
    private var _doses as Array;

    function initialize() {
        _doses = [];
    }

    // Add a new caffeine dose
    function addDose(mg as Number, timeEpoch as Number, name as String) as Void {
        _doses.add({:mg => mg.toFloat(), :time => timeEpoch, :name => name});
    }

    // Get current total caffeine level in mg
    function getCurrentLevel(nowEpoch as Number) as Float {
        var total = 0.0;
        pruneExpired(nowEpoch);
        for (var i = 0; i < _doses.size(); i++) {
            var dose = _doses[i];
            total += decayedAmount(dose[:mg], dose[:time], nowEpoch);
        }
        return total;
    }

    // Get total caffeine consumed today (sum of original doses, not decayed)
    function getDailyIntake(nowEpoch as Number) as Number {
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
    function getMinutesToSafe(nowEpoch as Number, safeLevel as Number) as Number {
        var currentLevel = getCurrentLevel(nowEpoch);
        if (currentLevel <= safeLevel) {
            return 0;
        }
        // Binary search: check in 1-minute increments over next 24 hours
        var low = 0;
        var high = 1440; // 24 hours in minutes
        while (low < high) {
            var mid = (low + high) / 2;
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
    function getProjection(nowEpoch as Number, hours as Number) as Array {
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
    function getDoses() as Array {
        return _doses;
    }

    // Load doses from storage (deserialization)
    function setDoses(doses as Array) as Void {
        _doses = doses;
    }

    // Get today's drink log: array of {:mg, :time} for doses logged today
    function getTodayLog(nowEpoch as Number) as Array {
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
    private function decayedAmount(originalMg as Float, doseTimeEpoch as Number, nowEpoch as Number) as Float {
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
    private function pruneExpired(nowEpoch as Number) as Void {
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
    private function getMidnightEpoch(nowEpoch as Number) as Number {
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
