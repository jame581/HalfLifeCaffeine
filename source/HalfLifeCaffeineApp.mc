using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Time;

class HalfLifeCaffeineApp extends Application.AppBase {

    var caffeineModel as CaffeineModel?;
    var drinkPresets as DrinkPresets?;
    var storageManager as StorageManager?;
    var alertManager as AlertManager?;
    var syncManager as SyncManager?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        storageManager = new StorageManager();
        caffeineModel = new CaffeineModel();
        drinkPresets = new DrinkPresets();
        alertManager = new AlertManager();
        syncManager = new SyncManager(storageManager);
        syncManager.registerPhoneListener();

        // Load persisted doses
        var savedDoses = storageManager.loadDoses();
        var now = Time.now().value();
        savedDoses = storageManager.pruneOldDoses(savedDoses, now);
        caffeineModel.setDoses(savedDoses);
    }

    function onStop(state as Dictionary?) as Void {
        // Persist current doses
        if (caffeineModel != null && storageManager != null) {
            storageManager.saveDoses(caffeineModel.getDoses());
        }
    }

    function getGlanceView() as Array? {
        return [new GlanceView()];
    }

    function getView() as Array {
        return [new SummaryView(), new SummaryDelegate()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    // Helper to add a drink and trigger save + alerts
    function logDrink(presetIndex as Number) as Void {
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
}
