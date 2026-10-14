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

    // Layout, in percent of the screen; drawing and indexAt share it.
    private const CHART_TOP_PCT = 15;
    private const CHART_BOTTOM_PCT = 48;
    private const CHART_INSET_PCT = 12;
    private const MAX_BARS = 14;
    private const LIST_TOP_PCT = 54;
    private const LIST_BOTTOM_PCT = 84; // three rows, then the scroll-down arrow
    private const ROW_HEIGHT_PCT = 10;

    private var _sTitle;
    private var _sEmpty;
    private var _tplDateShort;
    private var _monthNames;

    function initialize() {
        View.initialize();
        selectedIndex = 0;
        dayRows = [];
        _sTitle = WatchUi.loadResource(Rez.Strings.TitleHistory);
        _sEmpty = WatchUi.loadResource(Rez.Strings.NoHistoryYet);
        _tplDateShort = WatchUi.loadResource(Rez.Strings.DateShort);
        _monthNames = MonthNames.load();
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
                _sTitle, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
            _sTitle, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Top ~37% of screen height: 14-bar chart with daily-limit reference line.
    // Screen layout: title 0-15%, chart 15-50%, day list 50-95%.
    private function drawBarChart(dc, width, height, rows, dailyLimit) {
        var chartTop = height * CHART_TOP_PCT / 100;
        var chartBottom = height * CHART_BOTTOM_PCT / 100;
        var chartHeight = chartBottom - chartTop;
        var chartLeftInset = width * CHART_INSET_PCT / 100;
        var chartWidth = width - 2 * chartLeftInset;

        if (rows.size() == 0) { return; }

        // Always reserve 14 slots so bar width stays consistent regardless of
        // history length. Slots are filled right-to-left (newest on the right);
        // unfilled slots render as empty space.
        var maxBars = MAX_BARS;
        var filledCount = rows.size() < maxBars ? rows.size() : maxBars;

        // Compute scale from the filled rows only.
        var maxVal = dailyLimit * 110 / 100;
        for (var i = 0; i < filledCount; i++) {
            var v = rows[i][1] * 110 / 100;
            if (v > maxVal) { maxVal = v; }
        }
        if (maxVal <= 0) { maxVal = 1; }

        var barSlotWidth = chartWidth / maxBars;
        var barInnerWidth = barSlotWidth * 70 / 100;
        var barGap = (barSlotWidth - barInnerWidth) / 2;

        // Draw filled bars anchored to the right.
        // Slot index runs 0..maxBars-1 left to right. Newest day fills the rightmost slot.
        for (var i = 0; i < filledCount; i++) {
            var row = rows[i]; // rows[0] = today (newest)
            var total = row[1];
            var barPixelHeight = (total * chartHeight) / maxVal;
            if (barPixelHeight < 1 && total > 0) { barPixelHeight = 1; }
            var slotIdx = maxBars - 1 - i; // newest goes rightmost
            var bx = chartLeftInset + (slotIdx * barSlotWidth) + barGap;
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
        var listTop = height * LIST_TOP_PCT / 100;
        var listBottom = height * LIST_BOTTOM_PCT / 100;
        var rowHeight = height * ROW_HEIGHT_PCT / 100;
        var visibleCount = visibleRows(height);

        if (rows.size() == 0) {
            dc.setColor(Colors.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, (listTop + listBottom) / 2, Graphics.FONT_XTINY,
                _sEmpty, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var scrollStart = scrollStartFor(visibleCount);

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

            var dateStr = Util.formatYmd(row[0], _tplDateShort, _monthNames);
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

        if (scrollStart > 0) {
            ListArrows.draw(dc, width / 2, (height * CHART_BOTTOM_PCT / 100 + listTop) / 2, height, true);
        }
        if (scrollStart + visibleCount < rows.size()) {
            ListArrows.draw(dc, width / 2, listTop + visibleCount * rowHeight + rowHeight * 4 / 10, height, false);
        }
    }

    // Row index (into dayRows) under a tap at x, y on a width x height screen,
    // from a list row or a chart bar; -1 when the tap hits neither.
    function indexAt(x, y, width, height) {
        var count = dayRows.size();
        if (count == 0) { return -1; }

        var listTop = height * LIST_TOP_PCT / 100;
        var rowHeight = height * ROW_HEIGHT_PCT / 100;
        var visibleCount = visibleRows(height);
        if (y >= listTop && rowHeight > 0) {
            var slot = (y - listTop) / rowHeight;
            var idx = scrollStartFor(visibleCount) + slot;
            return (slot < visibleCount && idx < count) ? idx : -1;
        }

        var chartLeft = width * CHART_INSET_PCT / 100;
        var slotWidth = (width - 2 * chartLeft) / MAX_BARS;
        if (y < height * CHART_TOP_PCT / 100 || y > height * CHART_BOTTOM_PCT / 100
                || x < chartLeft || slotWidth <= 0) {
            return -1;
        }
        var barSlot = (x - chartLeft) / slotWidth;
        var dayIdx = MAX_BARS - 1 - barSlot; // newest on the right
        return (barSlot < MAX_BARS && dayIdx < count) ? dayIdx : -1;
    }

    // -1 / 1 when a tap at x, y hits the scroll-up arrow (between the chart and
    // the list) or the scroll-down arrow (below the list), each only while rows
    // are hidden that way; 0 otherwise.
    function arrowAt(x, y, width, height) {
        var listTop = height * LIST_TOP_PCT / 100;
        var visible = visibleRows(height);
        var first = scrollStartFor(visible);
        if (y > height * CHART_BOTTOM_PCT / 100 && y < listTop) {
            return (first > 0) ? -1 : 0;
        }
        if (y >= listTop + visible * (height * ROW_HEIGHT_PCT / 100)) {
            return (first + visible < dayRows.size()) ? 1 : 0;
        }
        return 0;
    }

    // Scroll a page (direction -1 up, 1 down) and leave the cursor on the
    // last row shown, so the list window follows it.
    function scrollPage(direction, height) {
        var visible = visibleRows(height);
        var count = dayRows.size();
        var start = scrollStartFor(visible) + direction * visible;
        if (start > count - visible) { start = count - visible; }
        if (start < 0) { start = 0; }
        var sel = start + visible - 1;
        if (sel > count - 1) { sel = count - 1; }
        if (sel < 0) { sel = 0; }
        selectedIndex = sel;
        WatchUi.requestUpdate();
    }

    private function visibleRows(height) {
        var rowHeight = height * ROW_HEIGHT_PCT / 100;
        var n = (rowHeight > 0) ? (height * (LIST_BOTTOM_PCT - LIST_TOP_PCT) / 100) / rowHeight : 1;
        return (n < 1) ? 1 : n;
    }

    // First row shown, so that selectedIndex is visible.
    private function scrollStartFor(visibleCount) {
        return (selectedIndex >= visibleCount) ? selectedIndex - visibleCount + 1 : 0;
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
