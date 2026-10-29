import Toybox.Graphics;
import Toybox.Math;
import Toybox.System;

// Fits a centred "time  name  mg" row of the log and day detail lists to the
// screen. On round watches a row near the top or bottom has less room, and a
// long drink name (Czech "Překapávaná malá") ran off both edges.
module RowFit {

    // Width a centred row can use at y on a width × height screen, 4 % margin
    // each side. halfLine is half the text height: on a round screen the text
    // edge farther from the centre is where the chord is shortest.
    function availableWidth(width, height, y, halfLine, isRound) {
        var margin = width * 4 / 100;
        if (!isRound) { return width - 2 * margin; }
        var r = width / 2;
        var dy = (y - height / 2).abs() + halfLine;
        if (dy >= r) { return 0; }
        var w = (2 * Math.sqrt(r * r - dy * dy)).toNumber() - 2 * margin;
        return (w > 0) ? w : 0;
    }

    // The row text for y: the double spaces go first, then the name is cut
    // with an ellipsis. Time and mg always show whole.
    function line(dc, font, timeStr, name, mgStr, y) {
        var isRound = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        var maxWidth = availableWidth(dc.getWidth(), dc.getHeight(), y,
            dc.getFontHeight(font) / 2, isRound);
        var text = timeStr + "  " + name + "  " + mgStr;
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) { return text; }
        text = timeStr + " " + name + " " + mgStr;
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) { return text; }
        for (var n = name.length() - 1; n > 0; n--) {
            text = timeStr + " " + name.substring(0, n) + "… " + mgStr;
            if (dc.getTextWidthInPixels(text, font) <= maxWidth) { return text; }
        }
        return timeStr + " " + mgStr;
    }
}
