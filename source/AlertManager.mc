using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

class AlertManager {

    private const WARNING_THRESHOLD = 0.8;  // 80% of daily limit
    private const SLEEP_SAFE_MG = 50;
    private const SLEEP_WINDOW_SECONDS = 7200; // 2 hours before bedtime

    // Tracks which alerts have fired today (reset at midnight)
    private var _warningFiredDate as Number;
    private var _limitFiredDate as Number;
    private var _sleepFiredDate as Number;

    function initialize() {
        _warningFiredDate = -1;
        _limitFiredDate = -1;
        _sleepFiredDate = -1;
    }

    // Check and fire alerts based on current state
    // Returns a status string for the UI: "ok", "warning", or "over"
    function checkAlerts(dailyIntake as Number, currentLevel as Float, nowEpoch as Number) as String {
        var app = Application.getApp();
        var dailyLimit = app.getProperty("dailyLimit");
        if (dailyLimit == null) { dailyLimit = 400; }

        var today = getUniqueDay(nowEpoch);
        var status = "ok";

        // Check 100% limit first (higher priority)
        if (dailyIntake >= dailyLimit) {
            status = "over";
            var alertLimitReached = app.getProperty("alertLimitReached");
            if (alertLimitReached == null) { alertLimitReached = true; }
            if (_limitFiredDate != today && alertLimitReached) {
                _limitFiredDate = today;
                vibrateStrong();
            }
        }
        // Check 80% warning
        else if (dailyIntake >= (dailyLimit * WARNING_THRESHOLD).toNumber()) {
            status = "warning";
            var alertLimitWarning = app.getProperty("alertLimitWarning");
            if (alertLimitWarning == null) { alertLimitWarning = true; }
            if (_warningFiredDate != today && alertLimitWarning) {
                _warningFiredDate = today;
                vibrateGentle();
            }
        }

        // Check safe-to-sleep
        checkSleepAlert(currentLevel, nowEpoch, today);

        return status;
    }

    // Pure read-only status check for UI display (no side effects)
    function getStatus(dailyIntake as Number, dailyLimit as Number) as String {
        if (dailyIntake >= dailyLimit) {
            return "over";
        } else if (dailyIntake >= (dailyLimit * WARNING_THRESHOLD).toNumber()) {
            return "warning";
        }
        return "ok";
    }

    private function checkSleepAlert(currentLevel as Float, nowEpoch as Number, today as Number) as Void {
        var app = Application.getApp();
        var alertSafeToSleep = app.getProperty("alertSafeToSleep");
        if (alertSafeToSleep == null) { alertSafeToSleep = true; }
        if (!alertSafeToSleep) {
            return;
        }
        if (_sleepFiredDate == today) {
            return;
        }
        if (currentLevel >= SLEEP_SAFE_MG) {
            return;
        }
        // Check if within 2 hours of bedtime
        var bedtimeEpoch = Util.getBedtimeEpoch(nowEpoch);
        var timeUntilBed = bedtimeEpoch - nowEpoch;
        if (timeUntilBed > 0 && timeUntilBed <= SLEEP_WINDOW_SECONDS) {
            _sleepFiredDate = today;
            vibrateGentle();
        }
    }

    private function getUniqueDay(epochSeconds as Number) as Number {
        var moment = new Time.Moment(epochSeconds);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.year * 10000 + info.month * 100 + info.day;
    }

    private function vibrateGentle() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 500)]);
        }
    }

    private function vibrateStrong() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 300),
                new Attention.VibeProfile(0, 200),
                new Attention.VibeProfile(100, 300)
            ]);
        }
    }
}
