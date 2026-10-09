import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Time;
import Toybox.Lang;

(:glance)
class GlanceView extends WatchUi.GlanceView {

    // Loaded once; every string here is scope="glance" in the resources.
    private var _sClear;
    private var _tplSafeIn;
    private var _unitHour;
    private var _unitMinute;

    function initialize() {
        GlanceView.initialize();
        _sClear = WatchUi.loadResource(Rez.Strings.Clear);
        _tplSafeIn = WatchUi.loadResource(Rez.Strings.GlanceSafeIn);
        _unitHour = WatchUi.loadResource(Rez.Strings.UnitHour);
        _unitMinute = WatchUi.loadResource(Rez.Strings.UnitMinute);
    }

    function onUpdate(dc) {
        Colors.applyTheme();
        var now = Time.now().value();

        // Glance process doesn't share state with the full-view app,
        // so instantiate model+storage locally and read doses fresh.
        var storage = new StorageManager();
        var model = new CaffeineModel();
        model.setDoses(storage.loadDoses());
        model.setHalfLifeSeconds(Util.getHalfLifeSeconds());

        var level = model.getCurrentLevel(now);
        var numText = Util.formatMg(level);

        var statusText = _sClear;
        if (level >= 1.0) {
            var minutesToSafe = model.getMinutesToSafe(now, 50);
            if (minutesToSafe > 0) {
                statusText = Lang.format(_tplSafeIn,
                    [Util.formatDuration(minutesToSafe, _unitHour, _unitMinute)]);
            }
        }

        var h = dc.getHeight();
        var numY = h * 32 / 100;

        // Big caffeine number — FONT_GLANCE_NUMBER is digit-only on some
        // smaller fenix devices (fenix 7S in particular renders 'm' and 'g'
        // glyphs as missing-glyph boxes), so the "mg" suffix is drawn
        // separately in FONT_GLANCE.
        dc.setColor(Colors.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, numY, Graphics.FONT_GLANCE_NUMBER,
            numText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var numWidth = dc.getTextWidthInPixels(numText, Graphics.FONT_GLANCE_NUMBER);
        dc.drawText(numWidth + 4, numY, Graphics.FONT_GLANCE,
            "mg", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Status line
        dc.setColor(Colors.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 72 / 100, Graphics.FONT_GLANCE,
            statusText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
