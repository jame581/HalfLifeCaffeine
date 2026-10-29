import Toybox.Application;
import Toybox.WatchUi;

// Believable data for store screenshots. Only store.jungle compiles this folder
// (tools/sim-matrix.ps1 -Demo); release and test builds never contain it.
module DemoData {

    // Each drink: [preset index in Names(), mg, minutes after local midnight].
    // Days run from 13 days ago to yesterday: mostly green, one day over 80 %
    // of the 400 mg default (amber) and one over the limit (red).
    const DAYS = [
        [[2, 95, 450], [4, 63, 780]],
        [[3, 190, 465], [5, 30, 900]],
        [[0, 63, 480], [1, 77, 630], [6, 47, 930]],
        [[2, 95, 450], [7, 80, 840]],
        [[3, 190, 450], [4, 63, 750], [9, 34, 1080]],
        [[0, 63, 540], [5, 30, 960]],
        [[2, 95, 450], [4, 63, 810]],
        [[3, 190, 450], [8, 160, 840], [0, 63, 990]],
        [[2, 95, 450], [6, 47, 870]],
        [[1, 77, 480], [4, 63, 720], [5, 30, 930]],
        [[3, 190, 460], [7, 80, 810], [9, 34, 1020]],
        [[2, 95, 450], [4, 63, 765]],
        [[3, 190, 450], [0, 63, 660], [6, 47, 900], [10, 25, 1200]]
    ];
    // Today, as minutes before now: filter coffee, a latte, a green tea.
    const TODAY = [[2, 95, 330], [4, 63, 170], [5, 30, 50]];

    function names() {
        return [
            WatchUi.loadResource(Rez.Strings.PresetEspresso),
            WatchUi.loadResource(Rez.Strings.PresetAmericano),
            WatchUi.loadResource(Rez.Strings.PresetDripS),
            WatchUi.loadResource(Rez.Strings.PresetDripL),
            WatchUi.loadResource(Rez.Strings.PresetLatte),
            WatchUi.loadResource(Rez.Strings.PresetGreenTea),
            WatchUi.loadResource(Rez.Strings.PresetBlackTea),
            WatchUi.loadResource(Rez.Strings.PresetRedBull),
            WatchUi.loadResource(Rez.Strings.PresetMonster),
            WatchUi.loadResource(Rez.Strings.PresetCola),
            WatchUi.loadResource(Rez.Strings.PresetDarkChocolate)
        ];
    }

    // Fill the dose store once, before the app's roll-up and archive run, so
    // History gets its rows and Day Detail its drinks the normal way. Names are
    // the current language's, so clear the app data before each language.
    function seed(storageManager, now) {
        if (Application.Storage.getValue("demoSeeded") != null) { return; }
        Application.Storage.setValue("demoSeeded", true);

        var n = names();
        var today = Util.midnightEpochFor(now);
        var doses = [];
        for (var d = 0; d < DAYS.size(); d++) {
            // Noon of the day, so a clock change cannot move it to the next one.
            var noon = today - (DAYS.size() - d) * 86400 + 43200;
            var drinks = DAYS[d];
            for (var i = 0; i < drinks.size(); i++) {
                doses.add({:mg => drinks[i][1], :name => n[drinks[i][0]],
                    :time => Util.localTimeOnDay(noon, drinks[i][2] * 60)});
            }
        }
        for (var i = 0; i < TODAY.size(); i++) {
            var t = now - TODAY[i][2] * 60;
            // Captures in the small hours would put these on yesterday.
            if (t >= today) {
                doses.add({:mg => TODAY[i][1], :name => n[TODAY[i][0]], :time => t});
            }
        }
        storageManager.saveDoses(doses);
        // Roll up from the day before the first demo day; a fresh install would roll nothing.
        storageManager.saveLastRolledYmd(Util.ymdFromEpoch(today - (DAYS.size() + 1) * 86400 + 43200));
        // StorageManager's one-time pre-1.4.0 fix-up would move that marker back a day.
        Application.Storage.setValue("localDayFix", true);
    }
}
