import Toybox.WatchUi;
import Toybox.Application;

class EditTimeMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _doseIndex;

    function initialize(doseIndex) {
        Menu2InputDelegate.initialize();
        _doseIndex = doseIndex;
    }

    function onSelect(item) {
        var offsetSeconds = item.getId();
        Application.getApp().adjustDoseTime(_doseIndex, offsetSeconds);
        // Pop the offsets menu, then pop the Edit Drink menu — return to LogView.
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
