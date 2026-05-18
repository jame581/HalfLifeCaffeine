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

    function initialize() {
        View.initialize();
        selectedIndex = 0;
        dayIndices = [];
        dayDoses = [];
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
            "Today's Drinks", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

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
                "No drinks today", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Re-clamp selectedIndex if mutations shrank the list.
        if (selectedIndex >= dayDoses.size()) {
            selectedIndex = dayDoses.size() - 1;
        }
        if (selectedIndex < 0) { selectedIndex = 0; }

        var listTop = height * 28 / 100;
        var listBottom = height * 82 / 100;
        var listHeight = listBottom - listTop;
        var lineHeight = height * 10 / 100;
        var maxVisible = listHeight / lineHeight;

        var rowInsetLeft = width * 10 / 100;
        var rowInsetRight = width * 10 / 100;
        var rowWidth = width - rowInsetLeft - rowInsetRight;

        for (var i = 0; i < dayDoses.size() && i < maxVisible; i++) {
            var dose = dayDoses[i];
            var y = listTop + (i * lineHeight);
            var isSelected = (i == selectedIndex);

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
