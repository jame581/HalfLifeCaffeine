import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Time;

class LogView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        var app = Application.getApp();
        var now = Time.now().value();
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Title — pushed down for round screen safe area
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 18 / 100, Graphics.FONT_XTINY,
            "Today's Drinks", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (app.caffeineModel == null) { return; }

        var log = app.caffeineModel.getTodayLog(now);

        if (log.size() == 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL,
                "No drinks today", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Entries drawn in round-screen safe area
        var listTop = height * 28 / 100;
        var listBottom = height * 82 / 100;
        var listHeight = listBottom - listTop;
        var lineHeight = height * 10 / 100;
        var maxVisible = listHeight / lineHeight;

        for (var i = log.size() - 1; i >= 0; i--) {
            var entryIndex = log.size() - 1 - i;
            if (entryIndex >= maxVisible) { break; }

            var dose = log[i];
            var timeStr = Util.formatTime(dose[:time]);
            var mgStr = Util.formatMg(dose[:mg]) + "mg";
            var name = dose.hasKey(:name) && !dose[:name].equals("") ? dose[:name] : Util.formatMg(dose[:mg]) + "mg";

            var y = listTop + (entryIndex * lineHeight);

            // Single-line format centered: "HH:MM Name Xmg"
            var line = timeStr + "  " + name + "  " + mgStr;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y, Graphics.FONT_XTINY,
                line, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

}
