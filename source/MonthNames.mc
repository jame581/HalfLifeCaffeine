import Toybox.WatchUi;

// Month names for Util.formatYmd, from the translation sheets. Load once in a
// view's initialize(); the glance shows no dates, so this is not (:glance).
module MonthNames {

    function load() {
        var ids = [
            Rez.Strings.Month1, Rez.Strings.Month2, Rez.Strings.Month3,
            Rez.Strings.Month4, Rez.Strings.Month5, Rez.Strings.Month6,
            Rez.Strings.Month7, Rez.Strings.Month8, Rez.Strings.Month9,
            Rez.Strings.Month10, Rez.Strings.Month11, Rez.Strings.Month12
        ];
        var names = new [12];
        for (var i = 0; i < 12; i++) {
            names[i] = WatchUi.loadResource(ids[i]);
        }
        return names;
    }
}
