using Toybox.Application;
using Toybox.Communications;
using Toybox.WatchUi;
using Toybox.Time;

class HalfLifeCaffeineApp extends Application.AppBase {

    var caffeineModel;
    var drinkPresets;
    var storageManager;
    var alertManager;
    var syncManager;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        storageManager = new StorageManager();
        caffeineModel = new CaffeineModel();
        drinkPresets = new DrinkPresets();
        alertManager = new AlertManager();
        syncManager = new SyncManager(storageManager);
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));

        // Load persisted doses
        var savedDoses = storageManager.loadDoses();
        var now = Time.now().value();
        savedDoses = storageManager.pruneOldDoses(savedDoses, now);
        caffeineModel.setDoses(savedDoses);
    }

    function onStop(state) {
        // Persist current doses
        if (caffeineModel != null && storageManager != null) {
            storageManager.saveDoses(caffeineModel.getDoses());
        }
    }

    function getGlanceView() {
        return [new GlanceView()];
    }

    function getView() {
        return [new SummaryView(), new SummaryDelegate()];
    }

    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }

    // Helper to add a drink and trigger save + alerts
    function logDrink(presetIndex) {
        var preset = drinkPresets.getPresetAt(presetIndex);
        var now = Time.now().value();
        caffeineModel.addDose(preset[:mg], now, preset[:name]);
        storageManager.saveDoses(caffeineModel.getDoses());
        syncManager.syncToPhone(caffeineModel.getDoses());

        var dailyIntake = caffeineModel.getDailyIntake(now);
        var currentLevel = caffeineModel.getCurrentLevel(now);
        alertManager.checkAlerts(dailyIntake, currentLevel, now);

        WatchUi.requestUpdate();
    }

    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        if (syncManager != null) {
            syncManager.handlePhoneMessage(msg.data);
        }
    }
}
