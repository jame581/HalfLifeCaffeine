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
        // Keep minimal — this runs in both glance and full-view processes.
        // Heavy init happens lazily in getInitialView().
    }

    function onStop(state as Dictionary?) as Void {
        if (caffeineModel != null && storageManager != null) {
            var now = Time.now().value();
            var doses = caffeineModel.getDoses();
            storageManager.rollUpYesterday(doses, now);
            storageManager.saveDoses(doses);
        }
    }

    function getGlanceView() {
        return [new GlanceView()];
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        initializeManagers();
        return [new SummaryView(), new SummaryDelegate()];
    }

    function initializeManagers() {
        Colors.applyTheme();
        if (caffeineModel != null) { return; }
        storageManager = new StorageManager();
        caffeineModel = new CaffeineModel();
        drinkPresets = new DrinkPresets();
        alertManager = new AlertManager();
        syncManager = new SyncManager();
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));

        caffeineModel.setHalfLifeSeconds(Util.getHalfLifeSeconds());
        var savedDoses = storageManager.loadDoses();
        var now = Time.now().value();
        storageManager.rollUpYesterday(savedDoses, now);
        // Keep yesterday and today (phone sync of an edit across midnight) and
        // the decay tail of the timeline's longest past window (6 h, TimelineView.RANGES)
        // in memory; older doses move to the archive. Each dose in memory costs
        // ~160 B and fenix 6 has little to spare, so the tail is cut at 7
        // half-lives of the current setting; raising the half-life later
        // ignores the archived tails (under 1 % of each dose).
        var since = storageManager.recentWindowStart(now,
            caffeineModel.getArchiveCutoff(now - 6 * 3600));
        savedDoses = storageManager.archiveOldDoses(savedDoses, since, now);
        caffeineModel.setDoses(savedDoses);
    }

    function onSettingsChanged() as Void {
        Colors.applyTheme();
        if (drinkPresets != null) {
            drinkPresets.reload();
        }
        if (caffeineModel != null) {
            caffeineModel.setHalfLifeSeconds(Util.getHalfLifeSeconds());
        }
        WatchUi.requestUpdate();
    }

    function logDrink(presetIndex) {
        var preset = drinkPresets.getPresetAt(presetIndex);
        var now = Time.now().value();
        caffeineModel.addDose(preset[:mg], now, preset[:name]);
        storageManager.saveDoses(caffeineModel.getDoses());
        syncManager.syncDayToPhone(caffeineModel.getDoses(), Util.ymdFromEpoch(now));

        var dailyIntake = caffeineModel.getDailyIntake(now);
        var currentLevel = caffeineModel.getCurrentLevel(now);
        alertManager.checkAlerts(dailyIntake, currentLevel, now);

        WatchUi.requestUpdate();
    }

    function removeDose(doseIndex) {
        if (caffeineModel == null) { return; }
        var now = Time.now().value();
        var ymd = Util.ymdFromEpoch(now);
        caffeineModel.removeDoseAt(doseIndex);
        storageManager.saveDoses(caffeineModel.getDoses());
        syncManager.syncDayToPhone(caffeineModel.getDoses(), ymd);
        WatchUi.requestUpdate();
    }

    function adjustDoseTime(doseIndex, offsetSeconds) {
        if (caffeineModel == null) { return; }
        var doses = caffeineModel.getDoses();
        if (doseIndex < 0 || doseIndex >= doses.size()) { return; }

        var oldYmd = Util.ymdFromEpoch(doses[doseIndex][:time]);
        var now = Time.now().value();
        var newTime = caffeineModel.adjustDoseTime(doseIndex, offsetSeconds, now);
        if (newTime < 0) { return; } // out-of-bounds defensive
        var newYmd = Util.ymdFromEpoch(newTime);

        var allDoses = caffeineModel.getDoses();
        storageManager.saveDoses(allDoses);

        syncManager.syncDayToPhone(allDoses, oldYmd);
        if (newYmd != oldYmd) {
            syncManager.syncDayToPhone(allDoses, newYmd);
        }
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
