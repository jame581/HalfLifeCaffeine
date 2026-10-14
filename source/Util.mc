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
