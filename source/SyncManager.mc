import Toybox.Communications;
import Toybox.Application;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class SyncManager {

    private var _storageManager;

    function initialize(storageManager) {
        _storageManager = storageManager;
    }

    function syncToPhone(allDoses) {
        var lastSync = _storageManager.getLastSyncTime();
        var newDoses = _storageManager.getDosesSince(allDoses, lastSync);

        if (newDoses.size() == 0) {
            return;
        }

        var payload = [];
        for (var i = 0; i < newDoses.size(); i++) {
            var dose = newDoses[i];
            var name = dose.hasKey(:name) ? dose[:name] : "";
            payload.add({
                "mg" => dose[:mg].toNumber(),
                "time" => dose[:time],
                "name" => name
            });
        }

        var message = {
            "type" => "drinks",
            "data" => payload
        };

        try {
            Communications.transmit(message, null, new SyncCallback(_storageManager));
        } catch (e) {
            System.println("SyncManager: phone sync failed - " + e.getErrorMessage());
        }
    }

    function handlePhoneMessage(data, drinkPresets) {
        if (data == null) { return; }

        if (data.hasKey("type") && data["type"].equals("settings")) {
            if (data.hasKey("dailyLimit")) {
                Application.Properties.setValue("dailyLimit", data["dailyLimit"]);
            }
            if (data.hasKey("bedtimeHour")) {
                Application.Properties.setValue("bedtimeHour", data["bedtimeHour"]);
            }
            if (data.hasKey("bedtimeMinute")) {
                Application.Properties.setValue("bedtimeMinute", data["bedtimeMinute"]);
            }
            if (data.hasKey("alertLimitWarning")) {
                Application.Properties.setValue("alertLimitWarning", data["alertLimitWarning"]);
            }
            if (data.hasKey("alertLimitReached")) {
                Application.Properties.setValue("alertLimitReached", data["alertLimitReached"]);
            }
            if (data.hasKey("alertSafeToSleep")) {
                Application.Properties.setValue("alertSafeToSleep", data["alertSafeToSleep"]);
            }
            if (data.hasKey("presets") && drinkPresets != null) {
                var incoming = data["presets"];
                if (incoming instanceof Array && incoming.size() > 0) {
                    var parsed = [];
                    for (var i = 0; i < incoming.size(); i++) {
                        var p = incoming[i];
                        if (p instanceof Dictionary && p.hasKey("name") && p.hasKey("mg")) {
                            parsed.add({:name => p["name"].toString(), :mg => p["mg"].toNumber()});
                        }
                    }
                    if (parsed.size() > 0) {
                        drinkPresets.setPresets(parsed);
                    }
                }
            }
        }

        WatchUi.requestUpdate();
    }
}

class SyncCallback extends Communications.ConnectionListener {

    private var _storageManager;

    function initialize(storageManager) {
        ConnectionListener.initialize();
        _storageManager = storageManager;
    }

    function onComplete() {
        _storageManager.saveLastSyncTime(Time.now().value());
        System.println("SyncManager: phone sync completed");
    }

    function onError() {
        System.println("SyncManager: phone sync error");
    }
}
