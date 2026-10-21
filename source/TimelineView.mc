import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Time;

class TimelineView extends WatchUi.View {

    // Graph windows: hours past, hours future, sample step in minutes.
    // The step grows with the window so a redraw costs about the same.
    // static var, not const: a class const is not reachable from a static
    // function or as TimelineView.RANGES (Symbol Not Found at runtime).
    static var RANGES = [[2, 4, 10], [4, 8, 15], [6, 12, 20]];
    static var DEFAULT_RANGE = 1;
    static var RANGE_KEY = "timelineRange";

    // Index into RANGES from a stored value; anything unexpected means the default.
    static function rangeIndex(stored) {
        if (stored instanceof Lang.Number && stored >= 0 && stored < RANGES.size()) {
            return stored;
        }
        return DEFAULT_RANGE;
    }

    static function nextRange(index) {
        return (index + 1) % RANGES.size();
    }

    // Levels from -pastHours to +futureHours every stepMin minutes, as a flat
    // list of Floats: sample i is at minute -pastHours*60 + i*stepMin. A list of
    // {:minutes, :mg} dictionaries cost ~6.7 KB on fenix 6, which a debug build
    // could not afford.
    static function buildCurve(model, now, pastHours, futureHours, stepMin) {
        var curve = [];
        for (var m = -pastHours * 60; m <= futureHours * 60; m += stepMin) {
            curve.add(model.getCurrentLevel(now + m * 60).toFloat());
        }
        return curve;
    }


    // Graph geometry, set in onUpdate
    private var _graphLeft;
    private var _graphRight;
    private var _graphTop;
    private var _graphBottom;
    private var _graphWidth;
    private var _graphHeight;
    private var _maxMg;
    private var _levelY;

    private var _sTitle;
    private var _sNow;
    private var _tplNowLevel;
    private var _unitHour;

    private var _rangeIndex;
    private var _pastHours;
    private var _futureHours;
    private var _stepMin;

    function initialize() {
        View.initialize();
        _sTitle = WatchUi.loadResource(Rez.Strings.TitleTimeline);
        _sNow = WatchUi.loadResource(Rez.Strings.TimelineNow);
        _tplNowLevel = WatchUi.loadResource(Rez.Strings.TimelineNowLevel);
        _unitHour = WatchUi.loadResource(Rez.Strings.UnitHour);
        applyRange(rangeIndex(Application.Storage.getValue(RANGE_KEY)));
    }

    private function applyRange(index) {
        _rangeIndex = index;
        _pastHours = RANGES[index][0];
        _futureHours = RANGES[index][1];
        _stepMin = RANGES[index][2];
    }

    // SELECT on the timeline: next window, remembered for next time.
    function cycleRange() {
        applyRange(nextRange(_rangeIndex));
        Application.Storage.setValue(RANGE_KEY, _rangeIndex);
        WatchUi.requestUpdate();
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
            _sTitle, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (app.caffeineModel == null) { return; }

        _graphLeft = width * 18 / 100;
        _graphRight = width * 82 / 100;
        _graphTop = height * 28 / 100;
        _graphBottom = height * 74 / 100;

        // Below the graph sit the axis labels and then the current-level line.
        // Where the font is tall for the screen (small MIP watches) the two
        // collide, so lift the graph just enough to stack them.
        var fontH = dc.getFontHeight(Graphics.FONT_XTINY);
        _levelY = height * 83 / 100;
        if (_levelY + fontH > height * 95 / 100) { _levelY = height * 95 / 100 - fontH; }
        var maxBottom = _levelY - fontH * 9 / 10 - 8;
        if (_graphBottom > maxBottom) { _graphBottom = maxBottom; }

        _graphWidth = _graphRight - _graphLeft;
        _graphHeight = _graphBottom - _graphTop;

        var curve = buildCurve(app.caffeineModel, now, _pastHours, _futureHours, _stepMin);
        var totalMinutes = (_pastHours + _futureHours) * 60;

        // Y-axis scale (headroom above max)
        _maxMg = 50.0;
        for (var i = 0; i < curve.size(); i++) {
            if (curve[i] > _maxMg) { _maxMg = curve[i]; }
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
        if (minutesUntilBed <= 0 || minutesUntilBed > _futureHours * 60) { return; }
        var bedX = minutesToX(minutesUntilBed, (_pastHours + _futureHours) * 60);
        dc.setColor(Colors.BEDTIME, Graphics.COLOR_TRANSPARENT);
        for (var y = _graphTop; y < _graphBottom; y += 5) {
            dc.drawLine(bedX, y, bedX, y + 3);
        }
    }

    private function drawNowMarker(dc) {
        var nowX = minutesToX(0, (_pastHours + _futureHours) * 60);
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
            poly.add([minutesToX(sampleMinute(i), totalMinutes), mgToY(curve[i])]);
        }
        // Close the polygon along the baseline
        poly.add([minutesToX(sampleMinute(curve.size() - 1), totalMinutes), _graphBottom]);
        poly.add([minutesToX(sampleMinute(0), totalMinutes), _graphBottom]);
        dc.setColor(0x1B4D3E, Colors.BG); // dim accent shadow under curve
        dc.fillPolygon(poly);
    }

    private function drawCurve(dc, curve, totalMinutes) {
        dc.setColor(Colors.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setAntiAlias(true);
        for (var i = 1; i < curve.size(); i++) {
            dc.drawLine(
                minutesToX(sampleMinute(i - 1), totalMinutes), mgToY(curve[i - 1]),
                minutesToX(sampleMinute(i), totalMinutes), mgToY(curve[i])
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
            if (doseMinutesFromNow < -_pastHours * 60 || doseMinutesFromNow > 0) { continue; }
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
            [-_pastHours * 60, "-" + _pastHours + _unitHour],
            [0, _sNow],
            [_futureHours * 60 / 2, "+" + (_futureHours / 2) + _unitHour],
            [_futureHours * 60, "+" + _futureHours + _unitHour]
        ];
        for (var i = 0; i < labels.size(); i++) {
            var lx = minutesToX(labels[i][0], totalMinutes);
            dc.drawText(lx, labelY, Graphics.FONT_XTINY,
                labels[i][1], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawCurrentLevel(dc, width, height, curve) {
        // The "now" sample: every step divides the past window evenly.
        var currentMg = curve[_pastHours * 60 / _stepMin];
        dc.setColor(Colors.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, _levelY, Graphics.FONT_XTINY,
            Lang.format(_tplNowLevel, [Util.formatMg(currentMg)]), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Minute offset from now of curve sample i.
    private function sampleMinute(i) {
        return -_pastHours * 60 + i * _stepMin;
    }

    // minutes: offset from now, -_pastHours*60 .. +_futureHours*60
    // totalMinutes: the whole window, (_pastHours + _futureHours) * 60
    private function minutesToX(minutes, totalMinutes) {
        return _graphLeft + (((minutes + _pastHours * 60).toFloat() / totalMinutes) * _graphWidth).toNumber();
    }

    private function mgToY(mg) {
        return _graphBottom - ((mg.toFloat() / _maxMg) * _graphHeight).toNumber();
    }
}
