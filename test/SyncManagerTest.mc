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
