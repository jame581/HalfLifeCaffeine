using Toybox.Application;
using Toybox.Attention;
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

        var today = getDayOfYear(nowEpoch);
        var status = "ok";

        // Check 100% limit first (higher priority)
        if (dailyIntake >= dailyLimit) {
            status = "over";
            if (_limitFiredDate != today && app.getProperty("alertLimitReached")) {
                _limitFiredDate = today;
                vibrateStrong();
            }
        }
        // Check 80% warning
        else if (dailyIntake >= (dailyLimit * WARNING_THRESHOLD).toNumber()) {
            status = "warning";
            if (_warningFiredDate != today && app.getProperty("alertLimitWarning")) {
                _warningFiredDate = today;
                vibrateGentle();
            }
        }

        // Check safe-to-sleep
        checkSleepAlert(currentLevel, nowEpoch, today);

        return status;
    }

    private function checkSleepAlert(currentLevel as Float, nowEpoch as Number, today as Number) as Void {
        var app = Application.getApp();
        if (!app.getProperty("alertSafeToSleep")) {
            return;
        }
        if (_sleepFiredDate == today) {
            return;
        }
        if (currentLevel >= SLEEP_SAFE_MG) {
            return;
        }
        // Check if within 2 hours of bedtime
        var bedtimeEpoch = getBedtimeEpoch(nowEpoch);
        var timeUntilBed = bedtimeEpoch - nowEpoch;
        if (timeUntilBed > 0 && timeUntilBed <= SLEEP_WINDOW_SECONDS) {
            _sleepFiredDate = today;
            vibrateGentle();
        }
    }

    private function getBedtimeEpoch(nowEpoch as Number) as Number {
        var app = Application.getApp();
        var hour = app.getProperty("bedtimeHour");
        var minute = app.getProperty("bedtimeMinute");
        if (hour == null) { hour = 22; }
        if (minute == null) { minute = 30; }

        var moment = new Time.Moment(nowEpoch);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        var bedtime = Gregorian.moment({
            :year => info.year,
            :month => info.month,
            :day => info.day,
            :hour => hour,
            :minute => minute,
            :second => 0
        });
        return bedtime.value();
    }

    private function getDayOfYear(epochSeconds as Number) as Number {
        var moment = new Time.Moment(epochSeconds);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.day_of_year;
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
