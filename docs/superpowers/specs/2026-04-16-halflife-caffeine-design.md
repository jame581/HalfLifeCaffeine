# HalfLife Caffeine — Design Spec

**Date:** 2026-04-16
**Status:** Approved
**Platform:** Garmin Connect IQ
**Architecture:** Widget + Web-Based Companion (Approach B)
**Pricing:** Free
**Store Category:** Health & Fitness

---

## Overview

HalfLife Caffeine is a free Garmin watch widget that tracks caffeine intake, models caffeine decay in the bloodstream using a pharmacokinetic half-life model, and helps users understand when caffeine will stop affecting their sleep. It supports any caffeinated drink (coffee, tea, energy drinks, soda, chocolate, supplements) via configurable presets.

The watch widget handles real-time tracking and drink logging. A web-based companion page inside the Garmin Connect app provides settings management, history, and trend charts.

---

## 1. Watch Widget

### 1.1 Glance View

The glance is the small preview visible in the widget loop without tapping.

- Current caffeine level in mg (e.g. "142 mg")
- Coffee cup icon
- One-line status: "Safe to sleep in 3h 20m" or "Clear"

### 1.2 Full Widget — Screen 1: Summary

The main screen shown when the user taps into the widget.

- Current caffeine level — large number with unit (mg)
- Progress bar showing decay toward zero
- Time until sleep-safe (projected time to drop below 50mg threshold)
- Daily intake vs. limit (e.g. "280 / 400 mg")
- Warning indicator if over limit (yellow at 80%, red at 100%)

### 1.3 Full Widget — Screen 2: Timeline Graph

Scrolled to from the summary screen.

- Line graph showing projected caffeine decay over the next 8 hours
- Bedtime marker (vertical line on the graph)
- Sleep-safe threshold line at 50mg
- Current time indicator

### 1.4 Full Widget — Screen 3: Today's Log

Scrolled to from the timeline screen.

- Scrollable list of all drinks logged today
- Each entry shows: time, drink name, caffeine amount
- Example: "09:15 — Espresso (63mg)"

### 1.5 Adding a Drink

- Triggered by pressing the action button (or menu) from any widget screen
- Shows a scrollable list of drink presets
- User selects a preset → short vibration confirms → returns to summary with recalculated numbers
- No manual mg entry on watch — custom drinks are managed from the phone

---

## 2. Caffeine Pharmacokinetic Model

### 2.1 Half-Life Decay

- Fixed half-life: **5.7 hours** (established average for healthy adults)
- Formula: `current_mg = dose_mg * (0.5 ^ (hours_elapsed / 5.7))`
- Each drink dose is tracked independently
- Total caffeine = sum of all active doses
- Doses decayed below 1mg are discarded

### 2.2 Sleep Safety

- Sleep-safe threshold: **50mg** (below this, caffeine has minimal impact on sleep)
- Time-to-safe is calculated by projecting the total decay curve forward until it crosses 50mg
- Bedtime source: Garmin's sleep schedule data if available, otherwise user-configured manual bedtime

### 2.3 Daily Limit

- Default: **400mg** (FDA guideline for healthy adults)
- User-configurable via phone settings
- Resets at midnight local time

---

## 3. Alerts & Notifications

### 3.1 Daily Limit Alerts

- **Warning at 80%** of daily limit (default 320mg): gentle vibration + yellow indicator on summary screen
- **Alert at 100%** of daily limit (default 400mg): stronger vibration + red indicator on summary screen
- Each threshold fires only once per day (not repeated)

### 3.2 Safe-to-Sleep Notification

- When caffeine drops below 50mg AND it's within 2 hours of bedtime
- Single notification: "Caffeine cleared — safe to sleep"
- Fires once per evening

### 3.3 Notification Settings

- All notifications can be toggled on/off individually from phone settings
- Defaults: all enabled

---

## 4. Data Storage

### 4.1 On-Watch Storage

- Uses Connect IQ `Application.Storage`
- Each drink log entry stores: timestamp (epoch), caffeine mg (integer), drink preset ID (~40 bytes per entry)
- Retains **14 days** of history (well within the ~64KB storage limit)
- Active doses (not yet decayed below 1mg) kept in a separate array for fast real-time calculations
- Drink presets stored as a list synced from phone settings

### 4.2 Data Cleanup

- Entries older than 14 days are purged on each app wake
- Decayed doses (below 1mg) removed from the active array on each calculation cycle

---

## 5. Watch-to-Phone Sync

### 5.1 Sync Mechanism

- Uses Connect IQ Communications API (built into the SDK, no extra pairing)
- Incremental sync: only new entries since last sync are transmitted

### 5.2 Sync Triggers

- After each drink is logged
- Once per hour in background (when widget is in the widget loop)

### 5.3 Data Flow

```
Watch logs drink
  → saves to Application.Storage
  → recalculates caffeine levels
  → updates widget display
  → Communications API sends new entries to phone
      → Garmin Connect app receives data
      → Web Settings page stores in localStorage
      → History/charts update on next page open
```

### 5.4 Settings Sync (Phone → Watch)

- Drink presets, daily limit, bedtime override, notification toggles
- Pushed to watch when user saves settings in the Garmin Connect app
- Watch picks up new settings on next sync cycle

---

## 6. Phone Companion (Web Settings Page)

Runs as an HTML/CSS/JS page inside the Garmin Connect mobile app. No separate app installation required.

### 6.1 Settings Tab

- **Drink Presets**: add, edit, remove, reorder. Each preset has: name, caffeine amount (mg), icon/color
- **Daily Limit**: number input with slider, default 400mg
- **Bedtime**: time picker, with option to use Garmin sleep schedule
- **Notifications**: individual toggles for limit warning, limit reached, safe to sleep

### 6.2 History Tab

- **Daily log**: expandable list of each day's drinks with times and amounts
- **Daily total bar**: visual bar showing intake vs. limit for each day
- **Calendar view**: color-coded days — green (under limit), yellow (near limit), red (over limit)

### 6.3 Trends Tab

- **Weekly/Monthly average**: daily caffeine intake
- **Line chart**: daily caffeine totals over time
- **Peak hours**: visualization of when the user typically consumes the most caffeine
- **Days over limit**: count and percentage

---

## 7. Default Drink Presets

Shipped with the app. Users can modify via phone settings.

| Drink | Caffeine (mg) |
|---|---|
| Espresso | 63 |
| Drip Coffee (small) | 95 |
| Drip Coffee (large) | 190 |
| Latte | 63 |
| Green Tea | 30 |
| Black Tea | 47 |
| Red Bull (250ml) | 80 |
| Monster (500ml) | 160 |
| Cola (330ml) | 34 |
| Dark Chocolate (50g) | 25 |
| Pre-Workout Supplement | 200 |

---

## 8. Device Support

### 8.1 Target API Level

- **Connect IQ API Level 3.2+** (required for glance view support)

### 8.2 Supported Device Families

- Vivoactive 4, Vivoactive 5
- Venu 2, Venu 2 Plus, Venu 3, Venu 3S
- Forerunner 255, 265, 955, 965
- Fenix 6, 7, 8 series
- Epix series

### 8.3 Screen Adaptation

- Uses Connect IQ's layout system to adapt to different screen sizes and shapes (round vs. rectangular, varying resolutions)
- Primary development and testing on Vivoactive 5

---

## 9. Store Publishing

- **App Name:** HalfLife Caffeine
- **Category:** Health & Fitness
- **Price:** Free
- **Language:** English (primary), localization support via string resources for future languages
- **Required Assets:** app icon (256x256), screenshots from simulator, store description
- **Review:** Garmin reviews submissions, typically a few days turnaround

---

## 10. Technology Stack

- **Watch App:** Monkey C (Connect IQ SDK)
- **Phone Companion:** HTML / CSS / JavaScript (Connect IQ Web Settings)
- **Data Sync:** Connect IQ Communications API
- **Development Environment:** Visual Studio Code + Connect IQ SDK plugin
- **Testing:** Connect IQ Simulator + physical Vivoactive 5
