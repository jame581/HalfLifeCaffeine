import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Time;

class DayDetailView extends WatchUi.View {

    private var _ymd;
    private var _sNoDrinks;
    private var _sExpired;
    private var _tplDateLong;
    // Doses of this day that were moved to the archive; read once.
    private var _archived;
    private var _monthNames;

    function initialize(ymd) {
        View.initialize();
        _ymd = ymd;
        _sNoDrinks = WatchUi.loadResource(Rez.Strings.NoDrinksToday);
        _sExpired = WatchUi.loadResource(Rez.Strings.DetailsExpired);
        _tplDateLong = WatchUi.loadResource(Rez.Strings.DateLong);
        _monthNames = MonthNames.load();
        var app = Application.getApp();
        _archived = (app.storageManager != null)
            ? app.storageManager.loadArchivedDosesForDay(ymd) : [];
    }

    function onUpdate(dc) {
        var app = Application.getApp();
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Colors.BG, Colors.BG);
        dc.clear();

        if (app.caffeineModel == null || app.storageManager == null) { return; }

        var headerStr = Util.formatYmd(_ymd, _tplDateLong, _monthNames);
        dc.setColor(Colors.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 12 / 100, Graphics.FONT_XTINY,
            headerStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Doses for this day: the archived ones (older), then those still in
        // the model. A day can straddle the boundary between the two.
        var dayDoses = [];
        for (var i = 0; i < _archived.size(); i++) { dayDoses.add(_archived[i]); }
        var live = app.storageManager.getDosesForDay(app.caffeineModel.getDoses(), _ymd);
        for (var i = 0; i < live.size(); i++) { dayDoses.add(live[i]); }
        // By time: an edited dose keeps its stored position. Insertion sort, a
        // day has few doses.
        for (var i = 1; i < dayDoses.size(); i++) {
            var d = dayDoses[i];
            var j = i - 1;
            while (j >= 0 && dayDoses[j][:time] > d[:time]) {
                dayDoses[j + 1] = dayDoses[j];
                j--;
            }
            dayDoses[j + 1] = d;
        }

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
            var msg = (_ymd == nowYmd) ? _sNoDrinks : _sExpired;
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
}
