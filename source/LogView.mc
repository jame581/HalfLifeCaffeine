using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Time;

class LogView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var app = Application.getApp() as HalfLifeCaffeineApp;
        var now = Time.now().value();
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Title
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.08, Graphics.FONT_XTINY,
            "Today's Drinks", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (app.caffeineModel == null) { return; }

        var log = app.caffeineModel.getTodayLog(now);

        if (log.size() == 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL,
                "No drinks today", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var lineHeight = (height * 0.12).toNumber();
        var startY = (height * 0.18).toNumber();
        var maxVisible = ((height * 0.75) / lineHeight).toNumber();

        var presets = app.drinkPresets;

        for (var i = log.size() - 1; i >= 0; i--) {
            var entryIndex = log.size() - 1 - i;
            if (entryIndex >= maxVisible) { break; }

            var dose = log[i];
            var timeStr = Util.formatTime(dose[:time]);
            var mgStr = Util.formatMg(dose[:mg]) + "mg";
            var name = findPresetName(presets, dose[:mg].toNumber());

            var y = startY + (entryIndex * lineHeight);

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width * 0.15, y, Graphics.FONT_XTINY,
                timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width * 0.50, y, Graphics.FONT_XTINY,
                name, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width * 0.85, y, Graphics.FONT_XTINY,
                mgStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function findPresetName(presets as DrinkPresets, mg as Number) as String {
        for (var i = 0; i < presets.getPresetCount(); i++) {
            var preset = presets.getPresetAt(i);
            if (preset[:mg] == mg) {
                return preset[:name];
            }
        }
        return mg + "mg";
    }
}
