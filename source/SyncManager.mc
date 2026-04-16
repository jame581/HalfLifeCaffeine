using Toybox.Communications;
using Toybox.Application;
using Toybox.Time;
using Toybox.WatchUi;

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

        Communications.transmit(message, null, new SyncCallback(_storageManager));
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
    }

    function onError() {
    }
}
