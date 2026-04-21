import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Time;

class TimelineView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        var app = Application.getApp();
        var now = Time.now().value();
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Colors.BG, Colors.BG);
        dc.clear();

        // Title — pushed down from top to avoid round-screen clip
        dc.setColor(Colors.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 18 / 100, Graphics.FONT_XTINY,
            "Caffeine Timeline", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (app.caffeineModel == null) { return; }

        // Graph area — inset heavily for round screen
        var graphLeft = width * 22 / 100;
        var graphRight = width * 78 / 100;
        var graphTop = height * 30 / 100;
        var graphBottom = height * 72 / 100;
        var graphWidth = graphRight - graphLeft;
        var graphHeight = graphBottom - graphTop;

        var projection = app.caffeineModel.getProjection(now, 8);

        var maxMg = 50.0;
        for (var i = 0; i < projection.size(); i++) {
            var mg = projection[i][:mg];
            if (mg > maxMg) { maxMg = mg; }
        }
        maxMg = maxMg * 1.1;

        // Axes
        dc.setColor(Colors.AXIS, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(graphLeft, graphTop, graphLeft, graphBottom);
        dc.drawLine(graphLeft, graphBottom, graphRight, graphBottom);

        // 50mg threshold line (dashed)
        var safeY = graphBottom - ((50.0 / maxMg) * graphHeight).toNumber();
        if (safeY >= graphTop && safeY <= graphBottom) {
            dc.setColor(Colors.WARNING, Graphics.COLOR_TRANSPARENT);
            for (var x = graphLeft; x < graphRight; x += 6) {
                dc.drawLine(x, safeY, x + 3, safeY);
            }
        }

        // Bedtime marker
        var bedtimeEpoch = Util.getBedtimeEpoch(now);
        var minutesUntilBed = (bedtimeEpoch - now) / 60;
        if (minutesUntilBed > 0 && minutesUntilBed < 480) {
            var bedX = graphLeft + ((minutesUntilBed.toFloat() / 480.0) * graphWidth).toNumber();
            dc.setColor(Colors.BEDTIME, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(bedX, graphTop, bedX, graphBottom);
        }

        // Decay curve
        dc.setColor(Colors.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setAntiAlias(true);
        for (var i = 1; i < projection.size(); i++) {
            var prev = projection[i - 1];
            var curr = projection[i];

            var x1 = graphLeft + ((prev[:minutesFromNow].toFloat() / 480.0) * graphWidth).toNumber();
            var y1 = graphBottom - ((prev[:mg].toFloat() / maxMg) * graphHeight).toNumber();
            var x2 = graphLeft + ((curr[:minutesFromNow].toFloat() / 480.0) * graphWidth).toNumber();
            var y2 = graphBottom - ((curr[:mg].toFloat() / maxMg) * graphHeight).toNumber();

            dc.drawLine(x1, y1, x2, y2);
        }
        dc.setAntiAlias(false);

        // Time labels along bottom (fewer, centered)
        dc.setColor(Colors.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        var labelY = graphBottom + 10;
        for (var h = 0; h <= 8; h += 4) {
            var lx = graphLeft + ((h.toFloat() / 8.0) * graphWidth).toNumber();
            dc.drawText(lx, labelY, Graphics.FONT_XTINY,
                "+" + h + "h", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Current level label (center bottom)
        if (projection.size() > 0) {
            var currentMg = projection[0][:mg];
            dc.setColor(Colors.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height * 83 / 100, Graphics.FONT_XTINY,
                "Now: " + Util.formatMg(currentMg) + " mg", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

}
