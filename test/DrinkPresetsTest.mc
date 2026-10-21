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

// A preset whose mg is not a positive number would crash the Add Drink
// menu's bedtime preview; it is skipped like any other malformed entry.
(:test)
function testPresetWithBadMgIsSkipped(logger) {
    Application.Properties.setValue("presets", [
        {"name" => "Bad", "mg" => "abc"},
        {"name" => "Zero", "mg" => 0},
        {"name" => "Good", "mg" => 85}
    ]);
    var presets = new DrinkPresets();
    var ok = presets.getPresetCount() == 1
        && presets.getPresetAt(0)[:name].equals("Good");
    Application.Properties.setValue("presets", []);
    return ok;
}

// An empty mg field can arrive as null; a numeric string or a Float is fine.
(:test)
function testPresetMgTypes(logger) {
    Application.Properties.setValue("presets", [
        {"name" => "Null", "mg" => null},
        {"name" => "Bool", "mg" => true},
        {"name" => "Text", "mg" => "85"},
        {"name" => "Float", "mg" => 85.7}
    ]);
    var presets = new DrinkPresets();
    var ok = presets.getPresetCount() == 2
        && presets.getPresetAt(0)[:name].equals("Text") && presets.getPresetAt(0)[:mg] == 85
        && presets.getPresetAt(1)[:name].equals("Float") && presets.getPresetAt(1)[:mg] == 85;
    Application.Properties.setValue("presets", []);
    return ok;
}
