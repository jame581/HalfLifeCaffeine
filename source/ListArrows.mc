import Toybox.Graphics;

// Scroll arrows for the log and history lists: a small triangle centred on
// cx, cy, pointing up or down. Drawn only while rows are hidden that way.
module ListArrows {

    function draw(dc, cx, cy, height, up) {
        var s = height * 2 / 100;
        if (s < 3) { s = 3; }
        dc.setColor(Colors.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        if (up) {
            dc.fillPolygon([[cx - s, cy + s / 2], [cx + s, cy + s / 2], [cx, cy - s / 2]]);
        } else {
            dc.fillPolygon([[cx - s, cy - s / 2], [cx + s, cy - s / 2], [cx, cy + s / 2]]);
        }
    }
}
