using Toybox.Application;
using Toybox.WatchUi;

class HalfLifeCaffeineApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
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
}
