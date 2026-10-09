import Toybox.Test;
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
    // Two different times on the same day should give the same ymd
    var morning = Gregorian.moment({
        :year => 2026, :month => 1, :day => 15,
        :hour => 3, :minute => 0, :second => 0
    });
    var evening = Gregorian.moment({
        :year => 2026, :month => 1, :day => 15,
        :hour => 23, :minute => 59, :second => 0
    });
    var ymd1 = Util.ymdFromEpoch(morning.value());
    var ymd2 = Util.ymdFromEpoch(evening.value());
    return (ymd1 == ymd2) && (ymd1 == 20260115);
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
