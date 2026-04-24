import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Time;

class HistoryView extends WatchUi.View {

    // Selected index into the day list (0 = most recent). Updated by HistoryDelegate.
    var selectedIndex;

    // Cached combined list of day rows, [ymd, totalMg], newest-first.
    // Built in onUpdate from dailyTotals + today's live dose sum.
    var dayRows;

    function initialize() {
        View.initialize();
        selectedIndex = 0;
        dayRows = [];
    }

    function onUpdate(dc) {
        var app = Application.getApp();
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Colors.BG, Colors.BG);
        dc.clear();

        if (app.caffeineModel == null || app.storageManager == null) {
            dc.setColor(Colors.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL,
                "History", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var now = Time.now().value();
        dayRows = buildDayRows(app, now);

        var dailyLimit = Application.Properties.getValue("dailyLimit");

        drawTitle(dc, width, height);
        drawBarChart(dc, width, height, dayRows, dailyLimit);
        drawDayList(dc, width, height, dayRows, dailyLimit);
    }

    // Build newest-first list of [ymd, totalMg] rows.
    // Today's entry is computed from live doses; earlier days come from dailyTotals.
    private function buildDayRows(app, now) {
        var rows = [];
        var todayYmd = Util.ymdFromEpoch(now);
        var todayMg = app.caffeineModel.getDailyIntake(now);
        rows.add([todayYmd, todayMg]);

        var totals = app.storageManager.loadDailyTotals();
        // totals are oldest-first; iterate in reverse to prepend newest-first to rows.
        for (var i = totals.size() - 1; i >= 0; i--) {
            rows.add([totals[i][0], totals[i][1]]);
        }
        return rows;
    }

    private function drawTitle(dc, width, height) {
        dc.setColor(Colors.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 8 / 100, Graphics.FONT_XTINY,
            "History", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Top ~37% of screen height: 14-bar chart with daily-limit reference line.
    // Screen layout: title 0-15%, chart 15-50%, day list 50-95%.
    private function drawBarChart(dc, width, height, rows, dailyLimit) {
        var chartTop = height * 15 / 100;
        var chartBottom = height * 48 / 100;
        var chartHeight = chartBottom - chartTop;
        var chartLeftInset = width * 12 / 100;
        var chartRightInset = width * 12 / 100;
        var chartWidth = width - chartLeftInset - chartRightInset;

        if (rows.size() == 0) { return; }

        // Take up to 14 rows, newest on the RIGHT.
        var maxBars = 14;
        var barCount = rows.size() < maxBars ? rows.size() : maxBars;
        var bars = [];
        for (var i = barCount - 1; i >= 0; i--) {
            bars.add(rows[i]);
        }

        // Compute scale: max of (dailyLimit * 1.1, max bar * 1.1).
        var maxVal = dailyLimit * 110 / 100;
        for (var i = 0; i < bars.size(); i++) {
            var v = bars[i][1] * 110 / 100;
            if (v > maxVal) { maxVal = v; }
        }
        if (maxVal <= 0) { maxVal = 1; }

        var barSlotWidth = chartWidth / barCount;
        var barInnerWidth = barSlotWidth * 70 / 100;
        var barGap = (barSlotWidth - barInnerWidth) / 2;

        // Draw bars
        for (var i = 0; i < bars.size(); i++) {
            var total = bars[i][1];
            var barPixelHeight = (total * chartHeight) / maxVal;
            if (barPixelHeight < 1 && total > 0) { barPixelHeight = 1; }
            var bx = chartLeftInset + (i * barSlotWidth) + barGap;
            var by = chartBottom - barPixelHeight;

            var color = Colors.ACCENT;
            if (total > dailyLimit) { color = Colors.DANGER; }
            else if (total > dailyLimit * 80 / 100) { color = Colors.WARNING; }

            dc.setColor(color, Colors.BG);
            dc.fillRectangle(bx, by, barInnerWidth, barPixelHeight);
        }

        // Daily-limit reference line (dashed-ish — we draw short segments).
        var limitY = chartBottom - ((dailyLimit * chartHeight) / maxVal);
        if (limitY > chartTop && limitY < chartBottom) {
            dc.setColor(Colors.DANGER, Colors.BG);
            var dashLen = 4;
            var gapLen = 4;
            var x = chartLeftInset;
            while (x < chartLeftInset + chartWidth) {
                var endX = x + dashLen;
                if (endX > chartLeftInset + chartWidth) { endX = chartLeftInset + chartWidth; }
                dc.drawLine(x, limitY, endX, limitY);
                x = endX + gapLen;
            }
        }
    }

    // Bottom ~45% of screen height: scrollable list of days.
    // Implemented in Task C6; this stub keeps onUpdate callable now.
    private function drawDayList(dc, width, height, rows, dailyLimit) {
        // Placeholder — fleshed out in Task C6.
    }
}
