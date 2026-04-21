import Toybox.Application;

class DrinkPresets {

    private const PRESETS_KEY = "presets";

    // Each preset: {:name => String, :mg => Number}
    private var _presets;

    function initialize() {
        _presets = loadFromStorage();
    }

    function getPresets() {
        return _presets;
    }

    function getPresetCount() {
        return _presets.size();
    }

    function getPresetAt(index) {
        return _presets[index];
    }

    // Replace presets (e.g. from phone sync) and persist
    function setPresets(newPresets) {
        _presets = newPresets;
        saveToStorage();
    }

    private function loadFromStorage() {
        var stored = Application.Storage.getValue(PRESETS_KEY);
        if (stored == null || !(stored instanceof Array) || stored.size() == 0) {
            return getDefaults();
        }
        // Stored format: array of [name, mg] pairs (dictionaries don't serialize reliably)
        var result = [];
        for (var i = 0; i < stored.size(); i++) {
            var entry = stored[i];
            if (entry instanceof Array && entry.size() == 2) {
                result.add({:name => entry[0].toString(), :mg => entry[1].toNumber()});
            }
        }
        return result.size() > 0 ? result : getDefaults();
    }

    private function saveToStorage() {
        var storable = [];
        for (var i = 0; i < _presets.size(); i++) {
            var p = _presets[i];
            storable.add([p[:name], p[:mg]]);
        }
        Application.Storage.setValue(PRESETS_KEY, storable);
    }

    function getDefaults() {
        return [
            {:name => "Espresso", :mg => 63},
            {:name => "Americano", :mg => 77},
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
