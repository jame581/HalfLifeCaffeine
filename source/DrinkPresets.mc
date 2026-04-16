using Toybox.Application;
using Toybox.Lang;

class DrinkPresets {

    // Each preset: {:name => String, :mg => Number}
    private var _presets as Array;

    function initialize() {
        _presets = getDefaults();
    }

    function getPresets() as Array {
        return _presets;
    }

    function getPresetCount() as Number {
        return _presets.size();
    }

    function getPresetAt(index as Number) as Dictionary {
        return _presets[index];
    }

    function getDefaults() as Array {
        return [
            {:name => "Espresso", :mg => 63},
            {:name => "Drip Coffee (S)", :mg => 95},
            {:name => "Drip Coffee (L)", :mg => 190},
            {:name => "Latte", :mg => 63},
            {:name => "Green Tea", :mg => 30},
            {:name => "Black Tea", :mg => 47},
            {:name => "Red Bull", :mg => 80},
            {:name => "Monster", :mg => 160},
            {:name => "Cola", :mg => 34},
            {:name => "Dark Chocolate", :mg => 25},
            {:name => "Pre-Workout", :mg => 200}
        ];
    }
}
