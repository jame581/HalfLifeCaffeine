using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Time;

class TimelineView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        var app = Application.getApp();
        var now = Time.now().value();
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Title
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.08, Graphics.FONT_XTINY,
            "Caffeine Timeline", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (app.caffeineModel == null) { return; }

        // Graph area
        var graphLeft = (width * 0.15).toNumber();
        var graphRight = (width * 0.85).toNumber();
        var graphTop = (height * 0.18).toNumber();
        var graphBottom = (height * 0.82).toNumber();
        var graphWidth = graphRight - graphLeft;
        var graphHeight = graphBottom - graphTop;

        // Get projection data (8 hours, every 30 min = 17 points)
        var projection = app.caffeineModel.getProjection(now, 8);

        // Find max value for Y-axis scaling
        var maxMg = 50.0;
        for (var i = 0; i < projection.size(); i++) {
            var mg = projection[i][:mg];
            if (mg > maxMg) { maxMg = mg; }
        }
        maxMg = maxMg * 1.1;

        // Draw axes
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(graphLeft, graphTop, graphLeft, graphBottom);
        dc.drawLine(graphLeft, graphBottom, graphRight, graphBottom);

        // Draw 50mg threshold line (dashed)
        var safeY = graphBottom - ((50.0 / maxMg) * graphHeight).toNumber();
        if (safeY >= graphTop && safeY <= graphBottom) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            for (var x = graphLeft; x < graphRight; x += 6) {
                dc.drawLine(x, safeY, x + 3, safeY);
            }
            dc.drawText(graphRight + 2, safeY, Graphics.FONT_XTINY,
                "50", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Draw bedtime marker
        var bedtimeEpoch = Util.getBedtimeEpoch(now);
        var minutesUntilBed = (bedtimeEpoch - now) / 60;
        if (minutesUntilBed > 0 && minutesUntilBed < 480) {
            var bedX = graphLeft + ((minutesUntilBed.toFloat() / 480.0) * graphWidth).toNumber();
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(bedX, graphTop, bedX, graphBottom);
            dc.drawText(bedX, graphTop - 2, Graphics.FONT_XTINY,
                "BED", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Draw the decay curve
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
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

        // Time labels along bottom
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        for (var h = 0; h <= 8; h += 2) {
            var lx = graphLeft + ((h.toFloat() / 8.0) * graphWidth).toNumber();
            dc.drawText(lx, graphBottom + 4, Graphics.FONT_XTINY,
                "+" + h + "h", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Current level label
        if (projection.size() > 0) {
            var currentMg = projection[0][:mg];
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(graphLeft + 4, graphTop + 4, Graphics.FONT_XTINY,
                Util.formatMg(currentMg) + "mg", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

}
