import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application;
import Toybox.Time;
import Toybox.Lang;

class SummaryView extends WatchUi.View {

    private var _sUnit;
    private var _sClear;
    private var _tplSleepSafe;
    private var _tplIntake;
    private var _sHint;
    private var _unitHour;
    private var _unitMinute;

    function initialize() {
        View.initialize();
        _sUnit = WatchUi.loadResource(Rez.Strings.SummaryUnit);
        _sClear = WatchUi.loadResource(Rez.Strings.Clear);
        _tplSleepSafe = WatchUi.loadResource(Rez.Strings.SummarySleepSafeIn);
        _tplIntake = WatchUi.loadResource(Rez.Strings.SummaryIntake);
        _sHint = WatchUi.loadResource(Rez.Strings.SummaryHint);
        _unitHour = WatchUi.loadResource(Rez.Strings.UnitHour);
        _unitMinute = WatchUi.loadResource(Rez.Strings.UnitMinute);
    }

    function onUpdate(dc) {
        var app = Application.getApp();
        var now = Time.now().value();
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Colors.BG, Colors.BG);
        dc.clear();

        var level = 0.0;
        var dailyIntake = 0;
        var minutesToSafe = 0;
        var alertStatus = "ok";
        var dailyLimit = 400;

        if (app.caffeineModel != null) {
            level = app.caffeineModel.getCurrentLevel(now);
            dailyIntake = app.caffeineModel.getDailyIntake(now);
            minutesToSafe = app.caffeineModel.getMinutesToSafe(now, 50);
        }

        var limitProp = Application.Properties.getValue("dailyLimit");
        if (limitProp != null) { dailyLimit = limitProp; }

        if (app.alertManager != null) {
            alertStatus = app.alertManager.getStatus(dailyIntake, dailyLimit);
        }

        var centerX = width / 2;

        // Current caffeine level (large, centered)
        dc.setColor(Colors.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 18 / 100), Graphics.FONT_NUMBER_HOT,
            Util.formatMg(level), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Colors.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 33 / 100), Graphics.FONT_TINY,
            _sUnit, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Progress bar
        var barY = height * 42 / 100;
        var barWidth = width * 60 / 100;
        var barHeight = 8;
        var barX = centerX - barWidth / 2;
        dc.setColor(Colors.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barWidth, barHeight);
        var fillRatio = dailyIntake.toFloat() / dailyLimit.toFloat();
        if (fillRatio > 1.0) { fillRatio = 1.0; }
        var fillWidth = (barWidth * fillRatio).toNumber();
        var barColor = Colors.ACCENT;
        if (alertStatus.equals("warning")) { barColor = Colors.WARNING; }
        if (alertStatus.equals("over")) { barColor = Colors.DANGER; }
        dc.setColor(barColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, fillWidth, barHeight);

        // Time until sleep-safe
        var sleepText = _sClear;
        if (level >= 1.0 && minutesToSafe > 0) {
            sleepText = Lang.format(_tplSleepSafe,
                [Util.formatDuration(minutesToSafe, _unitHour, _unitMinute)]);
        }
        dc.setColor(Colors.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 55 / 100), Graphics.FONT_SMALL,
            sleepText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Daily intake vs limit
        var intakeText = Lang.format(_tplIntake, [dailyIntake.toString(), dailyLimit.toString()]);
        var intakeColor = Colors.TEXT_SECONDARY;
        if (alertStatus.equals("warning")) { intakeColor = Colors.WARNING; }
        if (alertStatus.equals("over")) { intakeColor = Colors.DANGER; }
        dc.setColor(intakeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 70 / 100), Graphics.FONT_TINY,
            intakeText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Hint
        dc.setColor(Colors.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 88 / 100), Graphics.FONT_XTINY,
            _sHint, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
