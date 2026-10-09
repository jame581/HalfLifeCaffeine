import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Lang;

(:glance)
module Util {

    // Format minutes as "Xh Ym" (e.g. 200 → "3h 20m"). The unit strings are
    // passed in so this stays free of resource loading and unit-testable.
    function formatDuration(totalMinutes, hourUnit, minuteUnit) {
        if (totalMinutes <= 0) {
            return "0" + minuteUnit;
        }
        var hours = (totalMinutes / 60).toNumber();
        var mins = (totalMinutes % 60).toNumber();
        if (hours > 0 && mins > 0) {
            return hours + hourUnit + " " + mins + minuteUnit;
        } else if (hours > 0) {
            return hours + hourUnit;
        } else {
            return mins + minuteUnit;
        }
    }

    // Format a ymd int (20260424) with a template: $1$ = month abbreviation in
    // the watch language, $2$ = day, $3$ = year. Only the month name comes from
    // the system, so the lookup uses a fixed, always-valid date (the 15th of
    // that month in 2024, UTC on both sides) and the caller's year and day never
    // reach Gregorian.moment, which throws on anything that is not a real date.
    // A month outside 1-12 yields "?".
    function formatYmd(ymd, template) {
        var year = (ymd / 10000).toNumber();
        var month = ((ymd / 100) % 100).toNumber();
        var day = (ymd % 100).toNumber();
        var monthStr = "?";
        if (month >= 1 && month <= 12) {
            var moment = Gregorian.moment({
                :year => 2024, :month => month, :day => 15,
                :hour => 12, :minute => 0, :second => 0
            });
            monthStr = Gregorian.utcInfo(moment, Time.FORMAT_MEDIUM).month;
        }
        return Lang.format(template, [monthStr, day.toString(), year.toString()]);
    }

    // Format epoch to "HH:MM" local time
    function formatTime(epochSeconds) {
        var moment = new Time.Moment(epochSeconds);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        var h = info.hour.format("%02d");
        var m = info.min.format("%02d");
        return h + ":" + m;
    }

    // Format a caffeine level to a display string (e.g. 142.7 → "143")
    function formatMg(mg) {
        return (mg + 0.5).toNumber().toString();
    }

    // Read the user-configured caffeine half-life and return it in seconds.
    // Defaults to 5.7h if unset, clamps to [3, 10] hours. Used by both the
    // full-view and glance processes to inject the half-life into CaffeineModel.
    function getHalfLifeSeconds() {
        var hours = Application.Properties.getValue("halfLifeHours");
        if (hours == null) { hours = 5.7; }
        if (hours < 3.0) { hours = 3.0; }
        if (hours > 10.0) { hours = 10.0; }
        return (hours * 3600).toNumber();
    }

    // Get bedtime as epoch seconds for today
    function getBedtimeEpoch(nowEpoch) {
        var hour = Application.Properties.getValue("bedtimeHour");
        var minute = Application.Properties.getValue("bedtimeMinute");

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
        var bedtimeEpoch = bedtime.value();
        // If bedtime is already past (e.g. after-midnight bedtime called in evening), roll to next day
        if (bedtimeEpoch <= nowEpoch) {
            bedtimeEpoch += 86400; // Add 24 hours
        }
        return bedtimeEpoch;
    }

    // Convert epoch seconds to integer YYYYMMDD date key (local time)
    function ymdFromEpoch(epochSeconds) {
        var moment = new Time.Moment(epochSeconds);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.year.toNumber() * 10000
             + info.month.toNumber() * 100
             + info.day.toNumber();
    }

    // Midnight epoch for the local day containing the given epoch
    function midnightEpochFor(epochSeconds) {
        var moment = new Time.Moment(epochSeconds);
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
