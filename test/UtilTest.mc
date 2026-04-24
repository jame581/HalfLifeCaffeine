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
