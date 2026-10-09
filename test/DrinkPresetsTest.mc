import Toybox.Test;
import Toybox.Application;

(:test)
function testDefaultPresetsAreTwelveWithNames(logger) {
    var defaults = new DrinkPresets().getDefaults();
    Application.Properties.setValue("presets", []);
    if (defaults.size() != 12) { return false; }
    for (var i = 0; i < defaults.size(); i++) {
        var name = defaults[i][:name];
        if (name == null || name.length() == 0 || defaults[i][:mg] <= 0) { return false; }
    }
    return true;
}

(:test)
function testSeedingFillsEmptyPresets(logger) {
    Application.Properties.setValue("presets", []);
    var presets = new DrinkPresets();
    var raw = Application.Properties.getValue("presets");
    var ok = presets.getPresetCount() == 12 && raw.size() == 12;
    Application.Properties.setValue("presets", []);
    return ok;
}

// An existing user's list must survive untouched: no re-seeding, no renaming.
(:test)
function testSeedingKeepsExistingPresets(logger) {
    Application.Properties.setValue("presets", [{"name" => "My Mate", "mg" => 85}]);
    var presets = new DrinkPresets();
    var ok = presets.getPresetCount() == 1
        && presets.getPresetAt(0)[:name].equals("My Mate")
        && presets.getPresetAt(0)[:mg] == 85;
    Application.Properties.setValue("presets", []);
    return ok;
}
