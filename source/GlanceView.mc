using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Time;

(:glance)
class GlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc) {
        var app = Application.getApp();
        var now = Time.now().value();

        var level = 0.0;
        var statusText = "Clear";

        if (app.caffeineModel != null) {
            level = app.caffeineModel.getCurrentLevel(now);
            if (level >= 1.0) {
                var minutesToSafe = app.caffeineModel.getMinutesToSafe(now, 50);
                if (minutesToSafe > 0) {
                    statusText = "Safe in " + Util.formatDuration(minutesToSafe);
                } else {
                    statusText = "Clear";
                }
            }
        }

        var mgText = Util.formatMg(level) + " mg";

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, dc.getHeight() * 0.3, Graphics.FONT_GLANCE,
            mgText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, dc.getHeight() * 0.7, Graphics.FONT_GLANCE_NUMBER,
            statusText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
