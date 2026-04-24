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

    // Bottom region of screen: scrollable list of days, selected row highlighted.
    private function drawDayList(dc, width, height, rows, dailyLimit) {
        var listTop = height * 54 / 100;
        var listBottom = height * 94 / 100;
        var listHeight = listBottom - listTop;
        var rowHeight = height * 10 / 100;
        var visibleCount = listHeight / rowHeight;
        if (visibleCount < 1) { visibleCount = 1; }

        if (rows.size() == 0) {
            dc.setColor(Colors.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, (listTop + listBottom) / 2, Graphics.FONT_XTINY,
                "No history yet", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Compute scroll window so selectedIndex is visible.
        var scrollStart = 0;
        if (selectedIndex >= visibleCount) {
            scrollStart = selectedIndex - visibleCount + 1;
        }

        var listLeftInset = width * 10 / 100;
        var listRightInset = width * 10 / 100;
        var listWidth = width - listLeftInset - listRightInset;

        for (var i = 0; i < visibleCount && (scrollStart + i) < rows.size(); i++) {
            var rowIdx = scrollStart + i;
            var row = rows[rowIdx];
            var rowY = listTop + (i * rowHeight);
            var isSelected = (rowIdx == selectedIndex);

            if (isSelected) {
                dc.setColor(Colors.TRACK, Colors.BG);
                dc.fillRectangle(listLeftInset, rowY, listWidth, rowHeight - 2);
            }

            var dateStr = formatYmdShort(row[0]);
            var mgStr = Util.formatMg(row[1]) + " mg";

            // Color the mg text by proportion of daily limit.
            var mgColor = Colors.ACCENT;
            if (row[1] > dailyLimit) { mgColor = Colors.DANGER; }
            else if (row[1] > dailyLimit * 80 / 100) { mgColor = Colors.WARNING; }

            dc.setColor(Colors.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(listLeftInset + 6, rowY + rowHeight / 2,
                Graphics.FONT_XTINY, dateStr,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            dc.setColor(mgColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(listLeftInset + listWidth - 6, rowY + rowHeight / 2,
                Graphics.FONT_XTINY, mgStr,
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Format a ymd int to "MMM d" string (e.g. 20260424 → "Apr 24").
    private function formatYmdShort(ymd) {
        var year = (ymd / 10000).toNumber();
        var month = ((ymd / 100) % 100).toNumber();
        var day = (ymd % 100).toNumber();
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        var monthStr = (month >= 1 && month <= 12) ? months[month - 1] : "?";
        return monthStr + " " + day.toString();
    }

    // Called by HistoryDelegate on UP/DOWN input.
    function moveSelection(delta) {
        var newIndex = selectedIndex + delta;
        if (newIndex < 0) { newIndex = 0; }
        if (newIndex >= dayRows.size()) { newIndex = dayRows.size() - 1; }
        if (newIndex != selectedIndex) {
            selectedIndex = newIndex;
            WatchUi.requestUpdate();
        }
    }

    // Called by HistoryDelegate on SELECT to get the currently-highlighted day.
    // Returns the ymd int, or -1 if no rows.
    function getSelectedYmd() {
        if (dayRows.size() == 0) { return -1; }
        if (selectedIndex >= dayRows.size()) { return -1; }
        return dayRows[selectedIndex][0];
    }
}
