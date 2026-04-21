import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Time;

class TimelineView extends WatchUi.View {

    private const PAST_HOURS = 4;
    private const FUTURE_HOURS = 8;
    private const SAMPLE_INTERVAL_MIN = 15;

    // Graph geometry, set in onUpdate
    private var _graphLeft;
    private var _graphRight;
    private var _graphTop;
    private var _graphBottom;
    private var _graphWidth;
    private var _graphHeight;
    private var _maxMg;

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

        // Title
        dc.setColor(Colors.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 16 / 100, Graphics.FONT_XTINY,
            "Caffeine Timeline", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (app.caffeineModel == null) { return; }

        _graphLeft = width * 18 / 100;
        _graphRight = width * 82 / 100;
        _graphTop = height * 28 / 100;
        _graphBottom = height * 74 / 100;
        _graphWidth = _graphRight - _graphLeft;
        _graphHeight = _graphBottom - _graphTop;

        // Build curve: past PAST_HOURS + future FUTURE_HOURS, sampled every SAMPLE_INTERVAL_MIN
        var curve = [];
        var totalMinutes = (PAST_HOURS + FUTURE_HOURS) * 60;
        for (var m = -PAST_HOURS * 60; m <= FUTURE_HOURS * 60; m += SAMPLE_INTERVAL_MIN) {
            var epoch = now + (m * 60);
            var mg = app.caffeineModel.getCurrentLevel(epoch);
            curve.add({:minutes => m, :mg => mg});
        }

        // Y-axis scale (headroom above max)
        _maxMg = 50.0;
        for (var i = 0; i < curve.size(); i++) {
            var mg = curve[i][:mg];
            if (mg > _maxMg) { _maxMg = mg; }
        }
        _maxMg = _maxMg * 1.15;

        drawAxes(dc);
        drawAreaFill(dc, curve, totalMinutes);
        drawThresholdLine(dc);
        drawBedtimeMarker(dc, now);
        drawCurve(dc, curve, totalMinutes);
        drawNowMarker(dc);
        drawDoseMarkers(dc, app.caffeineModel, now, totalMinutes);
        drawTimeLabels(dc, totalMinutes);
        drawCurrentLevel(dc, width, height, curve);
    }

    private function drawAxes(dc) {
        dc.setColor(Colors.AXIS, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_graphLeft, _graphTop, _graphLeft, _graphBottom);
        dc.drawLine(_graphLeft, _graphBottom, _graphRight, _graphBottom);
    }

    private function drawThresholdLine(dc) {
        var safeY = _graphBottom - ((50.0 / _maxMg) * _graphHeight).toNumber();
        if (safeY < _graphTop || safeY > _graphBottom) { return; }
        dc.setColor(Colors.WARNING, Graphics.COLOR_TRANSPARENT);
        for (var x = _graphLeft; x < _graphRight; x += 6) {
            dc.drawLine(x, safeY, x + 3, safeY);
        }
    }

    private function drawBedtimeMarker(dc, now) {
        var bedtimeEpoch = Util.getBedtimeEpoch(now);
        var minutesUntilBed = (bedtimeEpoch - now) / 60;
        if (minutesUntilBed <= 0 || minutesUntilBed > FUTURE_HOURS * 60) { return; }
        var bedX = minutesToX(minutesUntilBed, (PAST_HOURS + FUTURE_HOURS) * 60);
        dc.setColor(Colors.BEDTIME, Graphics.COLOR_TRANSPARENT);
        for (var y = _graphTop; y < _graphBottom; y += 5) {
            dc.drawLine(bedX, y, bedX, y + 3);
        }
    }

    private function drawNowMarker(dc) {
        var nowX = minutesToX(0, (PAST_HOURS + FUTURE_HOURS) * 60);
        dc.setColor(Colors.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        // Vertical line — 2px wide for prominence
        dc.drawLine(nowX, _graphTop, nowX, _graphBottom);
        dc.drawLine(nowX + 1, _graphTop, nowX + 1, _graphBottom);
        // Downward-pointing triangle at the top of the line
        var triangle = [
            [nowX - 4, _graphTop - 6],
            [nowX + 5, _graphTop - 6],
            [nowX, _graphTop - 1]
        ];
        dc.fillPolygon(triangle);
    }

    private function drawAreaFill(dc, curve, totalMinutes) {
        // Fill area under curve with darker shade of accent for depth
        var poly = [];
        for (var i = 0; i < curve.size(); i++) {
            var p = curve[i];
            poly.add([minutesToX(p[:minutes], totalMinutes), mgToY(p[:mg])]);
        }
        // Close the polygon along the baseline
        poly.add([minutesToX(curve[curve.size() - 1][:minutes], totalMinutes), _graphBottom]);
        poly.add([minutesToX(curve[0][:minutes], totalMinutes), _graphBottom]);
        dc.setColor(0x1B4D3E, Colors.BG); // dim accent shadow under curve
        dc.fillPolygon(poly);
    }

    private function drawCurve(dc, curve, totalMinutes) {
        dc.setColor(Colors.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setAntiAlias(true);
        for (var i = 1; i < curve.size(); i++) {
            var prev = curve[i - 1];
            var curr = curve[i];
            dc.drawLine(
                minutesToX(prev[:minutes], totalMinutes), mgToY(prev[:mg]),
                minutesToX(curr[:minutes], totalMinutes), mgToY(curr[:mg])
            );
        }
        dc.setAntiAlias(false);
    }

    private function drawDoseMarkers(dc, model, now, totalMinutes) {
        var log = model.getTodayLog(now);
        dc.setColor(Colors.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < log.size(); i++) {
            var dose = log[i];
            var doseMinutesFromNow = (dose[:time] - now) / 60;
            if (doseMinutesFromNow < -PAST_HOURS * 60 || doseMinutesFromNow > 0) { continue; }
            var doseMg = model.getCurrentLevel(dose[:time]);
            var dx = minutesToX(doseMinutesFromNow, totalMinutes);
            var dy = mgToY(doseMg);
            dc.fillCircle(dx, dy, 3);
        }
    }

    private function drawTimeLabels(dc, totalMinutes) {
        dc.setColor(Colors.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        var labelY = _graphBottom + 8;
        var labels = [
            [-PAST_HOURS * 60, "-" + PAST_HOURS + "h"],
            [0, "now"],
            [FUTURE_HOURS * 60 / 2, "+" + (FUTURE_HOURS / 2) + "h"],
            [FUTURE_HOURS * 60, "+" + FUTURE_HOURS + "h"]
        ];
        for (var i = 0; i < labels.size(); i++) {
            var lx = minutesToX(labels[i][0], totalMinutes);
            dc.drawText(lx, labelY, Graphics.FONT_XTINY,
                labels[i][1], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawCurrentLevel(dc, width, height, curve) {
        // Find the sample closest to minutes=0 (current)
        var currentMg = 0.0;
        for (var i = 0; i < curve.size(); i++) {
            if (curve[i][:minutes] == 0) {
                currentMg = curve[i][:mg];
                break;
            }
        }
        dc.setColor(Colors.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 83 / 100, Graphics.FONT_XTINY,
            "Now: " + Util.formatMg(currentMg) + " mg", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // minutes: -240 to +480 (past and future offset from now)
    // totalMinutes: full window (720 for 4h past + 8h future)
    private function minutesToX(minutes, totalMinutes) {
        return _graphLeft + (((minutes + PAST_HOURS * 60).toFloat() / totalMinutes) * _graphWidth).toNumber();
    }

    private function mgToY(mg) {
        return _graphBottom - ((mg.toFloat() / _maxMg) * _graphHeight).toNumber();
    }
}
