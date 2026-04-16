using Toybox.Communications;
using Toybox.Application;
using Toybox.Time;

class SyncManager {

    private var _storageManager as StorageManager;

    function initialize(storageManager as StorageManager) {
        _storageManager = storageManager;
    }

    function syncToPhone(allDoses as Array) as Void {
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

    function registerPhoneListener() as Void {
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
    }

    function onPhoneMessage(message as Communications.PhoneAppMessage) as Void {
        var data = message.data;
        if (data == null) { return; }

        if (data.hasKey("type") && data["type"].equals("settings")) {
            var app = Application.getApp();
            if (data.hasKey("dailyLimit")) {
                app.setProperty("dailyLimit", data["dailyLimit"]);
            }
            if (data.hasKey("bedtimeHour")) {
                app.setProperty("bedtimeHour", data["bedtimeHour"]);
            }
            if (data.hasKey("bedtimeMinute")) {
                app.setProperty("bedtimeMinute", data["bedtimeMinute"]);
            }
        }

        WatchUi.requestUpdate();
    }
}

class SyncCallback extends Communications.ConnectionListener {

    private var _storageManager as StorageManager;

    function initialize(storageManager as StorageManager) {
        ConnectionListener.initialize();
        _storageManager = storageManager;
    }

    function onComplete() as Void {
        _storageManager.saveLastSyncTime(Time.now().value());
    }

    function onError() as Void {
    }
}
