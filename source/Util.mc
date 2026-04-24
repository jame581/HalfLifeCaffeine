import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:glance)
module Util {

    // Format minutes as "Xh Ym" (e.g. 200 → "3h 20m")
    function formatDuration(totalMinutes) {
        if (totalMinutes <= 0) {
            return "0m";
        }
        var hours = (totalMinutes / 60).toNumber();
        var mins = (totalMinutes % 60).toNumber();
        if (hours > 0 && mins > 0) {
            return hours + "h " + mins + "m";
        } else if (hours > 0) {
            return hours + "h";
        } else {
            return mins + "m";
        }
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
