import Toybox.Application;

(:glance)
module Colors {
    // Theme-dependent background (set by applyTheme; default = Navy)
    var BG = 0x1A2332;       // Dark navy background

    // Fixed palette — reads acceptably on both Navy and Black backgrounds
    const ACCENT = 0x3DDBA8; // Vibrant teal-green (caffeine / safe)

    // Text hierarchy
    const TEXT_PRIMARY = 0xFFFFFF;   // Large numbers, active state
    const TEXT_SECONDARY = 0xAAAAAA; // Labels, captions
    const TEXT_DIM = 0x555555;       // Hints, inactive

    // Alert states
    const WARNING = 0xFFAA00;        // Amber — 80% of limit
    const DANGER = 0xE74C3C;         // Red — over limit

    // Structural — theme-dependent (set by applyTheme)
    var TRACK = 0x2A3548;            // Progress bar background
    var AXIS = 0x3D4A60;             // Graph axes
    const BEDTIME = 0x5B8BD6;        // Bedtime marker

    // Apply the user-selected background theme to the mutable color vars.
    // Reads the `theme` number property: 0 = Navy (default), 1 = Black.
    // Safe to call from both the glance and full-view processes; call before drawing.
    function applyTheme() {
        var theme = Application.Properties.getValue("theme");
        if (theme == null) { theme = 0; }
        if (theme == 1) {
            // Black — better contrast on MIP displays, better battery on AMOLED
            BG = 0x000000;
            TRACK = 0x1C1C1C;
            AXIS = 0x333333;
        } else {
            // Navy (default)
            BG = 0x1A2332;
            TRACK = 0x2A3548;
            AXIS = 0x3D4A60;
        }
    }
}
