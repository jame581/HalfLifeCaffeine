import Toybox.Application;

class DrinkPresets {

    private const PRESETS_PROPERTY = "presets";

    // Each preset: {:name => String, :mg => Number}
    // Cached from Application.Properties on init / reload.
    private var _presets;

    function initialize() {
        seedDefaultsIfEmpty();
        _presets = loadFromProperties();
    }

    // First-run seeding: write the default preset list to Application.Properties
    // when the property is missing or empty. Without this, Garmin Connect Mobile's
    // settings editor opens with an empty list (the <defaults> block in
    // settings.xml only renders display hints — it does not populate the
    // property), so the user's first edit overwrites the displayed defaults
    // with just the new entry. Seeding ensures editing starts from a
    // pre-populated list. Re-seeds if the user deletes every preset.
    private function seedDefaultsIfEmpty() {
        var raw = Application.Properties.getValue(PRESETS_PROPERTY);
        if (raw != null && raw instanceof Array && raw.size() > 0) {
            return;
        }
        var defaults = getDefaults();
        var seedable = [];
        for (var i = 0; i < defaults.size(); i++) {
            seedable.add({"name" => defaults[i][:name], "mg" => defaults[i][:mg]});
        }
        Application.Properties.setValue(PRESETS_PROPERTY, seedable);
    }

    // Re-read presets from Application.Properties.
    // Called from HalfLifeCaffeineApp.onSettingsChanged when the user edits
    // presets in Garmin Connect Mobile / Garmin Express.
    function reload() {
        _presets = loadFromProperties();
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

    // Convert the array-of-dicts returned by Application.Properties (string keys)
    // into the symbol-keyed shape the rest of the app expects.
    // Falls back to baked-in defaults if the property is absent or malformed.
    private function loadFromProperties() {
        var raw = Application.Properties.getValue(PRESETS_PROPERTY);
        if (raw == null || !(raw instanceof Array) || raw.size() == 0) {
            return getDefaults();
        }
        var result = [];
        for (var i = 0; i < raw.size(); i++) {
            var entry = raw[i];
            if (entry instanceof Dictionary && entry.hasKey("name") && entry.hasKey("mg")) {
                result.add({:name => entry["name"].toString(), :mg => entry["mg"].toNumber()});
            }
        }
        return result.size() > 0 ? result : getDefaults();
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
