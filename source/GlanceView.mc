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

        // Glance process doesn't share state with the full-view app,
        // so instantiate model+storage locally and read doses fresh.
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

        // Big caffeine number
        dc.setColor(Colors.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 32 / 100, Graphics.FONT_GLANCE_NUMBER,
            mgText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Status line
        dc.setColor(Colors.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 72 / 100, Graphics.FONT_GLANCE,
            statusText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
