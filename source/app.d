module runani.app;

import parin;
import runani.game;

void ready() {
    setIsPixelPerfect(true);
    setIsPixelSnapped(true);
    lockResolution(gameWidth, gameHeight);
    setBackgroundColor(color4);
    setBorderColor(color4);
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
