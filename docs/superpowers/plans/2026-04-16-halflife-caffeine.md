# HalfLife Caffeine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a free Garmin Connect IQ widget that tracks caffeine intake, models decay via half-life, alerts on daily limits, and syncs history to a web-based phone companion with charts and trends.

**Architecture:** Connect IQ Widget (Monkey C) with glance view, 3 scrollable detail screens, and a drink-logging menu. Phone companion is an HTML/JS web settings page inside the Garmin Connect app. Data syncs via the Connect IQ Communications API. Caffeine decay uses a fixed 5.7-hour half-life pharmacokinetic model.

**Tech Stack:** Monkey C (Connect IQ SDK 3.2+), HTML/CSS/JavaScript (web settings), VS Code + Connect IQ plugin, Connect IQ Simulator

**Design Spec:** `docs/superpowers/specs/2026-04-16-halflife-caffeine-design.md`

---

## File Structure

```
HalfLifeCaffeine/
├── monkey.jungle                          # Build configuration
├── manifest.xml                           # App manifest (auto-generated)
├── source/
│   ├── HalfLifeCaffeineApp.mc             # AppBase — lifecycle, glance/view routing, settings change handler
│   ├── CaffeineModel.mc                   # Core caffeine math — decay, totals, time-to-safe, daily intake
│   ├── DrinkPresets.mc                    # Default drink list + loading custom presets from settings
│   ├── StorageManager.mc                  # Application.Storage wrapper — save/load doses, history, cleanup
│   ├── SyncManager.mc                     # Communications API — send drink logs to phone, receive settings
│   ├── AlertManager.mc                    # Daily limit alerts + sleep notification logic
│   ├── GlanceView.mc                      # Widget glance — caffeine level + sleep status one-liner
│   ├── SummaryView.mc                     # Screen 1 — current level, progress bar, daily intake, warnings
│   ├── SummaryDelegate.mc                 # Screen 1 input — swipe down to timeline, menu to add drink
│   ├── TimelineView.mc                    # Screen 2 — caffeine decay graph over next 8 hours
│   ├── TimelineDelegate.mc                # Screen 2 input — swipe navigation
│   ├── LogView.mc                         # Screen 3 — today's drink log list
│   ├── LogDelegate.mc                     # Screen 3 input — swipe navigation
│   ├── DrinkMenuDelegate.mc               # Drink picker menu — select preset to log
│   └── Util.mc                            # Time formatting helpers (e.g. minutes to "3h 20m")
├── resources/
│   ├── strings.xml                        # English strings
│   ├── properties.xml                     # App properties (daily limit, bedtime, notification toggles)
│   ├── settings.xml                       # Settings UI for Garmin Connect app
│   ├── drawables/
│   │   └── drawables.xml                  # Icon references
│   ├── images/
│   │   ├── launcher-icon.png              # 256x256 store icon
│   │   └── coffee-icon.png                # Small icon for glance
│   ├── layouts/
│   │   └── summary-layout.xml            # Summary screen layout
│   └── menus/
│       └── drink-menu.xml                 # Drink preset menu definition
├── resources-round/
│   └── layouts/
│       └── summary-layout.xml            # Round screen variant
├── resources-rectangle/
│   └── layouts/
│       └── summary-layout.xml            # Rectangle screen variant
├── companion/
│   └── settings/
│       └── index.html                     # Web settings page (history, trends, preset management)
└── test/
    └── CaffeineModelTest.mc               # Unit tests for caffeine math
```

---

## Task 1: SDK Setup & Project Scaffold

**Goal:** Install the Connect IQ SDK, create the project skeleton, and verify it compiles and runs in the simulator.

**Files:**
- Create: `monkey.jungle`
- Create: `manifest.xml`
- Create: `source/HalfLifeCaffeineApp.mc`
- Create: `source/GlanceView.mc`
- Create: `resources/strings.xml`
- Create: `resources/properties.xml`
- Create: `resources/drawables/drawables.xml`

### Prerequisites

- [ ] **Step 1: Install Connect IQ SDK**

Download and install from https://developer.garmin.com/connect-iq/sdk/. Install the VS Code Connect IQ extension ("Monkey C" by Garmin). Use the SDK Manager to download device files for at least: Vivoactive 5, Venu 3, Forerunner 265, Fenix 7.

- [ ] **Step 2: Generate a developer key**

```bash
openssl genrsa -out private_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in private_key.pem -out private_key.der -nocrypt
```

Keep `private_key.der` in the project root. Add `private_key.pem` and `private_key.der` to `.gitignore`.

### Scaffold

- [ ] **Step 3: Create monkey.jungle**

```
# monkey.jungle
project.manifest = manifest.xml

base.sourcePath = source
base.resourcePath = resources
base.excludeAnnotations = test
```

- [ ] **Step 4: Create manifest.xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<iq:manifest version="3" xmlns:iq="http://www.garmin.com/xml/connectiq">
  <iq:application entry="HalfLifeCaffeineApp"
                  id="com.halflife.caffeine"
                  launcherIcon="@Drawables.LauncherIcon"
                  minSdkVersion="3.2.0"
                  name="@Strings.AppName"
                  type="widget">
    <iq:products>
      <iq:product id="vivoactive5"/>
      <iq:product id="venu2"/>
      <iq:product id="venu2plus"/>
      <iq:product id="venu3"/>
      <iq:product id="venu3s"/>
      <iq:product id="fr255"/>
      <iq:product id="fr265"/>
      <iq:product id="fr955"/>
      <iq:product id="fr965"/>
      <iq:product id="fenix7"/>
      <iq:product id="fenix7s"/>
      <iq:product id="fenix7x"/>
      <iq:product id="epix2"/>
    </iq:products>
    <iq:permissions>
      <iq:uses-permission id="Communications"/>
      <iq:uses-permission id="Background"/>
    </iq:permissions>
    <iq:languages>
      <iq:language>eng</iq:language>
    </iq:languages>
  </iq:application>
</iq:manifest>
```

- [ ] **Step 5: Create resources/strings.xml**

```xml
<strings>
  <string id="AppName">HalfLife Caffeine</string>
  <string id="Clear">Clear</string>
  <string id="SafeToSleepIn">Safe to sleep in</string>
  <string id="AddDrink">Add Drink</string>
  <string id="NoDrinksToday">No drinks today</string>
  <string id="OverLimit">Over limit!</string>
  <string id="Bedtime">Bedtime</string>
  <string id="SafeThreshold">Safe</string>
</strings>
```

- [ ] **Step 6: Create resources/properties.xml**

```xml
<properties>
  <property id="dailyLimit" type="number">400</property>
  <property id="bedtimeHour" type="number">22</property>
  <property id="bedtimeMinute" type="number">30</property>
  <property id="useGarminSleep" type="boolean">true</property>
  <property id="alertLimitWarning" type="boolean">true</property>
  <property id="alertLimitReached" type="boolean">true</property>
  <property id="alertSafeToSleep" type="boolean">true</property>
</properties>
```

- [ ] **Step 7: Create resources/drawables/drawables.xml**

```xml
<drawables>
  <bitmap id="LauncherIcon" filename="../images/launcher-icon.png"/>
</drawables>
```

Create a placeholder 256x256 PNG at `resources/images/launcher-icon.png` (solid color square is fine for now).

- [ ] **Step 8: Create source/HalfLifeCaffeineApp.mc (minimal)**

```monkey
using Toybox.Application;
using Toybox.WatchUi;

class HalfLifeCaffeineApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getGlanceView() as Array? {
        return [new GlanceView()];
    }

    function getView() as Array {
        return [new SummaryView(), new SummaryDelegate()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
```

- [ ] **Step 9: Create source/GlanceView.mc (placeholder)**

```monkey
using Toybox.WatchUi;
using Toybox.Graphics;

class GlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, dc.getHeight() / 2, Graphics.FONT_GLANCE,
            "HalfLife: 0 mg", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
```

- [ ] **Step 10: Create stub SummaryView and SummaryDelegate**

**source/SummaryView.mc:**
```monkey
using Toybox.WatchUi;
using Toybox.Graphics;

class SummaryView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM,
            "0 mg", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
```

**source/SummaryDelegate.mc:**
```monkey
using Toybox.WatchUi;

class SummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        return true;
    }
}
```

- [ ] **Step 11: Build and run in simulator**

```bash
# From VS Code: Ctrl+Shift+P → "Monkey C: Build for Device"
# Select "vivoactive5" as target device
# Or via command line:
monkeyc -d vivoactive5 -f monkey.jungle -o bin/HalfLifeCaffeine.prg -y private_key.der
```

Launch the Connect IQ Simulator, load the .prg file. Verify:
- Widget appears in the widget loop
- Glance shows "HalfLife: 0 mg"
- Tapping into widget shows "0 mg" centered on screen

- [ ] **Step 12: Commit**

```bash
git add monkey.jungle manifest.xml source/ resources/ .gitignore
git commit -m "feat: scaffold HalfLife Caffeine widget project"
```

---

## Task 2: Caffeine Model (Core Logic)

**Goal:** Implement the pharmacokinetic caffeine decay math — the heart of the app. This is pure logic with no UI dependencies, so it's the most testable component.

**Files:**
- Create: `source/CaffeineModel.mc`
- Create: `test/CaffeineModelTest.mc`

- [ ] **Step 1: Write tests for the caffeine model**

**test/CaffeineModelTest.mc:**
```monkey
using Toybox.Test;
using Toybox.Time;
using Toybox.Math;

(:test)
function testSingleDoseDecayAtZeroTime(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    model.addDose(100, now);
    var level = model.getCurrentLevel(now);
    // At t=0, should be full dose
    return (level >= 99 && level <= 101);
}

(:test)
function testSingleDoseDecayAtOneHalfLife(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    // Add dose 5.7 hours (20520 seconds) ago
    model.addDose(100, now - 20520);
    var level = model.getCurrentLevel(now);
    // After one half-life, should be ~50mg
    return (level >= 48 && level <= 52);
}

(:test)
function testSingleDoseDecayAtTwoHalfLives(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    // Add dose 11.4 hours (41040 seconds) ago
    model.addDose(100, now - 41040);
    var level = model.getCurrentLevel(now);
    // After two half-lives, should be ~25mg
    return (level >= 23 && level <= 27);
}

(:test)
function testMultipleDosesStack(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    model.addDose(100, now);
    model.addDose(63, now);
    var level = model.getCurrentLevel(now);
    // Should be sum of both doses
    return (level >= 161 && level <= 165);
}

(:test)
function testExpiredDosesArePruned(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    // Add dose 48 hours ago — should decay well below 1mg
    model.addDose(100, now - 172800);
    var level = model.getCurrentLevel(now);
    return (level < 1);
}

(:test)
function testDailyIntakeSumsAllDosesToday(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    model.addDose(95, now - 3600);  // 1 hour ago
    model.addDose(63, now - 1800);  // 30 min ago
    var daily = model.getDailyIntake(now);
    return (daily == 158);
}

(:test)
function testTimeToSafeWithNoDoses(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    var minutes = model.getMinutesToSafe(now, 50);
    return (minutes == 0);
}

(:test)
function testTimeToSafeWithActiveDose(logger as Logger) as Boolean {
    var model = new CaffeineModel();
    var now = Time.now().value();
    model.addDose(200, now);
    var minutes = model.getMinutesToSafe(now, 50);
    // 200 * 0.5^(t/5.7) = 50 → t = 5.7 * 2 = 11.4 hours = 684 minutes
    return (minutes >= 680 && minutes <= 690);
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# Build with test annotations included
monkeyc -d vivoactive5 -f monkey.jungle -o bin/HalfLifeCaffeineTest.prg -y private_key.der -t
```

Expected: compilation errors — `CaffeineModel` class not found.

- [ ] **Step 3: Implement CaffeineModel**

**source/CaffeineModel.mc:**
```monkey
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;

class CaffeineModel {

    // Half-life of caffeine in seconds (5.7 hours)
    private const HALF_LIFE_SECONDS = 20520;
    // ln(0.5) precomputed for decay formula
    private const LN_HALF = -0.6931471805599453d;
    // Decay constant: ln(0.5) / half_life
    private const DECAY_CONSTANT = -0.00003377d; // LN_HALF / 20520
    // Minimum mg before a dose is considered cleared
    private const MIN_DOSE_MG = 1.0;

    // Array of active doses: each is {:mg => Float, :time => Number (epoch seconds)}
    private var _doses as Array;

    function initialize() {
        _doses = [];
    }

    // Add a new caffeine dose
    function addDose(mg as Number, timeEpoch as Number) as Void {
        _doses.add({:mg => mg.toFloat(), :time => timeEpoch});
    }

    // Get current total caffeine level in mg
    function getCurrentLevel(nowEpoch as Number) as Float {
        var total = 0.0;
        pruneExpired(nowEpoch);
        for (var i = 0; i < _doses.size(); i++) {
            var dose = _doses[i];
            total += decayedAmount(dose[:mg], dose[:time], nowEpoch);
        }
        return total;
    }

    // Get total caffeine consumed today (sum of original doses, not decayed)
    function getDailyIntake(nowEpoch as Number) as Number {
        var todayStart = getMidnightEpoch(nowEpoch);
        var total = 0;
        for (var i = 0; i < _doses.size(); i++) {
            var dose = _doses[i];
            if (dose[:time] >= todayStart) {
                total += dose[:mg].toNumber();
            }
        }
        return total;
    }

    // Get minutes until total caffeine drops below safeLevel mg
    // Returns 0 if already below
    function getMinutesToSafe(nowEpoch as Number, safeLevel as Number) as Number {
        var currentLevel = getCurrentLevel(nowEpoch);
        if (currentLevel <= safeLevel) {
            return 0;
        }
        // Binary search: check in 1-minute increments over next 24 hours
        var low = 0;
        var high = 1440; // 24 hours in minutes
        while (low < high) {
            var mid = (low + high) / 2;
            var futureEpoch = nowEpoch + (mid * 60);
            var futureLevel = getCurrentLevel(futureEpoch);
            if (futureLevel <= safeLevel) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return low;
    }

    // Get array of projected levels for the next `hours` hours, sampled every 30 min
    // Returns array of {:minutesFromNow => Number, :mg => Float}
    function getProjection(nowEpoch as Number, hours as Number) as Array {
        var points = [];
        var intervalMinutes = 30;
        var totalMinutes = hours * 60;
        for (var m = 0; m <= totalMinutes; m += intervalMinutes) {
            var futureEpoch = nowEpoch + (m * 60);
            points.add({:minutesFromNow => m, :mg => getCurrentLevel(futureEpoch)});
        }
        return points;
    }

    // Get all doses (for storage serialization)
    function getDoses() as Array {
        return _doses;
    }

    // Load doses from storage (deserialization)
    function setDoses(doses as Array) as Void {
        _doses = doses;
    }

    // Get today's drink log: array of {:mg, :time} for doses logged today
    function getTodayLog(nowEpoch as Number) as Array {
        var todayStart = getMidnightEpoch(nowEpoch);
        var log = [];
        for (var i = 0; i < _doses.size(); i++) {
            var dose = _doses[i];
            if (dose[:time] >= todayStart) {
                log.add(dose);
            }
        }
        return log;
    }

    // Calculate decayed amount for a single dose
    private function decayedAmount(originalMg as Float, doseTimeEpoch as Number, nowEpoch as Number) as Float {
        var elapsedSeconds = nowEpoch - doseTimeEpoch;
        if (elapsedSeconds <= 0) {
            return originalMg;
        }
        // mg * e^(decay_constant * elapsed_seconds)
        // equivalent to: mg * 0.5^(elapsed / half_life)
        var remaining = originalMg * Math.pow(0.5, elapsedSeconds.toFloat() / HALF_LIFE_SECONDS.toFloat());
        return remaining;
    }

    // Remove doses that have decayed below MIN_DOSE_MG
    private function pruneExpired(nowEpoch as Number) as Void {
        var kept = [];
        for (var i = 0; i < _doses.size(); i++) {
            var dose = _doses[i];
            if (decayedAmount(dose[:mg], dose[:time], nowEpoch) >= MIN_DOSE_MG) {
                kept.add(dose);
            }
        }
        _doses = kept;
    }

    // Get epoch seconds for midnight today (local time)
    private function getMidnightEpoch(nowEpoch as Number) as Number {
        var moment = new Time.Moment(nowEpoch);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        var midnight = Gregorian.moment({
            :year => info.year,
            :month => info.month,
            :day => info.day,
            :hour => 0,
            :minute => 0,
            :second => 0
        });
        return midnight.value();
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
monkeyc -d vivoactive5 -f monkey.jungle -o bin/HalfLifeCaffeineTest.prg -y private_key.der -t
connectiq -s bin/HalfLifeCaffeineTest.prg -d vivoactive5 --test
```

Expected: all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add source/CaffeineModel.mc test/CaffeineModelTest.mc
git commit -m "feat: implement caffeine pharmacokinetic model with tests"
```

---

## Task 3: Drink Presets

**Goal:** Define the default drink presets and a loader that can merge in user-configured presets from settings.

**Files:**
- Create: `source/DrinkPresets.mc`

- [ ] **Step 1: Implement DrinkPresets**

**source/DrinkPresets.mc:**
```monkey
using Toybox.Application;

class DrinkPresets {

    // Each preset: {:name => String, :mg => Number}
    private var _presets as Array;

    function initialize() {
        _presets = getDefaults();
    }

    function getPresets() as Array {
        return _presets;
    }

    function getPresetCount() as Number {
        return _presets.size();
    }

    function getPresetAt(index as Number) as Dictionary {
        return _presets[index];
    }

    function getDefaults() as Array {
        return [
            {:name => "Espresso", :mg => 63},
            {:name => "Drip Coffee (S)", :mg => 95},
            {:name => "Drip Coffee (L)", :mg => 190},
            {:name => "Latte", :mg => 63},
            {:name => "Green Tea", :mg => 30},
            {:name => "Black Tea", :mg => 47},
            {:name => "Red Bull", :mg => 80},
            {:name => "Monster", :mg => 160},
            {:name => "Cola", :mg => 34},
            {:name => "Dark Chocolate", :mg => 25},
            {:name => "Pre-Workout", :mg => 200}
        ];
    }
}
```

- [ ] **Step 2: Verify compilation**

```bash
monkeyc -d vivoactive5 -f monkey.jungle -o bin/HalfLifeCaffeine.prg -y private_key.der
```

Expected: compiles without errors.

- [ ] **Step 3: Commit**

```bash
git add source/DrinkPresets.mc
git commit -m "feat: add default drink presets"
```

---

## Task 4: Storage Manager

**Goal:** Persist caffeine doses and daily history to Application.Storage so data survives app restarts. Handle 14-day cleanup.

**Files:**
- Create: `source/StorageManager.mc`

- [ ] **Step 1: Implement StorageManager**

**source/StorageManager.mc:**
```monkey
using Toybox.Application;
using Toybox.Time;
using Toybox.Time.Gregorian;

class StorageManager {

    private const DOSES_KEY = "doses";
    private const LAST_SYNC_KEY = "lastSync";
    private const RETENTION_DAYS = 14;
    private const RETENTION_SECONDS = 1209600; // 14 * 24 * 60 * 60

    // Save all active doses to storage
    // doses: Array of {:mg => Float, :time => Number}
    function saveDoses(doses as Array) as Void {
        // Convert to storable format (arrays of arrays, since storage doesn't persist symbols)
        var storable = [];
        for (var i = 0; i < doses.size(); i++) {
            var dose = doses[i];
            storable.add([dose[:mg], dose[:time]]);
        }
        Application.Storage.setValue(DOSES_KEY, storable);
    }

    // Load doses from storage
    // Returns Array of {:mg => Float, :time => Number}
    function loadDoses() as Array {
        var storable = Application.Storage.getValue(DOSES_KEY);
        var doses = [];
        if (storable != null && storable instanceof Array) {
            for (var i = 0; i < storable.size(); i++) {
                var entry = storable[i];
                if (entry instanceof Array && entry.size() == 2) {
                    doses.add({:mg => entry[0].toFloat(), :time => entry[1].toNumber()});
                }
            }
        }
        return doses;
    }

    // Remove doses older than 14 days
    function pruneOldDoses(doses as Array, nowEpoch as Number) as Array {
        var cutoff = nowEpoch - RETENTION_SECONDS;
        var kept = [];
        for (var i = 0; i < doses.size(); i++) {
            if (doses[i][:time] >= cutoff) {
                kept.add(doses[i]);
            }
        }
        return kept;
    }

    // Save the epoch of the last successful sync to phone
    function saveLastSyncTime(epochSeconds as Number) as Void {
        Application.Storage.setValue(LAST_SYNC_KEY, epochSeconds);
    }

    // Get the epoch of the last successful sync
    function getLastSyncTime() as Number {
        var value = Application.Storage.getValue(LAST_SYNC_KEY);
        if (value != null && value instanceof Number) {
            return value;
        }
        return 0;
    }

    // Get doses added since a given epoch (for incremental sync)
    function getDosesSince(doses as Array, sinceEpoch as Number) as Array {
        var result = [];
        for (var i = 0; i < doses.size(); i++) {
            if (doses[i][:time] > sinceEpoch) {
                result.add(doses[i]);
            }
        }
        return result;
    }
}
```

- [ ] **Step 2: Verify compilation**

```bash
monkeyc -d vivoactive5 -f monkey.jungle -o bin/HalfLifeCaffeine.prg -y private_key.der
```

Expected: compiles without errors.

- [ ] **Step 3: Commit**

```bash
git add source/StorageManager.mc
git commit -m "feat: add storage manager for dose persistence and 14-day cleanup"
```

---

## Task 5: Utility Helpers

**Goal:** Time formatting helpers used across all views.

**Files:**
- Create: `source/Util.mc`

- [ ] **Step 1: Implement Util**

**source/Util.mc:**
```monkey
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

module Util {

    // Format minutes as "Xh Ym" (e.g. 200 → "3h 20m")
    function formatDuration(totalMinutes as Number) as String {
        if (totalMinutes <= 0) {
            return "0m";
        }
        var hours = totalMinutes / 60;
        var mins = totalMinutes % 60;
        if (hours > 0 && mins > 0) {
            return hours + "h " + mins + "m";
        } else if (hours > 0) {
            return hours + "h";
        } else {
            return mins + "m";
        }
    }

    // Format epoch to "HH:MM" local time
    function formatTime(epochSeconds as Number) as String {
        var moment = new Time.Moment(epochSeconds);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        var h = info.hour.format("%02d");
        var m = info.min.format("%02d");
        return h + ":" + m;
    }

    // Format a caffeine level to a display string (e.g. 142.7 → "143")
    function formatMg(mg as Float) as String {
        return mg.toNumber().toString();
    }
}
```

- [ ] **Step 2: Verify compilation**

```bash
monkeyc -d vivoactive5 -f monkey.jungle -o bin/HalfLifeCaffeine.prg -y private_key.der
```

- [ ] **Step 3: Commit**

```bash
git add source/Util.mc
git commit -m "feat: add time and caffeine formatting utilities"
```

---

## Task 6: Alert Manager

**Goal:** Implement daily limit alerts (80%, 100%) and safe-to-sleep notification logic.

**Files:**
- Create: `source/AlertManager.mc`

- [ ] **Step 1: Implement AlertManager**

**source/AlertManager.mc:**
```monkey
using Toybox.Application;
using Toybox.Attention;
using Toybox.Time;
using Toybox.Time.Gregorian;

class AlertManager {

    private const WARNING_THRESHOLD = 0.8;  // 80% of daily limit
    private const SLEEP_SAFE_MG = 50;
    private const SLEEP_WINDOW_SECONDS = 7200; // 2 hours before bedtime

    // Tracks which alerts have fired today (reset at midnight)
    private var _warningFiredDate as Number;   // day-of-year when warning last fired
    private var _limitFiredDate as Number;      // day-of-year when limit alert last fired
    private var _sleepFiredDate as Number;      // day-of-year when sleep alert last fired

    function initialize() {
        _warningFiredDate = -1;
        _limitFiredDate = -1;
        _sleepFiredDate = -1;
    }

    // Check and fire alerts based on current state
    // Returns a status string for the UI: "ok", "warning", or "over"
    function checkAlerts(dailyIntake as Number, currentLevel as Float, nowEpoch as Number) as String {
        var app = Application.getApp();
        var dailyLimit = app.getProperty("dailyLimit");
        if (dailyLimit == null) { dailyLimit = 400; }

        var today = getDayOfYear(nowEpoch);
        var status = "ok";

        // Check 100% limit first (higher priority)
        if (dailyIntake >= dailyLimit) {
            status = "over";
            if (_limitFiredDate != today && app.getProperty("alertLimitReached")) {
                _limitFiredDate = today;
                vibrateStrong();
            }
        }
        // Check 80% warning
        else if (dailyIntake >= (dailyLimit * WARNING_THRESHOLD).toNumber()) {
            status = "warning";
            if (_warningFiredDate != today && app.getProperty("alertLimitWarning")) {
                _warningFiredDate = today;
                vibrateGentle();
            }
        }

        // Check safe-to-sleep
        checkSleepAlert(currentLevel, nowEpoch, today);

        return status;
    }

    private function checkSleepAlert(currentLevel as Float, nowEpoch as Number, today as Number) as Void {
        var app = Application.getApp();
        if (!app.getProperty("alertSafeToSleep")) {
            return;
        }
        if (_sleepFiredDate == today) {
            return;
        }
        if (currentLevel >= SLEEP_SAFE_MG) {
            return;
        }
        // Check if within 2 hours of bedtime
        var bedtimeEpoch = getBedtimeEpoch(nowEpoch);
        var timeUntilBed = bedtimeEpoch - nowEpoch;
        if (timeUntilBed > 0 && timeUntilBed <= SLEEP_WINDOW_SECONDS) {
            _sleepFiredDate = today;
            vibrateGentle();
        }
    }

    // Get bedtime as epoch seconds for today
    private function getBedtimeEpoch(nowEpoch as Number) as Number {
        var app = Application.getApp();
        var hour = app.getProperty("bedtimeHour");
        var minute = app.getProperty("bedtimeMinute");
        if (hour == null) { hour = 22; }
        if (minute == null) { minute = 30; }

        var moment = new Time.Moment(nowEpoch);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        var bedtime = Gregorian.moment({
            :year => info.year,
            :month => info.month,
            :day => info.day,
            :hour => hour,
            :minute => minute,
            :second => 0
        });
        return bedtime.value();
    }

    private function getDayOfYear(epochSeconds as Number) as Number {
        var moment = new Time.Moment(epochSeconds);
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.day_of_year;
    }

    private function vibrateGentle() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 500)]);
        }
    }

    private function vibrateStrong() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 300),
                new Attention.VibeProfile(0, 200),
                new Attention.VibeProfile(100, 300)
            ]);
        }
    }
}
```

- [ ] **Step 2: Verify compilation**

```bash
monkeyc -d vivoactive5 -f monkey.jungle -o bin/HalfLifeCaffeine.prg -y private_key.der
```

- [ ] **Step 3: Commit**

```bash
git add source/AlertManager.mc
git commit -m "feat: add alert manager for daily limits and sleep notifications"
```

---

## Task 7: Wire Up the App (Lifecycle & State)

**Goal:** Connect all the managers to the app lifecycle — load state on start, save on stop, create shared instances.

**Files:**
- Modify: `source/HalfLifeCaffeineApp.mc`

- [ ] **Step 1: Update HalfLifeCaffeineApp with full lifecycle**

Replace `source/HalfLifeCaffeineApp.mc` with:

```monkey
using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Time;

class HalfLifeCaffeineApp extends Application.AppBase {

    var caffeineModel as CaffeineModel?;
    var drinkPresets as DrinkPresets?;
    var storageManager as StorageManager?;
    var alertManager as AlertManager?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        storageManager = new StorageManager();
        caffeineModel = new CaffeineModel();
        drinkPresets = new DrinkPresets();
        alertManager = new AlertManager();

        // Load persisted doses
        var savedDoses = storageManager.loadDoses();
        var now = Time.now().value();
        savedDoses = storageManager.pruneOldDoses(savedDoses, now);
        caffeineModel.setDoses(savedDoses);
    }

    function onStop(state as Dictionary?) as Void {
        // Persist current doses
        if (caffeineModel != null && storageManager != null) {
            storageManager.saveDoses(caffeineModel.getDoses());
        }
    }

    function getGlanceView() as Array? {
        return [new GlanceView()];
    }

    function getView() as Array {
        return [new SummaryView(), new SummaryDelegate()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    // Helper to add a drink and trigger save + alerts
    function logDrink(presetIndex as Number) as Void {
        var preset = drinkPresets.getPresetAt(presetIndex);
        var now = Time.now().value();
        caffeineModel.addDose(preset[:mg], now);
        storageManager.saveDoses(caffeineModel.getDoses());

        // Check alerts
        var dailyIntake = caffeineModel.getDailyIntake(now);
        var currentLevel = caffeineModel.getCurrentLevel(now);
        alertManager.checkAlerts(dailyIntake, currentLevel, now);

        WatchUi.requestUpdate();
    }
}
```

- [ ] **Step 2: Build and test in simulator**

```bash
monkeyc -d vivoactive5 -f monkey.jungle -o bin/HalfLifeCaffeine.prg -y private_key.der
```

Launch in simulator. Verify the widget loads without crashes.

- [ ] **Step 3: Commit**

```bash
git add source/HalfLifeCaffeineApp.mc
git commit -m "feat: wire app lifecycle with caffeine model, storage, alerts"
```

---

## Task 8: Glance View (Real Data)

**Goal:** Update the glance to show real caffeine level and sleep status from the model.

**Files:**
- Modify: `source/GlanceView.mc`

- [ ] **Step 1: Update GlanceView with real data**

Replace `source/GlanceView.mc` with:

```monkey
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Time;

class GlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var app = Application.getApp() as HalfLifeCaffeineApp;
        var now = Time.now().value();

        var level = 0.0;
        var statusText = "Clear";

        if (app.caffeineModel != null) {
            level = app.caffeineModel.getCurrentLevel(now);
            if (level >= 1.0) {
                var minutesToSafe = app.caffeineModel.getMinutesToSafe(now, 50);
                if (minutesToSafe > 0) {
                    statusText = "Safe in " + Util.formatDuration(minutesToSafe);
                } else {
                    statusText = "Clear";
                }
            }
        }

        var mgText = Util.formatMg(level) + " mg";

        // Draw caffeine level (top line)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, dc.getHeight() * 0.3, Graphics.FONT_GLANCE,
            mgText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Draw status (bottom line)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, dc.getHeight() * 0.7, Graphics.FONT_GLANCE_NUMBER,
            statusText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
```

- [ ] **Step 2: Test in simulator**

Launch in simulator. Check the widget glance in the widget loop — should show "0 mg" and "Clear" initially.

- [ ] **Step 3: Commit**

```bash
git add source/GlanceView.mc
git commit -m "feat: show real caffeine level and sleep status in glance view"
```

---

## Task 9: Summary Screen (Screen 1)

**Goal:** Build the main widget screen showing caffeine level, progress bar, daily intake vs limit, and warning indicators.

**Files:**
- Modify: `source/SummaryView.mc`
- Modify: `source/SummaryDelegate.mc`

- [ ] **Step 1: Implement SummaryView with full layout**

Replace `source/SummaryView.mc` with:

```monkey
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Time;

class SummaryView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var app = Application.getApp() as HalfLifeCaffeineApp;
        var now = Time.now().value();
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Background
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
            alertStatus = app.alertManager.checkAlerts(dailyIntake, level, now);
        }

        var centerX = width / 2;

        // --- Current caffeine level (large, centered) ---
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.18, Graphics.FONT_NUMBER_HOT,
            Util.formatMg(level), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.33, Graphics.FONT_TINY,
            "mg caffeine", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- Progress bar (decay toward zero) ---
        var barY = (height * 0.42).toNumber();
        var barWidth = (width * 0.6).toNumber();
        var barHeight = 8;
        var barX = (centerX - barWidth / 2).toNumber();
        // Bar background
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barWidth, barHeight);
        // Bar fill — scale: 0 to dailyLimit
        var fillRatio = level.toFloat() / dailyLimit.toFloat();
        if (fillRatio > 1.0) { fillRatio = 1.0; }
        var fillWidth = (barWidth * fillRatio).toNumber();
        var barColor = Graphics.COLOR_GREEN;
        if (alertStatus.equals("warning")) { barColor = Graphics.COLOR_YELLOW; }
        if (alertStatus.equals("over")) { barColor = Graphics.COLOR_RED; }
        dc.setColor(barColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, fillWidth, barHeight);

        // --- Time until sleep-safe ---
        var sleepText = "Clear";
        if (level >= 1.0 && minutesToSafe > 0) {
            sleepText = "Sleep safe in " + Util.formatDuration(minutesToSafe);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.55, Graphics.FONT_SMALL,
            sleepText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- Daily intake vs limit ---
        var intakeText = dailyIntake.toString() + " / " + dailyLimit.toString() + " mg today";
        var intakeColor = Graphics.COLOR_LT_GRAY;
        if (alertStatus.equals("warning")) { intakeColor = Graphics.COLOR_YELLOW; }
        if (alertStatus.equals("over")) { intakeColor = Graphics.COLOR_RED; }
        dc.setColor(intakeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.70, Graphics.FONT_TINY,
            intakeText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- Hint to add drink ---
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.88, Graphics.FONT_XTINY,
            "Press to add drink", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
```

- [ ] **Step 2: Update SummaryDelegate for navigation**

Replace `source/SummaryDelegate.mc` with:

```monkey
using Toybox.WatchUi;

class SummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // SELECT button → open drink menu
    function onSelect() as Boolean {
        var app = Application.getApp() as HalfLifeCaffeineApp;
        WatchUi.pushView(
            new WatchUi.Menu2({:title => "Add Drink"}),
            new DrinkMenuDelegate(),
            WatchUi.SLIDE_UP
        );
        // Populate the menu
        var menu = new WatchUi.Menu2({:title => "Add Drink"});
        for (var i = 0; i < app.drinkPresets.getPresetCount(); i++) {
            var preset = app.drinkPresets.getPresetAt(i);
            menu.addItem(new WatchUi.MenuItem(
                preset[:name],
                preset[:mg] + " mg",
                i,
                {}
            ));
        }
        WatchUi.switchToView(menu, new DrinkMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    // Swipe down → timeline view
    function onNextPage() as Boolean {
        WatchUi.switchToView(new TimelineView(), new TimelineDelegate(), WatchUi.SLIDE_UP);
        return true;
    }
}
```

- [ ] **Step 3: Test in simulator**

Build and launch. Verify:
- Summary screen shows "0 mg caffeine", "Clear", "0 / 400 mg today"
- Progress bar is empty (green)
- "Press to add drink" hint visible

- [ ] **Step 4: Commit**

```bash
git add source/SummaryView.mc source/SummaryDelegate.mc
git commit -m "feat: implement summary screen with caffeine level, progress bar, alerts"
```

---

## Task 10: Drink Menu & Logging

**Goal:** Implement the drink picker menu that appears when the user presses SELECT. Selecting a drink logs it and returns to the summary.

**Files:**
- Create: `source/DrinkMenuDelegate.mc`

- [ ] **Step 1: Implement DrinkMenuDelegate**

**source/DrinkMenuDelegate.mc:**
```monkey
using Toybox.WatchUi;
using Toybox.Application;

class DrinkMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var presetIndex = item.getId() as Number;
        var app = Application.getApp() as HalfLifeCaffeineApp;
        app.logDrink(presetIndex);

        // Pop back to summary
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
```

- [ ] **Step 2: Fix SummaryDelegate to build menu correctly**

The SummaryDelegate onSelect from Task 9 creates the menu inline. Let's clean it up — replace the `onSelect` method in `source/SummaryDelegate.mc`:

```monkey
    function onSelect() as Boolean {
        var app = Application.getApp() as HalfLifeCaffeineApp;
        var menu = new WatchUi.Menu2({:title => "Add Drink"});
        for (var i = 0; i < app.drinkPresets.getPresetCount(); i++) {
            var preset = app.drinkPresets.getPresetAt(i);
            menu.addItem(new WatchUi.MenuItem(
                preset[:name],
                preset[:mg] + " mg",
                i,
                {}
            ));
        }
        WatchUi.pushView(menu, new DrinkMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }
```

- [ ] **Step 3: Test in simulator**

Build and launch. Verify:
1. Press SELECT → drink menu appears with all 11 presets
2. Select "Espresso" → vibration → returns to summary
3. Summary now shows "63 mg caffeine", progress bar partially filled, "63 / 400 mg today"
4. Sleep-safe time updates to ~11+ hours

- [ ] **Step 4: Commit**

```bash
git add source/DrinkMenuDelegate.mc source/SummaryDelegate.mc
git commit -m "feat: add drink menu with logging and haptic feedback"
```

---

## Task 11: Timeline View (Screen 2)

**Goal:** Draw a line graph showing projected caffeine decay over the next 8 hours with bedtime marker and 50mg threshold line.

**Files:**
- Create: `source/TimelineView.mc`
- Create: `source/TimelineDelegate.mc`

- [ ] **Step 1: Implement TimelineView**

**source/TimelineView.mc:**
```monkey
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Time;

class TimelineView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var app = Application.getApp() as HalfLifeCaffeineApp;
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
        var maxMg = 50.0; // minimum scale
        for (var i = 0; i < projection.size(); i++) {
            var mg = projection[i][:mg] as Float;
            if (mg > maxMg) { maxMg = mg; }
        }
        maxMg = maxMg * 1.1; // 10% headroom

        // Draw axes
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(graphLeft, graphTop, graphLeft, graphBottom);
        dc.drawLine(graphLeft, graphBottom, graphRight, graphBottom);

        // Draw 50mg threshold line
        var safeY = graphBottom - ((50.0 / maxMg) * graphHeight).toNumber();
        if (safeY >= graphTop && safeY <= graphBottom) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            for (var x = graphLeft; x < graphRight; x += 6) {
                dc.drawLine(x, safeY, x + 3, safeY); // dashed line
            }
            dc.drawText(graphRight + 2, safeY, Graphics.FONT_XTINY,
                "50", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Draw bedtime marker
        var bedtimeEpoch = getBedtimeEpoch(now);
        var minutesUntilBed = (bedtimeEpoch - now) / 60;
        if (minutesUntilBed > 0 && minutesUntilBed < 480) { // within 8 hours
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
            var currentMg = projection[0][:mg] as Float;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(graphLeft + 4, graphTop + 4, Graphics.FONT_XTINY,
                Util.formatMg(currentMg) + "mg", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    private function getBedtimeEpoch(nowEpoch as Number) as Number {
        var app = Application.getApp();
        var hour = app.getProperty("bedtimeHour");
        var minute = app.getProperty("bedtimeMinute");
        if (hour == null) { hour = 22; }
        if (minute == null) { minute = 30; }

        var moment = new Time.Moment(nowEpoch);
        var info = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
        var bedtime = Time.Gregorian.moment({
            :year => info.year,
            :month => info.month,
            :day => info.day,
            :hour => hour,
            :minute => minute,
            :second => 0
        });
        return bedtime.value();
    }
}
```

- [ ] **Step 2: Implement TimelineDelegate**

**source/TimelineDelegate.mc:**
```monkey
using Toybox.WatchUi;

class TimelineDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Swipe down → log view
    function onNextPage() as Boolean {
        WatchUi.switchToView(new LogView(), new LogDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    // Swipe up → back to summary
    function onPreviousPage() as Boolean {
        WatchUi.switchToView(new SummaryView(), new SummaryDelegate(), WatchUi.SLIDE_DOWN);
        return true;
    }
}
```

- [ ] **Step 3: Test in simulator**

Build and launch. Log a drink from the summary screen, then swipe down to the timeline. Verify:
- Graph shows the decay curve starting at the current level
- 50mg threshold line visible (dashed yellow)
- Bedtime marker visible if within 8 hours
- Time labels along bottom (+0h, +2h, +4h, +6h, +8h)

- [ ] **Step 4: Commit**

```bash
git add source/TimelineView.mc source/TimelineDelegate.mc
git commit -m "feat: add timeline graph showing caffeine decay projection"
```

---

## Task 12: Log View (Screen 3)

**Goal:** Show today's drink log as a scrollable list.

**Files:**
- Create: `source/LogView.mc`
- Create: `source/LogDelegate.mc`

- [ ] **Step 1: Implement LogView**

**source/LogView.mc:**
```monkey
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Time;

class LogView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var app = Application.getApp() as HalfLifeCaffeineApp;
        var now = Time.now().value();
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Title
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.08, Graphics.FONT_XTINY,
            "Today's Drinks", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (app.caffeineModel == null) { return; }

        var log = app.caffeineModel.getTodayLog(now);

        if (log.size() == 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL,
                "No drinks today", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Draw drink entries (most recent first)
        var lineHeight = (height * 0.12).toNumber();
        var startY = (height * 0.18).toNumber();
        var maxVisible = ((height * 0.75) / lineHeight).toNumber();

        // Resolve preset names by matching mg values (best effort)
        var presets = app.drinkPresets;

        for (var i = log.size() - 1; i >= 0; i--) {
            var entryIndex = log.size() - 1 - i;
            if (entryIndex >= maxVisible) { break; }

            var dose = log[i];
            var timeStr = Util.formatTime(dose[:time]);
            var mgStr = Util.formatMg(dose[:mg]) + "mg";
            var name = findPresetName(presets, dose[:mg].toNumber());

            var y = startY + (entryIndex * lineHeight);

            // Time
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width * 0.15, y, Graphics.FONT_XTINY,
                timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            // Drink name
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width * 0.50, y, Graphics.FONT_XTINY,
                name, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            // Caffeine amount
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width * 0.85, y, Graphics.FONT_XTINY,
                mgStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function findPresetName(presets as DrinkPresets, mg as Number) as String {
        for (var i = 0; i < presets.getPresetCount(); i++) {
            var preset = presets.getPresetAt(i);
            if (preset[:mg] == mg) {
                return preset[:name];
            }
        }
        return mg + "mg";
    }
}
```

- [ ] **Step 2: Implement LogDelegate**

**source/LogDelegate.mc:**
```monkey
using Toybox.WatchUi;

class LogDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Swipe up → back to timeline
    function onPreviousPage() as Boolean {
        WatchUi.switchToView(new TimelineView(), new TimelineDelegate(), WatchUi.SLIDE_DOWN);
        return true;
    }
}
```

- [ ] **Step 3: Test in simulator**

Build and launch. Log 2-3 drinks, then swipe down past the timeline to the log view. Verify:
- "Today's Drinks" title
- Each drink shows time, name, and mg
- Most recent drink appears at top
- "No drinks today" shows when no drinks logged

- [ ] **Step 4: Commit**

```bash
git add source/LogView.mc source/LogDelegate.mc
git commit -m "feat: add today's drink log view"
```

---

## Task 13: Improve Log View with Drink Names

**Goal:** Store drink name alongside each dose so the log view can display the correct name even for custom presets or presets with the same mg.

**Files:**
- Modify: `source/CaffeineModel.mc`
- Modify: `source/StorageManager.mc`
- Modify: `source/HalfLifeCaffeineApp.mc`
- Modify: `source/LogView.mc`

- [ ] **Step 1: Update dose format to include name**

In `source/CaffeineModel.mc`, update `addDose`:

```monkey
    // Add a new caffeine dose with drink name
    function addDose(mg as Number, timeEpoch as Number, name as String) as Void {
        _doses.add({:mg => mg.toFloat(), :time => timeEpoch, :name => name});
    }
```

Update `addDose` call signature everywhere. Also update `getTodayLog` — it already returns the full dose dict, which now includes `:name`.

- [ ] **Step 2: Update StorageManager to persist names**

In `source/StorageManager.mc`, update `saveDoses`:

```monkey
    function saveDoses(doses as Array) as Void {
        var storable = [];
        for (var i = 0; i < doses.size(); i++) {
            var dose = doses[i];
            var name = dose.hasKey(:name) ? dose[:name] : "";
            storable.add([dose[:mg], dose[:time], name]);
        }
        Application.Storage.setValue(DOSES_KEY, storable);
    }
```

Update `loadDoses`:

```monkey
    function loadDoses() as Array {
        var storable = Application.Storage.getValue(DOSES_KEY);
        var doses = [];
        if (storable != null && storable instanceof Array) {
            for (var i = 0; i < storable.size(); i++) {
                var entry = storable[i];
                if (entry instanceof Array && entry.size() >= 2) {
                    var name = (entry.size() >= 3) ? entry[2].toString() : "";
                    doses.add({:mg => entry[0].toFloat(), :time => entry[1].toNumber(), :name => name});
                }
            }
        }
        return doses;
    }
```

- [ ] **Step 3: Update logDrink in HalfLifeCaffeineApp.mc**

```monkey
    function logDrink(presetIndex as Number) as Void {
        var preset = drinkPresets.getPresetAt(presetIndex);
        var now = Time.now().value();
        caffeineModel.addDose(preset[:mg], now, preset[:name]);
        storageManager.saveDoses(caffeineModel.getDoses());

        var dailyIntake = caffeineModel.getDailyIntake(now);
        var currentLevel = caffeineModel.getCurrentLevel(now);
        alertManager.checkAlerts(dailyIntake, currentLevel, now);

        WatchUi.requestUpdate();
    }
```

- [ ] **Step 4: Update LogView to use stored name**

In `source/LogView.mc`, replace the name-resolution line in the draw loop:

```monkey
            var name = dose.hasKey(:name) && !dose[:name].equals("") ? dose[:name] : Util.formatMg(dose[:mg]) + "mg";
```

Remove the `findPresetName` method.

- [ ] **Step 5: Update test to use new addDose signature**

In `test/CaffeineModelTest.mc`, update all `addDose` calls to include a name parameter:

```monkey
model.addDose(100, now, "Test");
model.addDose(63, now, "Test2");
model.addDose(95, now - 3600, "Test3");
```

- [ ] **Step 6: Run tests and verify**

```bash
monkeyc -d vivoactive5 -f monkey.jungle -o bin/HalfLifeCaffeineTest.prg -y private_key.der -t
```

Expected: all tests pass.

- [ ] **Step 7: Test in simulator**

Log drinks, check the log view shows the correct preset name for each entry.

- [ ] **Step 8: Commit**

```bash
git add source/CaffeineModel.mc source/StorageManager.mc source/HalfLifeCaffeineApp.mc source/LogView.mc test/CaffeineModelTest.mc
git commit -m "feat: store drink names with doses for accurate log display"
```

---

## Task 14: Settings (Properties + Settings XML)

**Goal:** Define the settings UI that appears in the Garmin Connect app for basic configuration (daily limit, bedtime, notification toggles).

**Files:**
- Create: `resources/settings.xml`
- Modify: `resources/properties.xml` (already exists, verify completeness)

- [ ] **Step 1: Create resources/settings.xml**

```xml
<settings>
  <setting propertyKey="@Properties.dailyLimit"
           title="Daily Caffeine Limit (mg)">
    <settingConfig type="numeric"
                   min="100"
                   max="1000"
                   default="400"/>
  </setting>

  <setting propertyKey="@Properties.bedtimeHour"
           title="Bedtime Hour (0-23)">
    <settingConfig type="numeric"
                   min="0"
                   max="23"
                   default="22"/>
  </setting>

  <setting propertyKey="@Properties.bedtimeMinute"
           title="Bedtime Minute (0-59)">
    <settingConfig type="numeric"
                   min="0"
                   max="59"
                   default="30"/>
  </setting>

  <setting propertyKey="@Properties.useGarminSleep"
           title="Use Garmin Sleep Schedule">
    <settingConfig type="boolean"/>
  </setting>

  <setting title="Notifications">
    <settingConfig type="group">
      <setting propertyKey="@Properties.alertLimitWarning"
               title="Warn at 80% of limit">
        <settingConfig type="boolean"/>
      </setting>

      <setting propertyKey="@Properties.alertLimitReached"
               title="Alert when limit reached">
        <settingConfig type="boolean"/>
      </setting>

      <setting propertyKey="@Properties.alertSafeToSleep"
               title="Safe to sleep notification">
        <settingConfig type="boolean"/>
      </setting>
    </settingConfig>
  </setting>
</settings>
```

- [ ] **Step 2: Verify compilation and test settings in simulator**

```bash
monkeyc -d vivoactive5 -f monkey.jungle -o bin/HalfLifeCaffeine.prg -y private_key.der
```

In the simulator, go to Settings → App Settings. Verify all settings appear with correct types and defaults.

- [ ] **Step 3: Commit**

```bash
git add resources/settings.xml resources/properties.xml
git commit -m "feat: add settings UI for daily limit, bedtime, notifications"
```

---

## Task 15: Sync Manager (Communications API)

**Goal:** Send drink log data to the phone companion via the Communications API. Receive settings updates from the phone.

**Files:**
- Create: `source/SyncManager.mc`
- Modify: `source/HalfLifeCaffeineApp.mc`

- [ ] **Step 1: Implement SyncManager**

**source/SyncManager.mc:**
```monkey
using Toybox.Communications;
using Toybox.Application;
using Toybox.Time;

class SyncManager {

    private var _storageManager as StorageManager;

    function initialize(storageManager as StorageManager) {
        _storageManager = storageManager;
    }

    // Send new drink entries to the phone companion
    function syncToPhone(allDoses as Array) as Void {
        var lastSync = _storageManager.getLastSyncTime();
        var newDoses = _storageManager.getDosesSince(allDoses, lastSync);

        if (newDoses.size() == 0) {
            return;
        }

        // Build the payload
        var payload = [];
        for (var i = 0; i < newDoses.size(); i++) {
            var dose = newDoses[i];
            var name = dose.hasKey(:name) ? dose[:name] : "";
            payload.add({
                "mg" => dose[:mg].toNumber(),
                "time" => dose[:time],
                "name" => name
            });
        }

        var message = {
            "type" => "drinks",
            "data" => payload
        };

        Communications.transmit(message, null, new SyncCallback(_storageManager));
    }

    // Register to receive messages from phone
    function registerPhoneListener() as Void {
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
    }

    function onPhoneMessage(message as Communications.PhoneAppMessage) as Void {
        var data = message.data;
        if (data == null) { return; }

        // Phone can send updated presets or settings
        if (data.hasKey("type") && data["type"].equals("settings")) {
            // Apply settings from phone companion
            var app = Application.getApp();
            if (data.hasKey("dailyLimit")) {
                app.setProperty("dailyLimit", data["dailyLimit"]);
            }
            if (data.hasKey("bedtimeHour")) {
                app.setProperty("bedtimeHour", data["bedtimeHour"]);
            }
            if (data.hasKey("bedtimeMinute")) {
                app.setProperty("bedtimeMinute", data["bedtimeMinute"]);
            }
        }

        WatchUi.requestUpdate();
    }
}

// Callback class for transmit result
class SyncCallback extends Communications.ConnectionListener {

    private var _storageManager as StorageManager;

    function initialize(storageManager as StorageManager) {
        ConnectionListener.initialize();
        _storageManager = storageManager;
    }

    function onComplete() as Void {
        _storageManager.saveLastSyncTime(Time.now().value());
    }

    function onError() as Void {
        // Silently fail — will retry on next sync trigger
    }
}
```

- [ ] **Step 2: Wire SyncManager into the app**

In `source/HalfLifeCaffeineApp.mc`, add the sync manager:

Add field:
```monkey
    var syncManager as SyncManager?;
```

In `onStart`, after creating storageManager:
```monkey
        syncManager = new SyncManager(storageManager);
        syncManager.registerPhoneListener();
```

In `logDrink`, after saving doses:
```monkey
        syncManager.syncToPhone(caffeineModel.getDoses());
```

- [ ] **Step 3: Verify compilation**

```bash
monkeyc -d vivoactive5 -f monkey.jungle -o bin/HalfLifeCaffeine.prg -y private_key.der
```

- [ ] **Step 4: Commit**

```bash
git add source/SyncManager.mc source/HalfLifeCaffeineApp.mc
git commit -m "feat: add sync manager for watch-to-phone communication"
```

---

## Task 16: Phone Companion (Web Settings Page)

**Goal:** Build the HTML/JS web settings page that runs inside the Garmin Connect app. This provides drink preset management, history view, and trend charts.

**Files:**
- Create: `companion/settings/index.html`

- [ ] **Step 1: Create the web settings page**

**companion/settings/index.html:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HalfLife Caffeine Settings</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #1a1a2e;
            color: #e0e0e0;
            padding: 16px;
            max-width: 480px;
            margin: 0 auto;
        }
        h1 { font-size: 1.4em; color: #4ecca3; margin-bottom: 16px; text-align: center; }
        h2 { font-size: 1.1em; color: #4ecca3; margin: 20px 0 10px; border-bottom: 1px solid #333; padding-bottom: 6px; }

        /* Tabs */
        .tabs { display: flex; gap: 4px; margin-bottom: 16px; }
        .tab {
            flex: 1; padding: 10px; text-align: center; background: #16213e;
            border: 1px solid #333; border-radius: 8px; cursor: pointer;
            font-size: 0.9em; color: #aaa; transition: all 0.2s;
        }
        .tab.active { background: #4ecca3; color: #1a1a2e; font-weight: bold; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }

        /* Settings */
        .setting-row {
            display: flex; justify-content: space-between; align-items: center;
            padding: 12px; background: #16213e; border-radius: 8px; margin-bottom: 8px;
        }
        .setting-label { font-size: 0.9em; }
        .setting-value input[type="number"] {
            width: 70px; padding: 6px; background: #0f3460; color: #fff;
            border: 1px solid #4ecca3; border-radius: 4px; text-align: center;
        }
        .toggle {
            width: 48px; height: 26px; background: #333; border-radius: 13px;
            position: relative; cursor: pointer; transition: background 0.2s;
        }
        .toggle.on { background: #4ecca3; }
        .toggle::after {
            content: ''; position: absolute; width: 22px; height: 22px;
            background: white; border-radius: 50%; top: 2px; left: 2px; transition: left 0.2s;
        }
        .toggle.on::after { left: 24px; }

        /* Presets */
        .preset-list { margin-bottom: 12px; }
        .preset-item {
            display: flex; justify-content: space-between; align-items: center;
            padding: 10px 12px; background: #16213e; border-radius: 8px; margin-bottom: 6px;
        }
        .preset-name { flex: 1; }
        .preset-mg { color: #4ecca3; font-weight: bold; margin-right: 12px; }
        .preset-delete { color: #e74c3c; cursor: pointer; font-size: 1.2em; }
        .add-preset {
            display: flex; gap: 8px; margin-bottom: 12px;
        }
        .add-preset input {
            flex: 1; padding: 8px; background: #0f3460; color: #fff;
            border: 1px solid #333; border-radius: 4px;
        }
        .add-preset input[type="number"] { width: 80px; flex: none; }
        .btn {
            padding: 8px 16px; background: #4ecca3; color: #1a1a2e;
            border: none; border-radius: 4px; cursor: pointer; font-weight: bold;
        }
        .btn:hover { background: #3ba88a; }
        .btn-save { width: 100%; padding: 12px; font-size: 1em; margin-top: 16px; }

        /* History */
        .history-day { margin-bottom: 12px; }
        .history-date {
            font-size: 0.85em; color: #4ecca3; margin-bottom: 4px; font-weight: bold;
        }
        .history-entry {
            display: flex; justify-content: space-between;
            padding: 6px 12px; background: #16213e; border-radius: 4px; margin-bottom: 3px;
            font-size: 0.85em;
        }
        .history-bar {
            height: 8px; background: #333; border-radius: 4px; margin-top: 4px;
        }
        .history-bar-fill { height: 100%; border-radius: 4px; }
        .bar-green { background: #4ecca3; }
        .bar-yellow { background: #f39c12; }
        .bar-red { background: #e74c3c; }

        /* Trends */
        .trend-stat {
            display: flex; justify-content: space-between;
            padding: 12px; background: #16213e; border-radius: 8px; margin-bottom: 8px;
        }
        .trend-value { color: #4ecca3; font-weight: bold; font-size: 1.2em; }
        canvas { width: 100%; background: #16213e; border-radius: 8px; margin-top: 8px; }

        .empty-state { text-align: center; color: #666; padding: 40px 16px; font-size: 0.9em; }
    </style>
</head>
<body>

<h1>&#9749; HalfLife Caffeine</h1>

<div class="tabs">
    <div class="tab active" onclick="switchTab('settings')">Settings</div>
    <div class="tab" onclick="switchTab('history')">History</div>
    <div class="tab" onclick="switchTab('trends')">Trends</div>
</div>

<!-- SETTINGS TAB -->
<div id="tab-settings" class="tab-content active">
    <h2>Limits</h2>
    <div class="setting-row">
        <span class="setting-label">Daily Limit (mg)</span>
        <div class="setting-value">
            <input type="number" id="dailyLimit" value="400" min="100" max="1000">
        </div>
    </div>

    <h2>Bedtime</h2>
    <div class="setting-row">
        <span class="setting-label">Bedtime Hour</span>
        <div class="setting-value">
            <input type="number" id="bedtimeHour" value="22" min="0" max="23">
        </div>
    </div>
    <div class="setting-row">
        <span class="setting-label">Bedtime Minute</span>
        <div class="setting-value">
            <input type="number" id="bedtimeMinute" value="30" min="0" max="59">
        </div>
    </div>
    <div class="setting-row">
        <span class="setting-label">Use Garmin Sleep</span>
        <div class="toggle on" id="useGarminSleep" onclick="toggleSetting(this)"></div>
    </div>

    <h2>Notifications</h2>
    <div class="setting-row">
        <span class="setting-label">Warn at 80%</span>
        <div class="toggle on" id="alertLimitWarning" onclick="toggleSetting(this)"></div>
    </div>
    <div class="setting-row">
        <span class="setting-label">Alert at 100%</span>
        <div class="toggle on" id="alertLimitReached" onclick="toggleSetting(this)"></div>
    </div>
    <div class="setting-row">
        <span class="setting-label">Safe to sleep</span>
        <div class="toggle on" id="alertSafeToSleep" onclick="toggleSetting(this)"></div>
    </div>

    <h2>Drink Presets</h2>
    <div class="add-preset">
        <input type="text" id="newPresetName" placeholder="Drink name">
        <input type="number" id="newPresetMg" placeholder="mg" min="1" max="500">
        <button class="btn" onclick="addPreset()">Add</button>
    </div>
    <div id="presetList" class="preset-list"></div>

    <button class="btn btn-save" onclick="saveSettings()">Save Settings</button>
</div>

<!-- HISTORY TAB -->
<div id="tab-history" class="tab-content">
    <h2>Drink History</h2>
    <div id="historyContent"></div>
</div>

<!-- TRENDS TAB -->
<div id="tab-trends" class="tab-content">
    <h2>Overview</h2>
    <div class="trend-stat">
        <span>7-Day Average</span>
        <span class="trend-value" id="avg7day">-- mg</span>
    </div>
    <div class="trend-stat">
        <span>30-Day Average</span>
        <span class="trend-value" id="avg30day">-- mg</span>
    </div>
    <div class="trend-stat">
        <span>Days Over Limit</span>
        <span class="trend-value" id="daysOver">--</span>
    </div>

    <h2>Daily Intake</h2>
    <canvas id="trendChart" height="200"></canvas>

    <h2>Peak Hours</h2>
    <canvas id="peakChart" height="150"></canvas>
</div>

<script>
// --- State ---
var drinkHistory = JSON.parse(localStorage.getItem('drinkHistory') || '[]');
var presets = JSON.parse(localStorage.getItem('presets') || 'null');
if (!presets) {
    presets = [
        {name: "Espresso", mg: 63},
        {name: "Drip Coffee (S)", mg: 95},
        {name: "Drip Coffee (L)", mg: 190},
        {name: "Latte", mg: 63},
        {name: "Green Tea", mg: 30},
        {name: "Black Tea", mg: 47},
        {name: "Red Bull", mg: 80},
        {name: "Monster", mg: 160},
        {name: "Cola", mg: 34},
        {name: "Dark Chocolate", mg: 25},
        {name: "Pre-Workout", mg: 200}
    ];
}

// --- Tabs ---
function switchTab(name) {
    document.querySelectorAll('.tab').forEach(function(t) { t.classList.remove('active'); });
    document.querySelectorAll('.tab-content').forEach(function(t) { t.classList.remove('active'); });
    event.target.classList.add('active');
    document.getElementById('tab-' + name).classList.add('active');
    if (name === 'history') { renderHistory(); }
    if (name === 'trends') { renderTrends(); }
}

// --- Toggles ---
function toggleSetting(el) {
    el.classList.toggle('on');
}

// --- Presets ---
function renderPresets() {
    var html = '';
    for (var i = 0; i < presets.length; i++) {
        html += '<div class="preset-item">' +
            '<span class="preset-name">' + presets[i].name + '</span>' +
            '<span class="preset-mg">' + presets[i].mg + ' mg</span>' +
            '<span class="preset-delete" onclick="removePreset(' + i + ')">&#x2715;</span>' +
            '</div>';
    }
    document.getElementById('presetList').innerHTML = html;
}

function addPreset() {
    var name = document.getElementById('newPresetName').value.trim();
    var mg = parseInt(document.getElementById('newPresetMg').value);
    if (!name || !mg || mg <= 0) { return; }
    presets.push({name: name, mg: mg});
    document.getElementById('newPresetName').value = '';
    document.getElementById('newPresetMg').value = '';
    renderPresets();
}

function removePreset(index) {
    presets.splice(index, 1);
    renderPresets();
}

// --- Save ---
function saveSettings() {
    localStorage.setItem('presets', JSON.stringify(presets));
    // Collect settings to send back to watch
    var settings = {
        dailyLimit: parseInt(document.getElementById('dailyLimit').value),
        bedtimeHour: parseInt(document.getElementById('bedtimeHour').value),
        bedtimeMinute: parseInt(document.getElementById('bedtimeMinute').value),
        useGarminSleep: document.getElementById('useGarminSleep').classList.contains('on'),
        alertLimitWarning: document.getElementById('alertLimitWarning').classList.contains('on'),
        alertLimitReached: document.getElementById('alertLimitReached').classList.contains('on'),
        alertSafeToSleep: document.getElementById('alertSafeToSleep').classList.contains('on'),
        presets: presets
    };
    // Send to Connect IQ app via URL scheme
    try {
        var encoded = encodeURIComponent(JSON.stringify(settings));
        window.location.href = "ciq://settings?" + encoded;
    } catch(e) {
        alert("Settings saved locally.");
    }
}

// --- History ---
function renderHistory() {
    var container = document.getElementById('historyContent');
    if (drinkHistory.length === 0) {
        container.innerHTML = '<div class="empty-state">No drink history yet.<br>Log drinks on your watch to see them here.</div>';
        return;
    }
    var dailyLimit = parseInt(document.getElementById('dailyLimit').value) || 400;
    // Group by date
    var days = {};
    for (var i = 0; i < drinkHistory.length; i++) {
        var d = drinkHistory[i];
        var date = new Date(d.time * 1000).toLocaleDateString();
        if (!days[date]) { days[date] = []; }
        days[date].push(d);
    }
    var html = '';
    var sortedDates = Object.keys(days).sort().reverse();
    for (var j = 0; j < sortedDates.length && j < 14; j++) {
        var dateStr = sortedDates[j];
        var entries = days[dateStr];
        var total = entries.reduce(function(sum, e) { return sum + e.mg; }, 0);
        var ratio = Math.min(total / dailyLimit, 1);
        var barClass = ratio < 0.8 ? 'bar-green' : (ratio < 1 ? 'bar-yellow' : 'bar-red');

        html += '<div class="history-day">';
        html += '<div class="history-date">' + dateStr + ' — ' + total + ' mg</div>';
        html += '<div class="history-bar"><div class="history-bar-fill ' + barClass + '" style="width:' + (ratio * 100) + '%"></div></div>';
        for (var k = entries.length - 1; k >= 0; k--) {
            var e = entries[k];
            var time = new Date(e.time * 1000).toLocaleTimeString([], {hour:'2-digit', minute:'2-digit'});
            html += '<div class="history-entry"><span>' + time + ' — ' + (e.name || 'Unknown') + '</span><span>' + e.mg + ' mg</span></div>';
        }
        html += '</div>';
    }
    container.innerHTML = html;
}

// --- Trends ---
function renderTrends() {
    if (drinkHistory.length === 0) { return; }
    var dailyLimit = parseInt(document.getElementById('dailyLimit').value) || 400;

    // Compute daily totals
    var dailyTotals = {};
    for (var i = 0; i < drinkHistory.length; i++) {
        var d = drinkHistory[i];
        var date = new Date(d.time * 1000).toISOString().split('T')[0];
        dailyTotals[date] = (dailyTotals[date] || 0) + d.mg;
    }

    var dates = Object.keys(dailyTotals).sort();
    var last7 = dates.slice(-7);
    var last30 = dates.slice(-30);

    // Averages
    var sum7 = last7.reduce(function(s, d) { return s + dailyTotals[d]; }, 0);
    var sum30 = last30.reduce(function(s, d) { return s + dailyTotals[d]; }, 0);
    document.getElementById('avg7day').textContent = last7.length > 0 ? Math.round(sum7 / last7.length) + ' mg' : '-- mg';
    document.getElementById('avg30day').textContent = last30.length > 0 ? Math.round(sum30 / last30.length) + ' mg' : '-- mg';

    // Days over limit
    var over = dates.filter(function(d) { return dailyTotals[d] > dailyLimit; }).length;
    document.getElementById('daysOver').textContent = over + ' / ' + dates.length;

    // Daily intake chart
    var canvas = document.getElementById('trendChart');
    var ctx = canvas.getContext('2d');
    canvas.width = canvas.offsetWidth * 2;
    canvas.height = 400;
    ctx.scale(2, 2);
    var cw = canvas.offsetWidth;
    var ch = 200;
    ctx.clearRect(0, 0, cw, ch);

    var displayDates = dates.slice(-14);
    var maxVal = Math.max(dailyLimit, Math.max.apply(null, displayDates.map(function(d) { return dailyTotals[d]; }))) * 1.1;
    var barW = (cw - 40) / displayDates.length;

    // Limit line
    var limitY = ch - 20 - ((dailyLimit / maxVal) * (ch - 40));
    ctx.strokeStyle = '#e74c3c';
    ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.moveTo(20, limitY);
    ctx.lineTo(cw - 20, limitY);
    ctx.stroke();
    ctx.setLineDash([]);

    // Bars
    for (var b = 0; b < displayDates.length; b++) {
        var val = dailyTotals[displayDates[b]];
        var barH = (val / maxVal) * (ch - 40);
        var bx = 20 + b * barW + barW * 0.15;
        var by = ch - 20 - barH;
        ctx.fillStyle = val > dailyLimit ? '#e74c3c' : (val > dailyLimit * 0.8 ? '#f39c12' : '#4ecca3');
        ctx.fillRect(bx, by, barW * 0.7, barH);
    }

    // Peak hours chart
    var peakCanvas = document.getElementById('peakChart');
    var pctx = peakCanvas.getContext('2d');
    peakCanvas.width = peakCanvas.offsetWidth * 2;
    peakCanvas.height = 300;
    pctx.scale(2, 2);
    var pw = peakCanvas.offsetWidth;
    var ph = 150;
    pctx.clearRect(0, 0, pw, ph);

    var hourBuckets = new Array(24).fill(0);
    for (var h = 0; h < drinkHistory.length; h++) {
        var hour = new Date(drinkHistory[h].time * 1000).getHours();
        hourBuckets[hour] += drinkHistory[h].mg;
    }
    var maxHour = Math.max.apply(null, hourBuckets) || 1;
    var hBarW = (pw - 40) / 24;

    for (var hr = 0; hr < 24; hr++) {
        var hBarH = (hourBuckets[hr] / maxHour) * (ph - 40);
        var hx = 20 + hr * hBarW + hBarW * 0.1;
        var hy = ph - 20 - hBarH;
        pctx.fillStyle = '#4ecca3';
        pctx.fillRect(hx, hy, hBarW * 0.8, hBarH);
        if (hr % 4 === 0) {
            pctx.fillStyle = '#666';
            pctx.font = '9px sans-serif';
            pctx.fillText(hr + ':00', hx, ph - 4);
        }
    }
}

// --- Receive data from watch ---
function onWatchData(data) {
    if (data && data.type === 'drinks' && data.data) {
        for (var i = 0; i < data.data.length; i++) {
            drinkHistory.push(data.data[i]);
        }
        localStorage.setItem('drinkHistory', JSON.stringify(drinkHistory));
    }
}

// --- Init ---
renderPresets();
</script>

</body>
</html>
```

- [ ] **Step 2: Wire companion settings into monkey.jungle**

Add to `monkey.jungle`:
```
base.barrelPath = companion
```

Note: The exact mechanism for linking the web settings page depends on the Connect IQ SDK version. In newer SDK versions, place the settings page at `resources/settings/` or configure via the manifest. Consult the SDK docs for the exact path your SDK version expects. The HTML file may need to be referenced in the manifest or the settings XML as a `settingConfig type="url"` pointing to a hosted version.

- [ ] **Step 3: Commit**

```bash
git add companion/settings/index.html monkey.jungle
git commit -m "feat: add phone companion web settings with history and trends"
```

---

## Task 17: Store Assets & Final Polish

**Goal:** Create the app icon, finalize the manifest, and prepare for Connect IQ Store submission.

**Files:**
- Create: `resources/images/launcher-icon.png` (final version)
- Modify: `manifest.xml` (verify device list)
- Create: `README.md` (for the repo)

- [ ] **Step 1: Create app icon**

Create a 256x256 PNG icon for the store listing. The icon should:
- Feature a coffee cup with a half-life decay curve
- Use green (#4ecca3) as the accent color on a dark (#1a1a2e) background
- Be clean and recognizable at small sizes

Use an image editor or AI image generator to create this. Save to `resources/images/launcher-icon.png`.

- [ ] **Step 2: Verify manifest device list**

Open `manifest.xml` and verify all target device IDs are valid for the current SDK. Check against the SDK's device list:

```bash
# List available devices in your SDK
ls "$CONNECT_IQ_SDK/Devices/"
```

Update `manifest.xml` device IDs to match exactly what the SDK expects.

- [ ] **Step 3: Build for all target devices**

```bash
# Build the .iq package for store submission
monkeyc -e -f monkey.jungle -o bin/HalfLifeCaffeine.iq -y private_key.der
```

This builds for all devices listed in the manifest. Fix any device-specific compilation errors.

- [ ] **Step 4: Test on physical Vivoactive 5**

Sideload the .prg file to your Vivoactive 5:
1. Connect watch via USB
2. Copy .prg to `GARMIN/Apps/` on the watch
3. Disconnect and verify:
   - Widget appears in widget loop
   - Glance shows caffeine level
   - Can log drinks from menu
   - All 3 screens work (summary, timeline, log)
   - Settings appear in Garmin Connect app

- [ ] **Step 5: Commit**

```bash
git add resources/images/ manifest.xml
git commit -m "feat: finalize store assets and device manifest"
```

---

## Task 18: Connect IQ Store Submission

**Goal:** Submit the app to the Garmin Connect IQ Store.

- [ ] **Step 1: Create a developer account**

Go to https://developer.garmin.com/connect-iq/ and sign up for a free developer account if you don't have one.

- [ ] **Step 2: Prepare store listing**

Prepare the following for the store submission:
- **App Name:** HalfLife Caffeine
- **Description:** "Track your caffeine intake and see how it decays in your body. HalfLife Caffeine uses a pharmacokinetic model to show your current caffeine level, predict when you'll be safe to sleep, and alert you when approaching your daily limit. Supports coffee, tea, energy drinks, and any caffeinated beverage. Completely free, no ads."
- **Category:** Health & Fitness
- **Screenshots:** Take 3-4 screenshots from the simulator showing the glance, summary, timeline, and drink menu
- **Icon:** The 256x256 launcher icon

- [ ] **Step 3: Upload and submit**

1. Go to https://apps.garmin.com/developer/
2. Create new app → Widget
3. Upload the .iq file
4. Fill in listing details
5. Upload screenshots and icon
6. Submit for review

- [ ] **Step 4: Tag the release**

```bash
git tag -a v1.0.0 -m "Initial release: HalfLife Caffeine v1.0.0"
```
