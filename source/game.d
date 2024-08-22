module runjam.game;

// TODO: Change loadTileMap(path) to loadTileMap(path, tileWidth, tileHeight) because it feels broken if you don't know what is happening.
// TODO: Change drawTile function. The tileSize param should be split into tileWidth and tileHeight and should have type int.
// TODO: Maybe replace tileWidth and tileHeight with just tileSize that is an int.
// TODO: Try to make the Monogram Font to work. For some reason it is always blurry (and I hate pixel art).
// TODO: Add tick function.

// NOTE: My best score is 1043.

import popka;

Game game;

enum gameWidth = 160;
enum gameHeight = 144;
enum moveSpeed = 60;
enum tileSize = 16;

enum color0 = red.alpha(140);
enum color1 = toRgb(0x081820);
enum color2 = toRgb(0x346856);
enum color3 = toRgb(0x88c070);
enum color4 = toRgb(0xe0f8d0);

enum AnimalKind {
    mouse,
    dog,
    bird,
}

struct Player {
    Vec2 position;
    Vec2 prevPosition;
    Vec2 maxFlowerOffset;
    AnimalKind kind;

    float gravity = 0.0f;
    float frame = 0.0f;
    float flashTimer = flashWaitTime;
    float hitDelayTimer = hitDelayWaitTime;
    int flowerCount;
    bool isDead;
    bool flashState;

    enum flashWaitTime = 0.1f;
    enum hitDelayWaitTime = 1.25f;

    this(Vec2 position) {
        this.position = position;
        this.prevPosition = position;
    }

    Rect area() {
        auto result = Rect(position, Vec2(tileSize));
        result.subAll(5.0f);
        final switch (kind) {
            case AnimalKind.mouse: result.position += Vec2(1.0f, 3.0f); break;
            case AnimalKind.dog: result.position += Vec2(-1.0f, 2.0f); break;
            case AnimalKind.bird: result.position += Vec2(-1.0f, 1.0f); break;
        }
        if (result.rightPoint.x <= 0.0f || result.leftPoint.x >= gameWidth || isHitDelayTimerRunning) {
            return Rect(Vec2(-256.0f), Vec2());
        }
        return result;
    }

    bool isOnFloor() {
        return position.y == playerStartPosition.y;
    }

    bool hasTouchedFloor() {
        return isOnFloor && position.y > prevPosition.y;
    }

    bool hasLooped() {
        return position.x < prevPosition.x;
    }

    bool isHitDelayTimerRunning() {
        return hitDelayTimer < hitDelayWaitTime;
    }

    void startHitDelayTimer() {
        hitDelayTimer = 0.0f;
        flashTimer = 0.0f;
    }

    void randomizeKind() {
        kind = cast(AnimalKind) (randi % (AnimalKind.max + 1));
    }

    void update(float dt) {
        prevPosition = position;
        gravity += moveSpeed * 12.0f * dt;
        hitDelayTimer = clamp(hitDelayTimer + dt, 0.0f, hitDelayWaitTime);
        flashTimer = clamp(flashTimer + dt, 0.0f, flashWaitTime);
        if (isHitDelayTimerRunning) {
            if (flashTimer == flashWaitTime) {
                flashState = !flashState;
                flashTimer = 0.0f;
            }
        } else {
            flashTimer = flashWaitTime;
            flashState = false;
        }

        position.x = wrap(position.x + moveSpeed * dt, -tileSize, gameWidth + tileSize);

        if (gravity > 0.0f) {
            position.y = clamp(position.y + gravity * 0.625f * dt, 0.0f, playerStartPosition.y);
        } else {
            position.y = clamp(position.y + gravity * dt, 0.0f, playerStartPosition.y);
        }

        if (Keyboard.j.isPressed && (position.y >= playerStartPosition.y - 3.0f && position.y <= playerStartPosition.y)) {
            gravity = -moveSpeed * 2.75f;
            playAudio(game.jumpSound);
        }
        if (Keyboard.k.isPressed) {
            auto hasPicked = false;
            foreach (ref flower; game.flowers.items) {
                if (!area.hasIntersection(flower.area)) continue;
                if (flower.canFollowPlayer) continue;

                if (maxFlowerOffset.y == 0.0f) {
                    final switch (kind) {
                        case AnimalKind.mouse: maxFlowerOffset.y = -5; break;
                        case AnimalKind.dog: maxFlowerOffset.y = -13; break;
                        case AnimalKind.bird: maxFlowerOffset.y = -8; break;
                    }
                }
                flower.canFollowPlayer = true;
                flower.playerOffset = maxFlowerOffset;
                flowerCount += 1;
                maxFlowerOffset.y -= 12;
                game.flowerPointValues[flower.point] = false;
                hasPicked = true;
            }
            if (hasPicked) {
                playAudio(game.takeSound);
            }
        }
    
        if (isOnFloor) {
            if (hasTouchedFloor) {
                frame = 0.0f;
            } else {
                frame = wrap(frame + 6.0f * dt, 0.0f, 2.0f);
            }
        } else {
            frame = 1.0f;
        }

        if (hasLooped) {
            throwRocks();
        }
    }

    void draw() {
        auto options = DrawOptions();
        if (isHitDelayTimerRunning) {
            options.color = flashState ? blank : white;
        }
        drawAnimal(kind, position, cast(int) frame, options);
        if (game.isDebug) {
            drawRect(area, color0);
        }
    }
}

struct Flower {
    Vec2 position;
    Vec2 prevPosition;
    Vec2 targetPosition;
    Vec2 playerOffset;
    Flip flip;
    Sz point;
    bool canFollowPlayer;

    this(Vec2 position) {
        this.position = position + Vec2(0.0f, tileSize);
        this.targetPosition = position;
    }

    Rect area() {
        return Rect(position, Vec2(tileSize)).subAll(1.0f);
    }

    bool hasLooped() {
        return position.x < prevPosition.x;
    }

    void randomizeFlip() {
        flip = (randi % 2) ? Flip.x : Flip.none;
    }

    void update(float dt) {
        prevPosition = position;
        
        auto realTargetPosition = canFollowPlayer ? game.player.position : targetPosition;
        if (canFollowPlayer) {
            position = position.moveTo(realTargetPosition + playerOffset, Vec2(moveSpeed * 3.0f * dt));
        } else {
            position = position.moveTo(realTargetPosition, Vec2(moveSpeed * 2.0f * dt));
        }

        if (hasLooped && position.x > gameWidth) {
            position.x = realTargetPosition.x;
        }
    }

    void draw() {
        auto options = DrawOptions();
        options.flip = flip;

        auto texturePosition = position;
        texturePosition.y -= cast(int) game.player.frame == 1;

        drawTexture(game.atlas, texturePosition, Rect(Vec2(16.0f, 32.0f), Vec2(16.0f)), options);
        if (game.isDebug) {
            drawRect(area, color0);
        }
    }
}

struct Rock {
    Vec2 position;
    float startOffset = 0.0f;
    float frameRotation = 0.0f;

    this(float startOffset) {
        this.startOffset = startOffset;
        this.position = rockStartPosition + Vec2(startOffset, 0.0f);;
    }

    Rect area() {
        return Rect(position, Vec2(tileSize)).area(Hook.center).subAll(4.0f);
    }

    void randomizeStartFrameRotation() {
        frameRotation = (randi % 4);
    }

    void update(float dt) {
        frameRotation = wrap(frameRotation + 9.0f * dt, 0.0f, 4.0f);
        
        if (position.x > -tileSize) {
            position.x -= moveSpeed * 1.8f * dt;
        }
        if (game.player.hasLooped) {
            position = rockStartPosition + Vec2(startOffset, 0.0f);
        }

        if (area.hasIntersection(game.player.area)) {
            if (game.player.isDead) return;
            if (game.player.flowerCount == 0) {
                game.player.isDead = true;
                game.startFreezeTimer();
                game.player.startHitDelayTimer();
            } else {
                final switch (game.player.kind) {
                    case AnimalKind.mouse: game.player.maxFlowerOffset.y = -5; break;
                    case AnimalKind.dog: game.player.maxFlowerOffset.y = -13; break;
                    case AnimalKind.bird: game.player.maxFlowerOffset.y = -8; break;
                }
                game.startFreezeTimer();
                game.player.startHitDelayTimer();
                game.player.flowerCount = 0;
            }
            playAudio(game.deathSound);
        }
    }

    void draw() {
        auto options = DrawOptions();
        options.hook = Hook.center;
        options.rotation = floor(frameRotation) * -90.0f;
        auto texturePosition = position;
        texturePosition.y -= (cast(int) frameRotation == 1 || cast(int) frameRotation == 3);
        drawTexture(game.atlas, texturePosition, Rect(Vec2(0.0f, 32.0f), Vec2(16.0f)), options);
        if (game.isDebug) {
            drawRect(area, color0);
        }
    }
}

struct Game {
    Font font;
    Texture atlas;
    Audio backgroundMusic;
    Audio jumpSound;
    Audio takeSound;
    Audio deathSound;
    TileMap groundMap;
    TileMap skyMap;

    Player player;
    List!Rock rocks;
    FlagList!Flower flowers;

    bool[10] flowerPointValues;
    int score;
    int scoreTrigger = dfltScoreTrigger;
    float timeRate = 1.0f;
    float freezeTimer = freezeWaitTime;
    float startScreenOffset = 0.0f;
    bool isDebug;
    bool isPlaying;

    enum dfltScoreTrigger = 30;
    enum freezeWaitTime = 0.2f;

    bool isFreezeTimerRunning() {
        return freezeTimer < freezeWaitTime;
    }

    void startFreezeTimer() {
        freezeTimer = 0.0f;
    }

    void ready() {
        player = Player(playerStartPosition);
        player.randomizeKind();
        appendFlowers(true);

        atlas = loadTexture("sprites/atlas.png").unwrap();

        backgroundMusic = loadAudio("audio/debussy_arabesque_no_1_l_66.mp3").unwrap();
        backgroundMusic.setPitch(1.0f);
        backgroundMusic.setVolume(0.6f);
        jumpSound = loadAudio("audio/jump.wav").unwrap();
        jumpSound.setPitch(1.1f);
        jumpSound.setVolume(0.28f);
        takeSound = loadAudio("audio/take.wav").unwrap();
        takeSound.setPitch(1.0f);
        takeSound.setVolume(0.25f);
        deathSound = loadAudio("audio/death.wav").unwrap();
        deathSound.setPitch(2.0f);
        deathSound.setVolume(0.1f);
        
        font = loadFont("fonts/pixeloid.ttf", 11).unwrap();
        font.runeSpacing = 1;
        font.lineSpacing = 14;

        groundMap = loadTileMap("maps/ground.csv").unwrap();
        groundMap.tileWidth = tileSize;
        groundMap.tileHeight = tileSize;

        skyMap = loadTileMap("maps/sky.csv").unwrap();
        skyMap.tileWidth = tileSize;
        skyMap.tileHeight = tileSize;

        playAudio(game.backgroundMusic);
    }

    bool update() {
        // Define some basic keys for doing basic stuff.
        debug {
            if (Keyboard.esc.isPressed) return true;
        }
        version(WebAssembly) {
            // Nothing lol.
        } else {
            if (Keyboard.f11.isPressed) toggleFullscreen();
        }
        if (Keyboard.n1.isPressed) reload();
        if (Keyboard.n2.isPressed) isDebug = !isDebug;
        if (Keyboard.n3.isPressed) toggleResolution(gameWidth, gameHeight);

        // Define some basic variables that are needed everywhere.
        auto dt = deltaTime * timeRate;
        auto prevTimeRate = timeRate;

        // Update audio.
        updateAudio(backgroundMusic);

        if (isPlaying) {
            // Return to start screen if player is dead.
            if (player.isDead) {
                if ((Keyboard.j.isPressed || Keyboard.k.isPressed) && (freezeTimer == freezeWaitTime)) {
                    reload();
                    isPlaying = false;
                    return false;
                }
            }

            // Freeze timer code. Stupid, but it works.
            freezeTimer = clamp(freezeTimer + deltaTime, 0.0f, freezeWaitTime);
            if (isFreezeTimerRunning) {
                timeRate = 0.0f;
            } else if (timeRate == 0.0f) {
                if (player.isDead) {
                    timeRate = 0.2f;
                } else {
                    timeRate = 1.0f;
                }
            }
            // Remove flowers when the freeze effect has ended. This should not be here, but works.
            if (timeRate > prevTimeRate) {
                foreach (id; flowers.ids) {
                    auto flower = &flowers[id];
                    if (flower.canFollowPlayer) {
                        flowers.remove(id);
                    }
                }
            }

            // Update the world.
            player.update(dt);
            foreach (ref rock; rocks) {
                rock.update(dt);
            }
            foreach (ref flower; flowers.items) {
                flower.update(dt);
            }

            // Update the score and add new flowers when needed.
            if (player.hasLooped && !player.isDead) {
                score += player.flowerCount + 1;
            }
            if (score >= scoreTrigger) {
                appendFlowers();
                scoreTrigger += dfltScoreTrigger;
            }
            return false;
        } else {
            if (Keyboard.j.isPressed || Keyboard.k.isPressed) {
                if (startScreenOffset == 0.0f) startScreenOffset = 0.001f;
            }
            if (startScreenOffset != 0) {
                startScreenOffset = startScreenOffset.moveTo(cast(float) -gameHeight, moveSpeed * 3.0f * deltaTime);
            }
            if (startScreenOffset == -gameHeight) {
                startScreenOffset = 0.0f;
                isPlaying = true;
            }
            return false;
        }
    }

    void draw() {
        import ray = popka.ray; // Cringe. Will change it one day.

        if (isPlaying) {
            auto textOptions = DrawOptions();
            textOptions.hook = Hook.center;
            textOptions.color = color3;

            // Draw the world.
            drawTileMap(atlas, Vec2(), skyMap, Camera());
            foreach (flower; flowers.items) {
                if (!flower.canFollowPlayer) flower.draw();
            }
            foreach (flower; flowers.items) {
                if (flower.canFollowPlayer) flower.draw();
            }
            player.draw();
            foreach (rock; rocks) {
                rock.draw();
            }
            drawTileMap(atlas, Vec2(), groundMap, Camera());

            // Draw the game info.
            auto scoreTextOffset = sin(ray.GetTime() * 5.0f) * 2.0f;
            drawText(font, Vec2(gameWidth * 0.5f, 26.0f + scoreTextOffset), "{}".format(score), textOptions);
            if (player.isDead) {
                drawText(font, Vec2(gameWidth * 0.5f, gameHeight * 0.5f + 4.0f), "Oh no!", textOptions);
            }
        } else {
            auto textOptions = DrawOptions();
            textOptions.hook = Hook.center;
            textOptions.color = color3;

            auto rect1 = Rect(gameWidth, gameHeight).subAll(2.0f);
            auto rect2 = Rect(gameWidth, gameHeight).subAll(4.0f);
            rect1.position.y += startScreenOffset;
            rect2.position.y += startScreenOffset;

            drawRect(rect1, color3);
            drawRect(rect2, color4);
            drawText(font, Vec2(gameWidth * 0.5f, gameHeight * 0.5f + startScreenOffset), "|  Runani  |", textOptions);
            drawText(font, Vec2(gameWidth * 0.5f, gameHeight * 0.9f + startScreenOffset), "(J) Jump (K) Take", textOptions);
            drawAnimal(player.kind, Vec2(gameWidth * 0.5f + 1.0f, gameHeight * 0.5f - 19.0f + startScreenOffset), 0);

            drawTileMap(atlas, Vec2(0.0f, gameHeight + startScreenOffset), groundMap, Camera());
            drawTileMap(atlas, Vec2(0.0f, gameHeight + startScreenOffset), skyMap, Camera());
        }
    }

    void free() {
        rocks.free();
        flowers.free();
        backgroundMusic.free();
        jumpSound.free();
        takeSound.free();
        deathSound.free();
        font.free();
        atlas.free();
        groundMap.free();
        skyMap.free();
        this = Game();
    }

    void reload() {
        score = 0;
        scoreTrigger = dfltScoreTrigger;
        timeRate = 1.0f;
        player = Player(playerStartPosition);
        player.randomizeKind();

        foreach (ref point; flowerPointValues) {
            point = false;
        }
        flowers.clear();
        appendFlowers(true);

        rocks.clear();
    }
}

Vec2 playerStartPosition() {
    return Vec2(-tileSize, tileSize * 6);
}

Vec2 rockStartPosition() {
    return Vec2(gameWidth + tileSize * 0.5f, tileSize * 6 + tileSize * 0.5f);
}

void appendFlowers(bool isForcedToBeThree = false) {
    // Don't add something if there is something there.
    auto count = isForcedToBeThree ? 3 : (randi % 3 + 1);
    foreach (value; game.flowerPointValues) {
        if (count == 0) return;
        count -= value;
    }

    foreach (i; 0 .. count) {
        // Super stupid way of placing a flower, but it works because there will be at most 3 flowers on the screen.
        auto point = cast(Sz) (randf * (game.flowerPointValues.length - 1));
        while (game.flowerPointValues[point]) {
            point = cast(Sz) (randf * (game.flowerPointValues.length - 1));
        }

        auto flower = Flower(Vec2(tileSize * point, tileSize * 6));
        flower.point = point;
        flower.randomizeFlip();

        game.flowerPointValues[point] = true;
        game.flowers.append(flower);
    }
}

void appendRock(float startOffset) {
    auto rock = Rock(startOffset);
    rock.randomizeStartFrameRotation();
    game.rocks.append(rock);
}

void throwRocks() {
    // This could be global, but I don't really care about it and it is a jam game.
    // Example: [2][3] = Second rock group and third rock start offset.
    enum none = -1.0f;

    static float[3][8] config = [
        [tileSize * 1.0f, none, none],
        [tileSize * 5.0f, none, none],
        [tileSize * 9.0f, none, none],
        [tileSize * 1.0f, tileSize * 7.0f, none],
        [tileSize * 0.0f, tileSize * 5.0f, tileSize * 6.0f],
        [tileSize * 1.0f, tileSize * 2.0f, tileSize * 7.0f],
        [tileSize * 0.0f, tileSize * 2.0f, tileSize * 6.0f],
        [tileSize * 0.0f, tileSize * 1.0f, tileSize * 2.0f],
    ];

    game.rocks.clear();
    auto group = randi % config.length;
    foreach (offset; config[group]) {
        if (offset == none) continue;
        appendRock(offset);
    }
}

void drawAnimal(AnimalKind kind, Vec2 position, int frame, DrawOptions options = DrawOptions()) {
    drawTile(game.atlas, position, (frame == 0) ? (kind) : (kind + (frame * 16)), Vec2(tileSize), options);
}
