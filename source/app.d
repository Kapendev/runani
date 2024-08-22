module runjam.app;

import popka;
import runjam.game;

bool gameLoop() {
    if (game.update()) return true;
    game.draw();
    return false;
}

void gameStart() {
    togglePixelPerfect();
    setBackgroundColor(color4);
    lockResolution(gameWidth, gameHeight);

    game.ready();
    updateWindow!gameLoop();
    game.free();
}

mixin callGameStart!(gameStart, 640, 576);
