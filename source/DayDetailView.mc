import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Time;

class DayDetailView extends WatchUi.View {

    // First drink shown; DayDetailDelegate scrolls it a page at a time.
    var firstRow;
    // Drinks on this day, as of the last onUpdate.
    var doseCount;

    // Layout, in percent of the screen; drawing and arrowAt share it.
    private const LIST_TOP_PCT = 32;
    private const LIST_BOTTOM_PCT = 88;
    private const ROW_HEIGHT_PCT = 9;

    private var _ymd;
    private var _sNoDrinks;
    private var _sExpired;
    private var _tplDateLong;
    // Doses of this day that were moved to the archive; read once.
    private var _archived;
    private var _monthNames;

    function initialize(ymd) {
        View.initialize();
        firstRow = 0;
        doseCount = 0;
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
        doseCount = dayDoses.size();
        var visible = visibleRows(height);
        if (firstRow > doseCount - visible) { firstRow = doseCount - visible; }
        if (firstRow < 0) { firstRow = 0; }

        // There is no room above the first drink, so while the list is
        // scrolled the scroll-up arrow takes the date's place.
        if (firstRow > 0) {
            ListArrows.draw(dc, width / 2, height * 12 / 100, height, true);
        } else {
            var headerStr = Util.formatYmd(_ymd, _tplDateLong, _monthNames);
            dc.setColor(Colors.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height * 12 / 100, Graphics.FONT_XTINY,
                headerStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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

        var dailyLimit = Util.getDailyLimit();
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

        var listTop = height * LIST_TOP_PCT / 100;
        var lineHeight = height * ROW_HEIGHT_PCT / 100;

        for (var i = 0; firstRow + i < dayDoses.size() && i < visible; i++) {
            var dose = dayDoses[firstRow + i];
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
        if (firstRow + visible < doseCount) {
            ListArrows.draw(dc, width / 2, listTop + visible * lineHeight, height, false);
        }
    }

    // -1 / 1 when a tap at y hits the scroll-up arrow (above the drinks, in the
    // date's place) or the scroll-down arrow (below them), each only while
    // drinks are hidden that way; 0 otherwise.
    function arrowAt(y, height) {
        var lineHeight = height * ROW_HEIGHT_PCT / 100;
        var top = height * LIST_TOP_PCT / 100 - lineHeight / 2; // rows are centred on their y
        var visible = visibleRows(height);
        if (y < top) { return (firstRow > 0) ? -1 : 0; }
        if (y >= top + visible * lineHeight) { return (firstRow + visible < doseCount) ? 1 : 0; }
        return 0;
    }

    // Scroll a page of drinks (direction -1 up, 1 down).
    function scrollPage(direction, height) {
        var visible = visibleRows(height);
        var start = firstRow + direction * visible;
        if (start > doseCount - visible) { start = doseCount - visible; }
        if (start < 0) { start = 0; }
        firstRow = start;
        WatchUi.requestUpdate();
    }

    private function visibleRows(height) {
        var lineHeight = height * ROW_HEIGHT_PCT / 100;
        var n = (lineHeight > 0) ? (height * (LIST_BOTTOM_PCT - LIST_TOP_PCT) / 100) / lineHeight : 1;
        return (n < 1) ? 1 : n;
    }
}
