import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Time;
import Toybox.Time.Gregorian;

class DayDetailView extends WatchUi.View {

    private var _ymd;

    function initialize(ymd) {
        View.initialize();
        _ymd = ymd;
    }

    function onUpdate(dc) {
        var app = Application.getApp();
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Colors.BG, Colors.BG);
        dc.clear();

        if (app.caffeineModel == null || app.storageManager == null) { return; }

        var headerStr = formatYmdLong(_ymd);
        dc.setColor(Colors.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 12 / 100, Graphics.FONT_XTINY,
            headerStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Resolve doses for this day from the live 14-day store.
        var allDoses = app.caffeineModel.getDoses();
        var dayDoses = app.storageManager.getDosesForDay(allDoses, _ymd);

        // Resolve daily total from daily-totals store (covers days older than 14 days).
        var totalMg = 0;
        var totals = app.storageManager.loadDailyTotals();
        for (var i = 0; i < totals.size(); i++) {
            if (totals[i][0] == _ymd) {
                totalMg = totals[i][1];
                break;
            }
        }
        // For today, compute live total (it's not rolled up yet).
        var nowYmd = Util.ymdFromEpoch(Time.now().value());
        if (_ymd == nowYmd) {
            totalMg = app.caffeineModel.getDailyIntake(Time.now().value());
        }

        var dailyLimit = Application.Properties.getValue("dailyLimit");
        var mgColor = Colors.ACCENT;
        if (totalMg > dailyLimit) { mgColor = Colors.DANGER; }
        else if (totalMg > dailyLimit * 80 / 100) { mgColor = Colors.WARNING; }

        dc.setColor(mgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 22 / 100, Graphics.FONT_SMALL,
            Util.formatMg(totalMg) + " mg",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (dayDoses.size() == 0) {
            dc.setColor(Colors.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            var msg = (_ymd == nowYmd)
                ? "No drinks today"
                : "Details expired after 14 days";
            dc.drawText(width / 2, height * 55 / 100, Graphics.FONT_XTINY,
                msg, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var listTop = height * 32 / 100;
        var listBottom = height * 88 / 100;
        var listHeight = listBottom - listTop;
        var lineHeight = height * 9 / 100;
        var maxVisible = listHeight / lineHeight;

        for (var i = 0; i < dayDoses.size() && i < maxVisible; i++) {
            var dose = dayDoses[i];
            var timeStr = Util.formatTime(dose[:time]);
            var name = dose.hasKey(:name) && !dose[:name].equals("")
                ? dose[:name] : (Util.formatMg(dose[:mg]) + "mg");
            var mgStr = Util.formatMg(dose[:mg]) + "mg";
            var y = listTop + (i * lineHeight);
            var line = timeStr + "  " + name + "  " + mgStr;

            dc.setColor(Colors.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y, Graphics.FONT_XTINY,
                line, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Format a ymd int to "Apr 24, 2026" style string.
    private function formatYmdLong(ymd) {
        var year = (ymd / 10000).toNumber();
        var month = ((ymd / 100) % 100).toNumber();
        var day = (ymd % 100).toNumber();
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        var monthStr = (month >= 1 && month <= 12) ? months[month - 1] : "?";
        return monthStr + " " + day.toString() + ", " + year.toString();
    }
}
