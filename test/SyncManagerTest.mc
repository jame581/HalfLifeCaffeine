import Toybox.Test;
import Toybox.Application;

// A daily limit from the phone that is not a positive number is ignored, so
// every screen and the alerts keep agreeing on the stored limit.
(:test)
function testPhoneDailyLimitRejectsBadValues(logger) {
    var old = Application.Properties.getValue("dailyLimit");
    var sync = new SyncManager();
    Application.Properties.setValue("dailyLimit", 300);
    sync.handlePhoneMessage({"type" => "settings", "dailyLimit" => 0});
    var ok = Application.Properties.getValue("dailyLimit") == 300;
    sync.handlePhoneMessage({"type" => "settings", "dailyLimit" => -5});
    ok = ok && Application.Properties.getValue("dailyLimit") == 300;
    sync.handlePhoneMessage({"type" => "settings", "dailyLimit" => null});
    ok = ok && Application.Properties.getValue("dailyLimit") == 300;
    sync.handlePhoneMessage({"type" => "settings", "dailyLimit" => 350});
    ok = ok && Application.Properties.getValue("dailyLimit") == 350;
    Application.Properties.setValue("dailyLimit", old);
    return ok;
}

// A Float limit is stored as a whole number; one that rounds down to 0 is ignored.
(:test)
function testPhoneDailyLimitFloat(logger) {
    var old = Application.Properties.getValue("dailyLimit");
    var sync = new SyncManager();
    Application.Properties.setValue("dailyLimit", 300);
    sync.handlePhoneMessage({"type" => "settings", "dailyLimit" => 0.5});
    var ok = Application.Properties.getValue("dailyLimit") == 300;
    sync.handlePhoneMessage({"type" => "settings", "dailyLimit" => 450.0});
    ok = ok && Application.Properties.getValue("dailyLimit") == 450;
    Application.Properties.setValue("dailyLimit", old);
    return ok;
}

// A sleep-safe level from the phone is stored rounded and kept in 25-100;
// a settings message without it, or with something that is not a number,
// leaves the stored level alone.
(:test)
function testPhoneSleepSafeMg(logger) {
    var old = Application.Properties.getValue("sleepSafeMg");
    var sync = new SyncManager();
    Application.Properties.setValue("sleepSafeMg", 50);
    sync.handlePhoneMessage({"type" => "settings", "dailyLimit" => 400});
    var ok = Application.Properties.getValue("sleepSafeMg") == 50;
    sync.handlePhoneMessage({"type" => "settings", "sleepSafeMg" => 30});
    ok = ok && Application.Properties.getValue("sleepSafeMg") == 30;
    sync.handlePhoneMessage({"type" => "settings", "sleepSafeMg" => 300});
    ok = ok && Application.Properties.getValue("sleepSafeMg") == 100;
    sync.handlePhoneMessage({"type" => "settings", "sleepSafeMg" => 42.6});
    ok = ok && Application.Properties.getValue("sleepSafeMg") == 43;
    Application.Properties.setValue("sleepSafeMg", 30);
    sync.handlePhoneMessage({"type" => "settings", "sleepSafeMg" => "40"});
    ok = ok && Application.Properties.getValue("sleepSafeMg") == 30;
    sync.handlePhoneMessage({"type" => "settings", "sleepSafeMg" => null});
    ok = ok && Application.Properties.getValue("sleepSafeMg") == 30;
    Application.Properties.setValue("sleepSafeMg", old);
    return ok;
}
