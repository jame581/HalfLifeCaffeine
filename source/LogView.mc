import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Time;

class LogView extends WatchUi.View {

    // Index into the rendered (newest-first) list. Default 0 = most recent dose.
    var selectedIndex;

    // Cached array of _doses indices in rendered (newest-first) order.
    // Rebuilt every onUpdate from caffeineModel.getTodayLogIndices.
    var dayIndices;

    // Cached array of dose dicts in rendered (newest-first) order, parallel to dayIndices.
    var dayDoses;

    // Layout, in percent of the screen; drawing and indexAt share it.
    private const LIST_TOP_PCT = 28;
    private const LIST_BOTTOM_PCT = 82;
    private const ROW_HEIGHT_PCT = 10;

    private var _sTitle;
    private var _sEmpty;

    function initialize() {
        View.initialize();
        selectedIndex = 0;
        dayIndices = [];
        dayDoses = [];
        _sTitle = WatchUi.loadResource(Rez.Strings.TitleLog);
        _sEmpty = WatchUi.loadResource(Rez.Strings.NoDrinksToday);
    }

    function onUpdate(dc) {
        var app = Application.getApp();
        var now = Time.now().value();
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Colors.BG, Colors.BG);
        dc.clear();

        dc.setColor(Colors.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 18 / 100, Graphics.FONT_XTINY,
            _sTitle, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (app.caffeineModel == null) { return; }

        // Build newest-first caches from chronological-ascending model indices.
        var ascIndices = app.caffeineModel.getTodayLogIndices(now);
        var doses = app.caffeineModel.getDoses();
        dayIndices = [];
        dayDoses = [];
        for (var i = ascIndices.size() - 1; i >= 0; i--) {
            dayIndices.add(ascIndices[i]);
            dayDoses.add(doses[ascIndices[i]]);
        }

        if (dayDoses.size() == 0) {
            selectedIndex = 0;
            dc.setColor(Colors.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL,
                _sEmpty, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Re-clamp selectedIndex if mutations shrank the list.
        if (selectedIndex >= dayDoses.size()) {
            selectedIndex = dayDoses.size() - 1;
        }
        if (selectedIndex < 0) { selectedIndex = 0; }

        var listTop = height * LIST_TOP_PCT / 100;
        var lineHeight = height * ROW_HEIGHT_PCT / 100;
        var maxVisible = visibleRows(height);
        var first = scrollStart(height);

        var rowInsetLeft = width * 10 / 100;
        var rowInsetRight = width * 10 / 100;
        var rowWidth = width - rowInsetLeft - rowInsetRight;

        for (var i = 0; first + i < dayDoses.size() && i < maxVisible; i++) {
            var dose = dayDoses[first + i];
            var y = listTop + (i * lineHeight);
            var isSelected = (first + i == selectedIndex);

            if (isSelected) {
                dc.setColor(Colors.TRACK, Colors.BG);
                dc.fillRectangle(rowInsetLeft, y - lineHeight / 2, rowWidth, lineHeight);
            }

            var timeStr = Util.formatTime(dose[:time]);
            var mgStr = Util.formatMg(dose[:mg]) + "mg";
            var name = dose.hasKey(:name) && !dose[:name].equals("") ? dose[:name] : Util.formatMg(dose[:mg]) + "mg";
            var line = timeStr + "  " + name + "  " + mgStr;

            dc.setColor(Colors.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y, Graphics.FONT_XTINY,
                line, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // There is no room above the first row, so while the list is scrolled
        // the scroll-up arrow takes the title's place.
        if (first > 0) {
            dc.setColor(Colors.BG, Colors.BG);
            dc.fillRectangle(0, 0, width, listTop - lineHeight / 2);
            ListArrows.draw(dc, width / 2, height * 18 / 100, height, true);
        }
        if (first + maxVisible < dayDoses.size()) {
            ListArrows.draw(dc, width / 2, listTop + maxVisible * lineHeight, height, false);
        }
    }

    // Row index (into dayDoses) under a tap at y on a screen height pixels
    // tall; -1 when the tap is above, below or past the end of the list.
    function indexAt(y, height) {
        var lineHeight = height * ROW_HEIGHT_PCT / 100;
        var top = height * LIST_TOP_PCT / 100 - lineHeight / 2; // rows are centred on their y
        if (y < top || lineHeight <= 0) { return -1; }
        var slot = (y - top) / lineHeight;
        var idx = scrollStart(height) + slot;
        return (slot < visibleRows(height) && idx < dayDoses.size()) ? idx : -1;
    }

    // -1 / 1 when a tap at y hits the scroll-up arrow (above the rows, in the
    // title's place) or the scroll-down arrow (below the rows), each only while
    // rows are hidden that way; 0 otherwise.
    function arrowAt(y, height) {
        var lineHeight = height * ROW_HEIGHT_PCT / 100;
        var top = height * LIST_TOP_PCT / 100 - lineHeight / 2;
        var visible = visibleRows(height);
        var first = scrollStart(height);
        if (y < top) { return (first > 0) ? -1 : 0; }
        if (y >= top + visible * lineHeight) { return (first + visible < dayDoses.size()) ? 1 : 0; }
        return 0;
    }

    // Scroll a page (direction -1 up, 1 down) and leave the cursor on the
    // last row shown, so the list window follows it.
    function scrollPage(direction, height) {
        var visible = visibleRows(height);
        var count = dayDoses.size();
        var start = scrollStart(height) + direction * visible;
        if (start > count - visible) { start = count - visible; }
        if (start < 0) { start = 0; }
        var sel = start + visible - 1;
        if (sel > count - 1) { sel = count - 1; }
        if (sel < 0) { sel = 0; }
        selectedIndex = sel;
        WatchUi.requestUpdate();
    }

    // First row shown, so that selectedIndex is visible.
    function scrollStart(height) {
        var visible = visibleRows(height);
        return (selectedIndex >= visible) ? selectedIndex - visible + 1 : 0;
    }

    private function visibleRows(height) {
        var lineHeight = height * ROW_HEIGHT_PCT / 100;
        var n = (lineHeight > 0) ? (height * (LIST_BOTTOM_PCT - LIST_TOP_PCT) / 100) / lineHeight : 1;
        return (n < 1) ? 1 : n;
    }

    // Move the cursor by delta rows (clamped). Called by LogDelegate on UP/DOWN.
    function moveSelection(delta) {
        var newIndex = selectedIndex + delta;
        if (newIndex < 0) { newIndex = 0; }
        if (newIndex >= dayDoses.size()) { newIndex = dayDoses.size() - 1; }
        if (newIndex != selectedIndex) {
            selectedIndex = newIndex;
            WatchUi.requestUpdate();
        }
    }

    // Return the master _doses index for the currently-selected row, or -1 if empty.
    function getSelectedDoseIndex() {
        if (dayDoses.size() == 0) { return -1; }
        if (selectedIndex < 0 || selectedIndex >= dayIndices.size()) { return -1; }
        return dayIndices[selectedIndex];
    }
}
