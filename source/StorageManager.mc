using Toybox.Application;
using Toybox.Time;
using Toybox.Time.Gregorian;

class StorageManager {

    private const DOSES_KEY = "doses";
    private const LAST_SYNC_KEY = "lastSync";
    private const RETENTION_DAYS = 14;
    private const RETENTION_SECONDS = 1209600; // 14 * 24 * 60 * 60

    // Save all active doses to storage
    // doses: Array of {:mg => Float, :time => Number}
    function saveDoses(doses as Array) as Void {
        var storable = [];
        for (var i = 0; i < doses.size(); i++) {
            var dose = doses[i];
            var name = dose.hasKey(:name) ? dose[:name] : "";
            storable.add([dose[:mg], dose[:time], name]);
        }
        Application.Storage.setValue(DOSES_KEY, storable);
    }

    // Load doses from storage
    // Returns Array of {:mg => Float, :time => Number}
    function loadDoses() as Array {
        var storable = Application.Storage.getValue(DOSES_KEY);
        var doses = [];
        if (storable != null && storable instanceof Array) {
            for (var i = 0; i < storable.size(); i++) {
                var entry = storable[i];
                if (entry instanceof Array && entry.size() >= 2) {
                    var name = (entry.size() >= 3) ? entry[2].toString() : "";
                    doses.add({:mg => entry[0].toFloat(), :time => entry[1].toNumber(), :name => name});
                }
            }
        }
        return doses;
    }

    // Remove doses older than 14 days
    function pruneOldDoses(doses as Array, nowEpoch as Number) as Array {
        var cutoff = nowEpoch - RETENTION_SECONDS;
        var kept = [];
        for (var i = 0; i < doses.size(); i++) {
            if (doses[i][:time] >= cutoff) {
                kept.add(doses[i]);
            }
        }
        return kept;
    }

    // Save the epoch of the last successful sync to phone
    function saveLastSyncTime(epochSeconds as Number) as Void {
        Application.Storage.setValue(LAST_SYNC_KEY, epochSeconds);
    }

    // Get the epoch of the last successful sync
    function getLastSyncTime() as Number {
        var value = Application.Storage.getValue(LAST_SYNC_KEY);
        if (value != null && value instanceof Number) {
            return value;
        }
        return 0;
    }

    // Get doses added since a given epoch (for incremental sync)
    function getDosesSince(doses as Array, sinceEpoch as Number) as Array {
        var result = [];
        for (var i = 0; i < doses.size(); i++) {
            if (doses[i][:time] > sinceEpoch) {
                result.add(doses[i]);
            }
        }
        return result;
    }
}
