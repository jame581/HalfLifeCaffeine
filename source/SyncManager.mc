import Toybox.Communications;
import Toybox.Application;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class SyncManager {

    function initialize(storageManager) {
        // storageManager parameter kept for API compatibility
    }

    // Send a replace-day resync for the given local-day ymd.
    // Filters allDoses to that day and transmits {type, mode, ymd, data}.
    // Companion is expected to drop existing entries for ymd and append data.
    function syncDayToPhone(allDoses, ymd) {
        var payload = [];
        for (var i = 0; i < allDoses.size(); i++) {
            var dose = allDoses[i];
            if (Util.ymdFromEpoch(dose[:time]) != ymd) { continue; }
            var name = dose.hasKey(:name) ? dose[:name] : "";
            payload.add({
                "mg" => dose[:mg].toNumber(),
                "time" => dose[:time],
                "name" => name
            });
        }

        var message = {
            "type" => "drinks",
            "mode" => "replace-day",
            "ymd" => ymd,
            "data" => payload
        };

        try {
            Communications.transmit(message, null, new SyncCallback());
        } catch (e) {
            System.println("SyncManager: phone sync failed - " + e.getErrorMessage());
        }
    }

    function handlePhoneMessage(data) {
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
        }

        WatchUi.requestUpdate();
    }
}

class SyncCallback extends Communications.ConnectionListener {

    function initialize() {
        ConnectionListener.initialize();
    }

    function onComplete() {
        System.println("SyncManager: phone sync completed");
    }

    function onError() {
        System.println("SyncManager: phone sync error");
    }
}
