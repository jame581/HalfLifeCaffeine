import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Time;

(:glance)
class GlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc) {
        var now = Time.now().value();

        // Load doses directly from storage — the glance process doesn't
        // have access to the app's initialized managers
        var storage = new StorageManager();
        var model = new CaffeineModel();
        model.setDoses(storage.loadDoses());

        var level = model.getCurrentLevel(now);
        var mgText = Util.formatMg(level) + " mg";

        var statusText = "Clear";
        if (level >= 1.0) {
            var minutesToSafe = model.getMinutesToSafe(now, 50);
            if (minutesToSafe > 0) {
                statusText = "Safe in " + Util.formatDuration(minutesToSafe);
            }
        }

        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 30 / 100, Graphics.FONT_GLANCE,
            mgText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 70 / 100, Graphics.FONT_GLANCE,
            statusText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
