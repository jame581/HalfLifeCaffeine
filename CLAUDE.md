# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**HalfLife Caffeine** — a Connect IQ widget for Garmin watches that tracks caffeine intake and models its exponential decay (5.7h half-life). The repo folder is still named `CoffeTracker` (original name, taken on the Connect IQ store). The app ID in `manifest.xml` is authoritative for store publishing.

Entry class: `HalfLifeCaffeineApp` (`source/HalfLifeCaffeineApp.mc`). Widget type, `minApiLevel 3.2.0`, targets vivoactive4/5, venu2/3 family, fr955/965, fenix6/7, epix2.

Live on the Connect IQ store since 2026-04-24: https://apps.garmin.com/en-US/apps/7f81c51f-3f4c-486b-b38f-444ac962df47

## Build & test

Monkey C projects are built through the VS Code Monkey C extension, not a CLI task runner. `.vscode/launch.json` provides:

- **Run App** — build and launch in simulator
- **Run App with Debug** — same but stops at launch and opens debugger on port 4711
- **Run Tests** — executes `(:test)`-annotated functions (e.g. `test/CaffeineModelTest.mc`)

All launches prompt `GetTargetDevice` (the simulator picks the device). The build produces `bin/CoffeTracker.prg` + `bin/CoffeTracker.prg.debug.xml`. Simulator devices are installed under `%APPDATA%/Garmin/ConnectIQ/Devices/`.

`monkey.jungle` excludes the `test` annotation from non-test builds — test files must be tagged `(:test)`.

### CLI builds

Developer key lives at `D:/Garmin/Key/developer_key` (DER, not in repo, not regenerable without re-registering with the store).

Single-device (for simulator/sideload):
```
monkeyc -f monkey.jungle -d vivoactive5_sim -y D:/Garmin/Key/developer_key -o bin/CoffeTracker.prg -w
```

Multi-device release `.iq` (43 devices, ~770 KB):
```
monkeyc -e -f monkey.jungle -y D:/Garmin/Key/developer_key -o bin/HalfLifeCaffeine.iq
```

## Architecture

### Two execution contexts

The widget runs in **two separate processes** that do not share in-memory state:

1. **Glance process** — renders the at-a-glance tile. Only code annotated `(:glance)` is linked into this process. Managers initialized in `getInitialView()` are **not available here**. `GlanceView.onUpdate()` works around this by instantiating `StorageManager` + `CaffeineModel` fresh and loading doses directly from storage.
2. **Full-view widget process** — launched when the user taps into the widget. `HalfLifeCaffeineApp.initializeManagers()` runs lazily on first `getInitialView()` call and wires up all managers.

When adding a class that must be reachable from the glance, annotate the class with `(:glance)` (see `CaffeineModel`, `StorageManager`, `Util`). Forgetting this causes link-time errors only for glance builds.

### Manager wiring (full-view process)

`HalfLifeCaffeineApp` owns five managers, initialized together in `initializeManagers()`:

- `StorageManager` — persistence layer for doses + last-sync timestamp. 14-day retention.
- `CaffeineModel` — domain logic: dose list, decay math (`0.5^(elapsed/HALF_LIFE)`), projections, `getMinutesToSafe()` binary search.
- `DrinkPresets` — user-editable drink menu, persisted separately. Defaults baked into `getDefaults()`.
- `AlertManager` — fires vibrations for 80%/100% limit + safe-to-sleep (once per day, tracked by `_*FiredDate`).
- `SyncManager` — bidirectional phone sync via `Communications`.

`onPhoneMessage` is registered in `initializeManagers()` and delegates to `SyncManager.handlePhoneMessage()`.

### Persistence: two stores, two conventions

- **`Application.Properties`** — typed user settings defined in `resources/properties.xml` + `resources/settings.xml` (daily limit, bedtime, alert toggles). Mirrored from the phone companion.
- **`Application.Storage`** — app state (doses, presets, last-sync time). Keys are private constants on each manager.

**Dictionaries do not round-trip reliably through Storage.** Both `StorageManager.saveDoses` and `DrinkPresets.saveToStorage` serialize dicts to arrays of primitives (`[mg, time, name]` and `[name, mg]`) and rehydrate on load. Keep this convention when adding persisted state.

### Phone companion protocol

The companion app lives in `companion/settings/` (a single-page web app served by the Connect IQ mobile app). Messages are JSON objects with a `"type"` discriminator:

- **Watch → phone** (`SyncManager.syncToPhone`): `{type: "drinks", data: [{mg, time, name}, ...]}`. Only doses newer than `lastSyncTime` are sent; `lastSyncTime` advances only on `onComplete`.
- **Phone → watch** (`SyncManager.handlePhoneMessage`): `{type: "settings", dailyLimit?, bedtimeHour?, bedtimeMinute?, alertLimitWarning?, alertLimitReached?, alertSafeToSleep?, presets?}`. Each field writes its own Property; `presets` replaces the full preset list via `DrinkPresets.setPresets`.

### View navigation

Three full-screen views connected by swipes:

- `SummaryView` ↔ `TimelineView` ↔ `LogView` (each with its own delegate)
- Transitions use `switchToView` so they don't accumulate on the stack
- SELECT from `SummaryView` pushes a `Menu2` of drink presets (`DrinkMenuDelegate`), which calls `app.logDrink(index)` and pops

### Domain invariants

- Half-life constant: `HALF_LIFE_SECONDS = 20520` (5.7h, `CaffeineModel`). Sleep-safe threshold: 50mg (`AlertManager.SLEEP_SAFE_MG`, `GlanceView`, `SummaryView`).
- `pruneExpiredDoses` removes doses once they decay below 1mg — must only be called with the real current time (never a projected future time), or non-expired doses will be dropped.
- `getMinutesToSafe` binary-searches over the next 24h in 1-minute steps; returns 0 if already below threshold.
- Bedtime logic in `Util.getBedtimeEpoch` rolls forward a day if today's bedtime has passed.

## Conventions

- All `.mc` files use single-quoted Monkey C syntax and typed imports (`import Toybox.*`).
- `StorageManager`, `CaffeineModel`, `Util` are `(:glance)`-tagged because the glance view instantiates them.
- `Util` is a **module**, not a class — call as `Util.formatMg(...)`.
- `Colors` is also a module — shared palette (`BG 0x1A2332`, `ACCENT 0x3DDBA8`, plus semantic aliases). Use `Colors.ACCENT`, not hex literals.
- Prefer extending the existing manager set over adding new globals; add new manager wiring in `initializeManagers()` and remember `onStop` persistence if state is in-memory only.

### SDK 9.1.0 gotchas (hard-won)

- **Entry point is `getInitialView()`, not `getView()`.** Legacy `getView()` compiles but silently fails — symptom is the IQ crash icon on tap-through from glance. This was THE widget-to-view crash fix.
- **`import Toybox.*`, not `using Toybox.*`.** `using` broke type resolution for basic `Lang` types in 9.1.0. `import` brings types into scope automatically.
- **`manifest.xml` uses `minApiLevel`, not `minSdkVersion`.** Renamed in SDK 9.x.
- **Drawing coordinates must be integers.** `height * 0.18` returns a Float and crashes `drawText`/`fillRectangle` on-device. Use integer math (`height * 18 / 100`).
- **Type annotations in function signatures are mostly omitted.** Adding them triggered an error storm in 9.1.0. The resulting "Cannot determine container access" warnings are cosmetic and accepted — don't try to fix them with `as Dictionary<...>` annotations.
- **Round-screen safe area:** Vivoactive 5 is 390×390 round. Content in the outer ~15% gets clipped; TimelineView/LogView inset to 18–82% horizontal and vertical.
