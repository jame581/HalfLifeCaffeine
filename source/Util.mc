import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Lang;
import Toybox.System;

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

    // Format a ymd int (20260424) with a template: $1$ = month name, $2$ = day,
    // $3$ = year. monthNames holds the 12 names from the translation sheets
    // (MonthNames.load()); the system's month names are not used because some
    // languages come back mis-decoded (Czech "Říjen" as "Å˜Ã­jen"). Nothing here
    // goes through Gregorian.moment, so invalid dates format without throwing.
    // A month outside 1-12 yields "?".
    function formatYmd(ymd, template, monthNames) {
        var year = (ymd / 10000).toNumber();
        var month = ((ymd / 100) % 100).toNumber();
        var day = (ymd % 100).toNumber();
        var monthStr = "?";
        if (month >= 1 && month <= 12) {
            monthStr = monthNames[month - 1];
        }
        return Lang.format(template, [monthStr, day.toString(), year.toString()]);
    }

    // Local time of day, in the watch's 12h/24h setting: "22:07" or "10:07 PM".
    // am/pm are the TimeAM/TimePM strings, loaded by the caller.
    function formatTime(epochSeconds, am, pm) {
        var info = Gregorian.info(new Time.Moment(epochSeconds), Time.FORMAT_SHORT);
        return formatClock(info.hour, info.min, System.getDeviceSettings().is24Hour, am, pm);
    }

    // "22:07" (24h) or "10:07 PM" (12h: no leading zero, 12 for midnight and noon).
    function formatClock(hour, min, is24, am, pm) {
        var m = min.format("%02d");
        if (is24) {
            return hour.format("%02d") + ":" + m;
        }
        var h = hour % 12;
        if (h == 0) { h = 12; }
        return h.toString() + ":" + m + " " + (hour < 12 ? am : pm);
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

    // Daily limit in mg. A value synced from the phone can be missing, a Float,
    // or nonsense; anything that is not a positive number means the default 400.
    function sanitizeDailyLimit(value) {
        if (value instanceof Lang.Number || value instanceof Lang.Float) {
            var n = value.toNumber();
            if (n > 0) { return n; }
        }
        return 400;
    }

    function getDailyLimit() {
        return sanitizeDailyLimit(Application.Properties.getValue("dailyLimit"));
    }

    // Safe-to-sleep level in mg. Missing or not a number means the default 50;
    // otherwise rounded to a whole number and kept in 25-100. Checked on every
    // read: the companion page saves through ciq://settings, not through
    // SyncManager, so a stored value may never have been checked.
    function sanitizeSleepSafeMg(value) {
        if (value instanceof Lang.Number || value instanceof Lang.Float) {
            var n = (value + 0.5).toNumber();
            if (n < 25) { return 25; }
            if (n > 100) { return 100; }
            return n;
        }
        return 50;
    }

    function getSleepSafeMg() {
        return sanitizeSleepSafeMg(Application.Properties.getValue("sleepSafeMg"));
    }

    // Which safe-to-sleep line to show: 0 = all clear (no caffeine to speak of,
    // or already under the level), 1 = a time or countdown, 2 = still above the
    // level at the end of the 24 h getMinutesToSafe searches (a clock time there
    // would mislead, so the views show "24h+").
    function safeSleepKind(level, minutesToSafe) {
        if (level < 1.0 || minutesToSafe <= 0) { return 0; }
        if (minutesToSafe >= 1440) { return 2; }
        return 1;
    }

    // How the safe-to-sleep line reads: 0 = clock time (default), 1 = countdown.
    function getSleepTimeFormat() {
        var v = Application.Properties.getValue("sleepTimeFormat");
        if (v instanceof Lang.Number && v == 1) { return 1; }
        return 0;
    }

    // Colour for a day's intake against the limit; same thresholds as AlertManager.
    // Used by every screen that colours an intake, so they agree at the limit.
    function intakeColor(intake, limit) {
        if (intake >= limit) { return Colors.DANGER; }
        if (intake >= (limit * 0.8).toNumber()) { return Colors.WARNING; }
        return Colors.ACCENT;
    }

    // Get bedtime as epoch seconds for today
    function getBedtimeEpoch(nowEpoch) {
        var hour = Application.Properties.getValue("bedtimeHour");
        var minute = Application.Properties.getValue("bedtimeMinute");

        // A value synced from the phone can be missing or a Float.
        if (hour == null) { hour = 22; }
        if (minute == null) { minute = 30; }
        var secondsOfDay = hour.toNumber() * 3600 + minute.toNumber() * 60;
        var bedtimeEpoch = localTimeOnDay(nowEpoch, secondsOfDay);
        // If bedtime is already past (e.g. after-midnight bedtime called in evening), roll to next day
        if (bedtimeEpoch <= nowEpoch) {
            // Midnight + 36 h is around noon tomorrow, whatever the clock change.
            bedtimeEpoch = localTimeOnDay(midnightEpochFor(nowEpoch) + 129600, secondsOfDay);
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
        return localTimeOnDay(epochSeconds, 0);
    }

    // Seconds since local midnight on the local clock at the given epoch
    function secondsIntoLocalDay(epochSeconds) {
        var info = Gregorian.info(new Time.Moment(epochSeconds), Time.FORMAT_SHORT);
        return info.hour * 3600 + info.min * 60 + info.sec;
    }

    // Epoch at which the local clock reads secondsOfDay on the local day
    // containing the given epoch. Gregorian.info returns local fields but
    // Gregorian.moment reads its fields as UTC, so building a local time out of
    // the two lands off by the UTC offset. Shift by the local time of day
    // instead; the correction absorbs a daylight-saving change within the day.
    function localTimeOnDay(epochSeconds, secondsOfDay) {
        var t = epochSeconds - secondsIntoLocalDay(epochSeconds) + secondsOfDay;
        var off = secondsIntoLocalDay(t) - secondsOfDay;
        if (off > 43200) { off -= 86400; }
        if (off < -43200) { off += 86400; }
        return t - off;
    }
}
