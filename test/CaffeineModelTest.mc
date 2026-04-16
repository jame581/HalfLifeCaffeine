using Toybox.Test;
using Toybox.Time;
using Toybox.Math;

(:test)
function testSingleDoseDecayAtZeroTime(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    model.addDose(100, now, "Test");
    var level = model.getCurrentLevel(now);
    return (level >= 99 && level <= 101);
}

(:test)
function testSingleDoseDecayAtOneHalfLife(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    model.addDose(100, now - 20520, "Test");
    var level = model.getCurrentLevel(now);
    return (level >= 48 && level <= 52);
}

(:test)
function testSingleDoseDecayAtTwoHalfLives(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    model.addDose(100, now - 41040, "Test");
    var level = model.getCurrentLevel(now);
    return (level >= 23 && level <= 27);
}

(:test)
function testMultipleDosesStack(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    model.addDose(100, now, "Test");
    model.addDose(63, now, "Test");
    var level = model.getCurrentLevel(now);
    return (level >= 161 && level <= 165);
}

(:test)
function testExpiredDosesArePruned(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    model.addDose(100, now - 172800, "Test");
    var level = model.getCurrentLevel(now);
    return (level < 1);
}

(:test)
function testDailyIntakeSumsAllDosesToday(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    model.addDose(95, now - 3600, "Test");
    model.addDose(63, now - 1800, "Test");
    var daily = model.getDailyIntake(now);
    return (daily == 158);
}

(:test)
function testTimeToSafeWithNoDoses(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    var minutes = model.getMinutesToSafe(now, 50);
    return (minutes == 0);
}

(:test)
function testTimeToSafeWithActiveDose(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    model.addDose(200, now, "Test");
    var minutes = model.getMinutesToSafe(now, 50);
    return (minutes >= 680 && minutes <= 690);
}
