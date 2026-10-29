import Toybox.Test;

(:test)
function testRowWidthRectangularIsWidthLessMargins(logger) {
    // 4 % margin each side, wherever the row is.
    return RowFit.availableWidth(200, 300, 30, 10, false) == 184
        && RowFit.availableWidth(200, 300, 150, 10, false) == 184;
}

(:test)
function testRowWidthRoundCentreIsFullChord(logger) {
    // Through the centre the chord is the diameter: 390 - 2 * 15.
    return RowFit.availableWidth(390, 390, 195, 0, true) == 360;
}

(:test)
function testRowWidthRoundNarrowsAwayFromCentre(logger) {
    var centre = RowFit.availableWidth(390, 390, 195, 12, true);
    var upper = RowFit.availableWidth(390, 390, 98, 12, true);
    var lower = RowFit.availableWidth(390, 390, 292, 12, true);
    // Symmetric about the centre, and the upper row is narrower.
    return upper < centre && upper == lower;
}

(:test)
function testRowWidthRoundUsesFartherTextEdge(logger) {
    // A taller line at the same y has its outer edge farther out, so less room.
    return RowFit.availableWidth(390, 390, 98, 20, true)
        < RowFit.availableWidth(390, 390, 98, 5, true);
}

(:test)
function testRowWidthRoundOffScreenIsZero(logger) {
    return RowFit.availableWidth(390, 390, 0, 10, true) == 0;
}
