import Toybox.Test;
import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:test)
function testYmdFromEpochConvertsCorrectly(logger) {
    // Local noon on 2026-04-24, whatever the time zone.
    var ymd = Util.ymdFromEpoch(Util.localTimeOnDay(new StorageManager().epochForYmdPublic(20260424), 12 * 3600));
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
    // Local 23:59 on Jan 31 and local 00:01 on Feb 1.
    var endOfJan = Util.localTimeOnDay(new StorageManager().epochForYmdPublic(20260131), 23 * 3600 + 59 * 60);
    var startOfFeb = Util.localTimeOnDay(new StorageManager().epochForYmdPublic(20260201), 60);
    return (Util.ymdFromEpoch(endOfJan) == 20260131)
        && (Util.ymdFromEpoch(startOfFeb) == 20260201);
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

const TEST_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

(:test)
function testFormatYmdPutsDayAndYearWhereTemplateSays(logger) {
    return Util.formatYmd(20260424, "$2$|$3$", TEST_MONTHS).equals("24|2026");
}

(:test)
function testFormatYmdTakesMonthFromGivenNames(logger) {
    return Util.formatYmd(20260101, "$1$", TEST_MONTHS).equals("Jan")
        && Util.formatYmd(20261014, "$2$. $1$ $3$", ["1.", "2.", "3.", "4.", "5.", "6.",
            "7.", "8.", "9.", "10.", "11.", "12."]).equals("14. 10. 2026")
        && Util.formatYmd(20261231, "$1$", TEST_MONTHS).equals("Dec");
}

(:test)
function testFormatYmdSurvivesInvalidDate(logger) {
    // Day 00 and month 00 are not real dates; the formatter must not throw.
    return Util.formatYmd(0, "$1$ $2$", TEST_MONTHS).equals("? 0")
        && Util.formatYmd(20260600, "$2$|$3$", TEST_MONTHS).equals("0|2026")
        && Util.formatYmd(20261300, "$1$", TEST_MONTHS).equals("?");
}

(:test)
function testFormatYmdSurvivesOutOfRangeYearAndDay(logger) {
    // Year 0 and Feb 31 are not valid dates either; only the month is looked up.
    return Util.formatYmd(101, "$2$|$3$", TEST_MONTHS).equals("1|0")
        && Util.formatYmd(20260231, "$2$|$1$", TEST_MONTHS).equals("31|Feb");
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

(:test)
function testSanitizeDailyLimit(logger) {
    return Util.sanitizeDailyLimit(null) == 400
        && Util.sanitizeDailyLimit(0) == 400
        && Util.sanitizeDailyLimit(-50) == 400
        && Util.sanitizeDailyLimit("abc") == 400
        && Util.sanitizeDailyLimit(300) == 300
        && Util.sanitizeDailyLimit(350.7) == 350;
}

(:test)
function testIntakeColorThresholds(logger) {
    return Util.intakeColor(0, 400) == Colors.ACCENT
        && Util.intakeColor(319, 400) == Colors.ACCENT
        && Util.intakeColor(320, 400) == Colors.WARNING
        && Util.intakeColor(399, 400) == Colors.WARNING
        && Util.intakeColor(400, 400) == Colors.DANGER
        && Util.intakeColor(900, 400) == Colors.DANGER;
}
