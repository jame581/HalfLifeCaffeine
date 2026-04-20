import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

class HalfLifeCaffeineApp extends Application.AppBase {

    var caffeineModel;
    var drinkPresets;
    var storageManager;
    var alertManager;
    var syncManager;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        storageManager = new StorageManager();
        caffeineModel = new CaffeineModel();
        drinkPresets = new DrinkPresets();
        alertManager = new AlertManager();
        syncManager = new SyncManager(storageManager);
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));

        var savedDoses = storageManager.loadDoses();
        var now = Time.now().value();
        savedDoses = storageManager.pruneOldDoses(savedDoses, now);
        caffeineModel.setDoses(savedDoses);
        caffeineModel.pruneExpiredDoses(now);
    }

    function onStop(state as Dictionary?) as Void {
        if (caffeineModel != null && storageManager != null) {
            storageManager.saveDoses(caffeineModel.getDoses());
        }
    }

    function getGlanceView() as [WatchUi.GlanceView] or Null {
        return [new GlanceView()];
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new SummaryView(), new SummaryDelegate()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    function logDrink(presetIndex) {
        var preset = drinkPresets.getPresetAt(presetIndex);
        var now = Time.now().value();
        caffeineModel.addDose(preset[:mg], now, preset[:name]);
        caffeineModel.pruneExpiredDoses(now);
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

function getApp() as HalfLifeCaffeineApp {
    return Application.getApp() as HalfLifeCaffeineApp;
}
