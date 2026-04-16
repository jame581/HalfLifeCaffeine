using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Time;

class SummaryView extends WatchUi.View {

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

        var appObj = Application.getApp();
        var limitProp = appObj.getProperty("dailyLimit");
        if (limitProp != null) { dailyLimit = limitProp; }

        if (app.alertManager != null) {
            alertStatus = app.alertManager.getStatus(dailyIntake, dailyLimit);
        }

        var centerX = width / 2;

        // Current caffeine level (large, centered)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 18 / 100), Graphics.FONT_NUMBER_HOT,
            Util.formatMg(level), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 33 / 100), Graphics.FONT_TINY,
            "mg caffeine", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Progress bar
        var barY = height * 42 / 100;
        var barWidth = width * 60 / 100;
        var barHeight = 8;
        var barX = centerX - barWidth / 2;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barWidth, barHeight);
        var fillRatio = dailyIntake.toFloat() / dailyLimit.toFloat();
        if (fillRatio > 1.0) { fillRatio = 1.0; }
        var fillWidth = (barWidth * fillRatio).toNumber();
        var barColor = Graphics.COLOR_GREEN;
        if (alertStatus.equals("warning")) { barColor = Graphics.COLOR_YELLOW; }
        if (alertStatus.equals("over")) { barColor = Graphics.COLOR_RED; }
        dc.setColor(barColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, fillWidth, barHeight);

        // Time until sleep-safe
        var sleepText = "Clear";
        if (level >= 1.0 && minutesToSafe > 0) {
            sleepText = "Sleep safe in " + Util.formatDuration(minutesToSafe);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 55 / 100), Graphics.FONT_SMALL,
            sleepText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Daily intake vs limit
        var intakeText = dailyIntake.toString() + " / " + dailyLimit.toString() + " mg today";
        var intakeColor = Graphics.COLOR_LT_GRAY;
        if (alertStatus.equals("warning")) { intakeColor = Graphics.COLOR_YELLOW; }
        if (alertStatus.equals("over")) { intakeColor = Graphics.COLOR_RED; }
        dc.setColor(intakeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 70 / 100), Graphics.FONT_TINY,
            intakeText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Hint
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * 88 / 100), Graphics.FONT_XTINY,
            "Press to add drink", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
