import Toybox.Test;
import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:test)
function testYmdFromEpochConvertsCorrectly(logger) {
    // 2026-04-24 12:00:00 UTC — but ymd uses local time, so compute from Gregorian
    var moment = Gregorian.moment({
        :year => 2026, :month => 4, :day => 24,
        :hour => 12, :minute => 0, :second => 0
    });
    var ymd = Util.ymdFromEpoch(moment.value());
    return (ymd == 20260424);
}

(:test)
function testYmdFromEpochIsDateOnly(logger) {
    // Two different local times on the same day should give the same ymd
    var now = Time.now().value();
    var ymd1 = Util.ymdFromEpoch(Util.localTimeOnDay(now, 3 * 3600));
    var ymd2 = Util.ymdFromEpoch(Util.localTimeOnDay(now, 23 * 3600 + 59 * 60));
    return (ymd1 == ymd2) && (ymd1 == Util.ymdFromEpoch(now));
}

(:test)
function testYmdFromEpochHandlesMonthBoundary(logger) {
    var endOfJan = Gregorian.moment({
        :year => 2026, :month => 1, :day => 31,
        :hour => 20, :minute => 0, :second => 0
    });
    var startOfFeb = Gregorian.moment({
        :year => 2026, :month => 2, :day => 1,
        :hour => 2, :minute => 0, :second => 0
    });
    return (Util.ymdFromEpoch(endOfJan.value()) == 20260131)
        && (Util.ymdFromEpoch(startOfFeb.value()) == 20260201);
}

(:test)
function testFormatDurationHoursAndMinutes(logger) {
    return Util.formatDuration(200, "h", "m").equals("3h 20m");
}

(:test)
function testFormatDurationMinutesOnly(logger) {
    return Util.formatDuration(45, "h", "m").equals("45m");
}

(:test)
function testFormatDurationWholeHours(logger) {
    return Util.formatDuration(120, "h", "m").equals("2h");
}

(:test)
function testFormatDurationZeroAndNegative(logger) {
    return Util.formatDuration(0, "h", "m").equals("0m")
        && Util.formatDuration(-5, "h", "m").equals("0m");
}

(:test)
function testFormatDurationUsesGivenUnits(logger) {
    return Util.formatDuration(200, "t", "min").equals("3t 20min");
}

(:test)
function testFormatYmdPutsDayAndYearWhereTemplateSays(logger) {
    return Util.formatYmd(20260424, "$2$|$3$").equals("24|2026");
}

(:test)
function testFormatYmdMonthIsNotEmpty(logger) {
    var month = Util.formatYmd(20260424, "$1$");
    return month.length() > 0 && !month.equals("?");
}

(:test)
function testFormatYmdSurvivesInvalidDate(logger) {
    // Day 00 makes Gregorian.moment throw "Invalid Value"; the formatter must not.
    return Util.formatYmd(0, "$1$ $2$").equals("? 0")
        && Util.formatYmd(20260600, "$2$|$3$").equals("0|2026");
}

(:test)
function testFormatYmdSurvivesOutOfRangeYearAndDay(logger) {
    // Year 0 and Feb 31 are not valid dates either; only the month is looked up.
    return Util.formatYmd(101, "$2$|$3$").equals("1|0")
        && Util.formatYmd(20260231, "$2$|$3$").equals("31|2026")
        && !Util.formatYmd(20260231, "$1$").equals("?");
}

// Regression: Gregorian.moment reads its fields as UTC while Gregorian.info
// returns local ones, so "local midnight" used to land off by the UTC offset
// (02:00 in UTC+2) and drinks logged before that were missing from today.
(:test)
function testMidnightEpochForIsLocalMidnight(logger) {
    var now = Time.now().value();
    var midnight = Util.midnightEpochFor(now);
    var info = Gregorian.info(new Time.Moment(midnight), Time.FORMAT_SHORT);
    return info.hour == 0 && info.min == 0 && info.sec == 0
        && midnight <= now && now - midnight < 90000
        && Util.ymdFromEpoch(midnight) == Util.ymdFromEpoch(now);
}

(:test)
function testLocalTimeOnDayReadsRequestedClockTime(logger) {
    var now = Time.now().value();
    var t = Util.localTimeOnDay(now, 13 * 3600 + 45 * 60);
    var info = Gregorian.info(new Time.Moment(t), Time.FORMAT_SHORT);
    return info.hour == 13 && info.min == 45
        && Util.ymdFromEpoch(t) == Util.ymdFromEpoch(now);
}

(:test)
function testBedtimeEpochIsNextLocalBedtime(logger) {
    var now = Time.now().value();
    var bedtime = Util.getBedtimeEpoch(now);
    var info = Gregorian.info(new Time.Moment(bedtime), Time.FORMAT_SHORT);
    return info.hour == Application.Properties.getValue("bedtimeHour")
        && info.min == Application.Properties.getValue("bedtimeMinute")
        && bedtime > now && bedtime - now <= 90000;
}
