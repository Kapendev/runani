module runani.app;

import popka;
import runani.game;

void ready() {
    lockResolution(gameWidth, gameHeight);
    setBackgroundColor(color4);
    setIsPixelPerfect(true);
    game.ready();
}

bool update(float dt) {
    if (game.update(dt)) return true;
    game.draw();
    return false;
}

void finish() {
    game.free();
}

mixin runGame!(ready, update, finish, 640, 576);
