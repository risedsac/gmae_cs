/* oxlint-disable typescript/no-explicit-any -- The DOM-free harness intentionally supplies partial runtime fixtures. */
import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { DesertGame, spawnPoints } from '../lib/game';
import { makeBot } from '../lib/bot';
import { createBrain, rememberSound, seesDirection } from '../lib/ai';
import { makeWeapon, installWeaponModel } from '../lib/weapon';
import { MAP_SOLIDS, canOccupy } from '../lib/world';
function harness() {
  const g: any = Object.create(DesertGame.prototype);
  Object.assign(g, {
    state: {
      time: 120,
      hurt: 0,
      hit: 0,
      phase: 'playing',
      weapon: 0,
      health: 100,
      armor: 100,
      dead: false,
      reloading: false,
      shots: 0,
      hits: 0,
      kills: 0,
      headshots: 0,
      deaths: 0,
      feed: [],
    },
    inventory: [
      { ammo: 30, reserve: 90 },
      { ammo: 12, reserve: 48 },
    ],
    position: new THREE.Vector3(0, 0, 23),
    velocity: new THREE.Vector3(),
    camera: new THREE.PerspectiveCamera(72, 1, 0.06, 120),
    scene: new THREE.Scene(),
    world: { targets: [], solids: MAP_SOLIDS },
    ray: new THREE.Raycaster(),
    bots: [],
    effects: [],
    decals: [],
    fireClock: 0,
    switchClock: 0,
    kick: 0,
    burst: 0,
    inspectClock: 0,
    recoilPitch: 0,
    recoilYaw: 0,
    onGround: true,
    protection: 0,
    difficulty: 1,
    elapsed: 0,
    eye: 1.65,
    yaw: 0,
    feedID: 0,
    triggerClock: 0,
    muzzleClock: 0,
    hitClock: 0,
    feedClock: 0,
    keys: new Set(),
    firing: false,
    pressed: false,
    dragging: false,
    capturePending: false,
    dragMode: false,
    lookPointer: null,
    shellGeometry: new THREE.CylinderGeometry(0.01, 0.01, 0.04),
    shellMaterial: new THREE.MeshBasicMaterial(),
    decalGeometry: new THREE.CircleGeometry(0.04),
    decalMaterial: new THREE.MeshBasicMaterial(),
    audio: {
      shot() {},
      impact() {},
      hurt() {},
      mechanical() {},
      pause() {},
      init() {},
    },
    emit() {},
    tracer() {},
    impact() {},
    updateCamera() {},
    movePlayer() {},
  });
  g.camera.position.set(0, 1.65, 0);
  g.camera.updateMatrixWorld();
  return g;
}
void test('map keeps spawn points and arch open, blocks walls, supports crouch clearance', () => {
  assert.equal(canOccupy(0, 23, 0, 1.8, MAP_SOLIDS), true);
  assert.equal(canOccupy(2.5, -18, 0, 1.8, MAP_SOLIDS), true);
  assert.equal(canOccupy(-7.5, -1, 0, 1.8, MAP_SOLIDS), false);
  assert.equal(canOccupy(5, 13, 0, 1.8, MAP_SOLIDS), false);
  const overhang = [{ x: 0, z: 0, w: 3, d: 3, h: 1, y: 1.2 }];
  assert.equal(canOccupy(0, 0, 0, 1.02, overhang), true);
  assert.equal(canOccupy(0, 0, 0, 1.8, overhang), false);
});
void test('bot navigation reaches player through connected free cells', () => {
  const g = harness();
  g.nav = new Uint8Array(49 * 65);
  for (let z = 0; z < 65; z++)
    for (let x = 0; x < 49; x++)
      g.nav[z * 49 + x] = canOccupy(x - 24, z - 32, 0, 1.8, MAP_SOLIDS, 0.43)
        ? 1
        : 0;
  for (const [x, z] of [
    [1, -11],
    [11, 2],
    [-1, 5],
    [17, -24],
  ]) {
    const path = g.findPath(
      new THREE.Vector3(x, 0, z),
      new THREE.Vector3(0, 0, 23),
    );
    assert.ok(path.length > 0, `route from ${x},${z}`);
    assert.ok(
      path.every((p: any) => canOccupy(p.x, p.z, 0, 1.8, MAP_SOLIDS, 0.43)),
    );
    assert.equal(path.at(-1).z, 23);
  }
});
void test('reload conserves rounds, partial reserve works, and shooting is blocked during reload', () => {
  const g = harness();
  g.inventory[0] = { ammo: 7, reserve: 10 };
  g.reload();
  assert.equal(g.state.reloading, true);
  g.shoot();
  assert.equal(g.inventory[0].ammo, 7);
  g.updateReload(2.4);
  assert.equal(g.state.reloading, false);
  assert.deepEqual(g.inventory[0], { ammo: 17, reserve: 0 });
  g.reload();
  assert.equal(g.state.reloading, false);
});
void test('raycast stops at cover; unobstructed head hit kills and consumes one round', () => {
  const g = harness();
  const head = new THREE.Mesh(
    new THREE.SphereGeometry(0.3),
    new THREE.MeshBasicMaterial(),
  );
  head.position.set(0, 1.65, -10);
  head.userData = { bot: 0, part: 'head' };
  const root = new THREE.Group();
  root.add(head);
  g.scene.add(root);
  const bot = {
    hp: 100,
    dead: 0,
    root,
    light: { intensity: 0 },
    hitboxes: [head],
    name: 'test',
    brain: createBrain(0),
    reaction: 0.5,
  };
  g.bots = [bot];
  const wall = new THREE.Mesh(
    new THREE.BoxGeometry(5, 5, 1),
    new THREE.MeshBasicMaterial(),
  );
  wall.position.set(0, 2, -5);
  g.scene.add(wall);
  g.world.targets = [wall];
  g.shoot();
  assert.equal(g.inventory[0].ammo, 29);
  assert.equal(bot.hp, 100);
  assert.equal(g.state.hits, 0);
  g.world.targets = [];
  g.shoot();
  assert.equal(g.inventory[0].ammo, 28);
  assert.equal(g.state.hits, 1);
  assert.equal(g.state.kills, 1);
  assert.equal(g.state.headshots, 1);
  assert.equal(bot.hp, 0);
});
void test('armor absorbs damage, spawn protection prevents it, and lethal damage causes one death', () => {
  const g = harness();
  g.protection = 1;
  g.damagePlayer(100, 'enemy');
  assert.equal(g.state.health, 100);
  g.protection = 0;
  g.damagePlayer(10, 'enemy');
  assert.equal(g.state.armor, 96);
  assert.equal(g.state.health, 94);
  g.damagePlayer(250, 'enemy');
  assert.equal(g.state.dead, true);
  assert.equal(g.state.health, 0);
  assert.equal(g.state.deaths, 1);
  g.damagePlayer(10, 'enemy');
  assert.equal(g.state.deaths, 1);
});

import { readFileSync } from 'node:fs';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { createActor } from '../lib/actor';

async function loadGeometryOnlySoldier(file = 'soldier') {
  // Preserve the actual skeleton, vertex buffers and animations. Texture decoding
  // is browser-only and irrelevant to the character scale regression.
  const input = readFileSync(`public/assets/${file}.glb`);
  const jsonLength = input.readUInt32LE(12);
  const gltf = JSON.parse(input.subarray(20, 20 + jsonLength).toString());
  gltf.materials = gltf.materials.map(() => ({
    pbrMetallicRoughness: { baseColorFactor: [0.5, 0.5, 0.5, 1] },
  }));
  delete gltf.textures;
  delete gltf.images;
  delete gltf.samplers;
  const json = Buffer.from(JSON.stringify(gltf));
  const padded = Buffer.alloc(Math.ceil(json.length / 4) * 4, 0x20);
  json.copy(padded);
  const binStart = 20 + jsonLength;
  const binary = input.subarray(binStart);
  const output = Buffer.alloc(20 + padded.length + binary.length);
  output.write('glTF');
  output.writeUInt32LE(2, 4);
  output.writeUInt32LE(output.length, 8);
  output.writeUInt32LE(padded.length, 12);
  output.writeUInt32LE(0x4e4f534a, 16);
  padded.copy(output, 20);
  binary.copy(output, 20 + padded.length);
  return new GLTFLoader().parseAsync(
    output.buffer.slice(output.byteOffset, output.byteOffset + output.length),
    '',
  );
}

void test('actual Blender operator stays human-sized in every animation and follows the head hit volume', async () => {
  const source = await loadGeometryOnlySoldier('operator');
  const prepared = createActor(source.scene, source.animations);
  const root = new THREE.Group();
  root.add(prepared.wrapper);
  assert.ok(
    prepared.height > 1.5 && prepared.height < 2.3,
    `evaluated bind height ${prepared.height}`,
  );
  for (const [name, action] of Object.entries(prepared.actions)) {
    prepared.mixer.stopAllAction();
    action.reset().play();
    prepared.mixer.update(0.3);
    prepared.pose();
    root.updateMatrixWorld(true);
    prepared.actor.traverse((o) => {
      if (o instanceof THREE.SkinnedMesh) o.skeleton.update();
    });
    const size = new THREE.Box3()
      .setFromObject(prepared.wrapper, true)
      .getSize(new THREE.Vector3());
    assert.ok(size.y > 1.55 && size.y < 2.2, `${name} height ${size.y}`);
    assert.ok(
      size.x < 1.8 && size.z < 1.6,
      `${name} sane width/depth ${size.toArray().join(',')}`,
    );
    const head = prepared.headBone!.getWorldPosition(new THREE.Vector3());
    assert.ok(head.y > 1.25 && head.y < 1.85, `${name} head ${head.y}`);
  }
});

void test('rejected pointer lock leaves training frozen until a control mode is chosen', async () => {
  const g = harness();
  g.state.phase = 'paused';
  g.last = 0;
  g.canvas = {
    requestPointerLock: () => Promise.reject(new Error('unsupported')),
  };
  g.start();
  await Promise.resolve();
  assert.equal(g.state.phase, 'ready');
  assert.equal(g.state.time, 120);
  assert.equal(g.capturePending, false);
  g.setFire(true);
  g.setKey('KeyW', true);
  assert.equal(g.firing, false);
  assert.equal(g.keys.size, 0);
  g.startDragMode();
  assert.equal(g.state.phase, 'playing');
  assert.equal(g.dragMode, true);
});

void test('a quick click between frames fires once; a held pistol never becomes automatic', () => {
  const g = harness();
  g.state.weapon = 1;
  g.setFire(true);
  g.setFire(false);
  g.update(1 / 60);
  assert.equal(g.inventory[1].ammo, 11);
  assert.equal(g.state.shots, 1);
  g.setFire(true);
  g.update(0.12);
  g.update(0.1);
  assert.equal(g.inventory[1].ammo, 11);
  g.setFire(false);
  g.setFire(true);
  g.update(1 / 60);
  assert.equal(g.inventory[1].ammo, 10);
  g.update(0.4);
  assert.equal(g.inventory[1].ammo, 10);
});

void test('timer follows elapsed time at 20 FPS and movement uses bounded simulation steps', () => {
  const g = harness();
  Object.assign(g, {
    disposed: false,
    last: 1000,
    elapsed: 0,
    frames: 0,
    fpsTime: 0,
    hudTime: 0,
    renderer: { clear() {}, render() {}, clearDepth() {} },
    animateWeapon() {},
    drawRadar() {},
    publish() {},
  });
  let maxStep = 0;
  g.update = (dt: number) => {
    maxStep = Math.max(maxStep, dt);
    g.state.time -= dt;
  };
  for (let i = 1; i <= 20; i++) g.advanceFrame(1000 + i * 50);
  assert.ok(Math.abs(g.state.time - 119) < 1e-7);
  assert.ok(maxStep <= 1 / 60 + 1e-9);
  assert.equal(g.state.fps, 20);
});

void test('changing weapons during reload never duplicates ammunition or leaves a muzzle flash', () => {
  const g = harness();
  g.weapons = [{ root: { visible: true } }, { root: { visible: false } }];
  g.inventory[0].ammo = 20;
  g.reload();
  g.updateReload(1);
  g.muzzleClock = 0.04;
  g.switchWeapon(1);
  assert.equal(g.state.reloading, false);
  assert.equal(g.state.reloadProgress, 0);
  assert.equal(g.muzzleClock, 0);
  assert.equal(g.inventory[0].ammo, 20);
  assert.equal(g.inventory[0].reserve, 90);
  g.switchWeapon(0);
  assert.equal(g.weapons[0].root.visible, true);
  assert.equal(g.weapons[1].root.visible, false);
});

void test('living actors cannot pass through or stack inside each other', () => {
  const g = harness();
  const bot = { hp: 100, root: { position: new THREE.Vector3(1, 0, 23) } };
  g.bots = [bot];
  assert.equal(g.canMoveTo(0.8, 23, 0, 1.8), false);
  assert.equal(g.canMoveTo(-1, 23, 0, 1.8), true);
  assert.equal(g.canMoveTo(0.2, 23, 0, 1.8, bot), false);
  bot.hp = 0;
  assert.equal(g.canMoveTo(0.8, 23, 0, 1.8), true);
});

void test('every spawn is outside cover and all four bots can leave their initial positions', () => {
  const g = harness();
  g.world.solids = MAP_SOLIDS;
  for (const [x, z] of spawnPoints)
    assert.equal(
      canOccupy(x, z, 0, 1.8, MAP_SOLIDS, 0.43),
      true,
      `blocked spawn ${x},${z}`,
    );
  for (const s of MAP_SOLIDS) {
    const mesh = new THREE.Mesh(
      new THREE.BoxGeometry(s.w, s.h, s.d),
      new THREE.MeshBasicMaterial(),
    );
    mesh.position.set(s.x, s.y + s.h / 2, s.z);
    g.scene.add(mesh);
    g.world.targets.push(mesh);
  }
  g.camera.position.set(0, 1.65, 23);
  g.camera.updateMatrixWorld();
  g.difficulty = 1;
  g.elapsed = 0;
  g.botShoot = (bot: any) => {
    bot.shot = 0.7;
  };
  g.nav = new Uint8Array(49 * 65);
  for (let z = 0; z < 65; z++)
    for (let x = 0; x < 49; x++)
      g.nav[z * 49 + x] = canOccupy(x - 24, z - 32, 0, 1.8, MAP_SOLIDS, 0.43)
        ? 1
        : 0;
  g.bots = Array.from({ length: 4 }, (_, i) => {
    const b = makeBot(i);
    const p = spawnPoints[i + 3];
    b.root.position.set(p[0], 0, p[1]);
    g.scene.add(b.root);
    return b;
  });
  const starts = g.bots.map((b: any) => b.root.position.clone());
  const excursion = [0, 0, 0, 0];
  g.scene.updateMatrixWorld(true);
  for (let frame = 0; frame < 600; frame++) {
    g.elapsed += 1 / 60;
    for (const b of g.bots) {
      g.updateBot(b, 1 / 60);
      excursion[b.brain.id] = Math.max(
        excursion[b.brain.id],
        b.root.position.distanceTo(starts[b.brain.id]),
      );
      assert.equal(
        canOccupy(
          b.root.position.x,
          b.root.position.z,
          0,
          1.8,
          MAP_SOLIDS,
          0.32,
        ),
        true,
        `${b.name} entered a wall`,
      );
    }
  }
  g.bots.forEach((b: any, i: number) =>
    assert.ok(excursion[i] > 1, `${b.name} stuck at spawn`),
  );
});

void test('Blender assets contain independently animated magazines, support hands and bolts at view-model scale', async () => {
  for (const [i, file] of ['rifle', 'sidearm'].entries()) {
    const source = await loadGeometryOnlySoldier(file);
    const weapon = makeWeapon(!!i);
    installWeaponModel(weapon, source.scene);
    assert.equal(weapon.modeled, true);
    assert.notEqual(weapon.magazine, weapon.leftHand);
    assert.ok(weapon.bolt.parent);
    source.scene.updateMatrixWorld(true);
    const bounds = new THREE.Box3().setFromObject(source.scene);
    const size = bounds.getSize(new THREE.Vector3());
    assert.ok(size.z > 0.8 && size.z < 1.9, `${file} length ${size.z}`);
    assert.ok(
      size.x < 1.05 && size.y < 0.9,
      `${file} size ${size.toArray().join(',')}`,
    );
    const rest = weapon.bolt.getWorldPosition(new THREE.Vector3());
    weapon.magazine.position.y = -0.5;
    source.scene.updateMatrixWorld(true);
    assert.ok(
      rest.distanceTo(weapon.bolt.getWorldPosition(new THREE.Vector3())) < 1e-6,
    );
  }
});
void test('perception has a field of view; hearing stores an immutable location instead of tracking through walls', () => {
  const origin = new THREE.Vector3();
  assert.equal(seesDirection(0, origin, new THREE.Vector3(0, 0, 10)), true);
  assert.equal(seesDirection(0, origin, new THREE.Vector3(0, 0, -10)), false);
  assert.equal(seesDirection(0, origin, new THREE.Vector3(0, 0, 45)), false);
  const brain = createBrain(0),
    sound = new THREE.Vector3(2, 0, 10);
  rememberSound(brain, sound);
  sound.set(20, 0, -20);
  assert.deepEqual(brain.lastKnown?.toArray(), [2, 0, 10]);
  assert.equal(brain.state, 'search');
});
void test('unseen player movement cannot update a patrol or a last-known contact', () => {
  const g = harness(),
    b = makeBot(0);
  g.bots = [b];
  b.root.position.set(0, 0, 10);
  b.brain.lastKnown = new THREE.Vector3(0, 0, 5);
  b.brain.memory = 6;
  g.scene.add(b.root);
  g.hasSight = () => false;
  g.findPath = () => [];
  g.position.set(14, 0, -24);
  g.camera.position.set(14, 1.65, -24);
  g.updateBot(b, 0.1);
  assert.equal(b.brain.visible, false);
  assert.deepEqual(b.brain.lastKnown?.toArray(), [0, 0, 5]);
  assert.equal(b.brain.state, 'search');
  b.brain.memory = 0;
  g.updateBot(b, 0.1);
  assert.equal(b.brain.lastKnown, null);
  assert.equal(b.brain.state, 'patrol');
});
void test('enemy bursts use finite magazines and cannot damage a player through an obstruction', () => {
  const g = harness(),
    b = makeBot(0);
  g.bots = [b];
  g.scene.add(b.root);
  b.root.position.set(0, 0, 5);
  b.root.rotation.y = Math.PI;
  g.position.set(0, 0, -8);
  g.camera.position.set(0, 1.65, -8);
  const wall = new THREE.Mesh(
    new THREE.BoxGeometry(6, 4, 1),
    new THREE.MeshBasicMaterial(),
  );
  wall.position.set(0, 2, 0);
  g.world.targets = [wall];
  g.scene.add(wall);
  g.scene.updateMatrixWorld(true);
  g.botShoot(b, 13);
  assert.equal(g.state.health, 100);
  assert.equal(b.brain.ammo, 30);
  g.world.targets = [];
  for (let i = 0; i < 30; i++) g.botShoot(b, 13);
  assert.equal(b.brain.ammo, 0);
  g.findPath = () => [];
  g.updateBot(b, 0.1);
  assert.ok(b.brain.reload > 2);
  g.botShoot(b, 13);
  assert.equal(b.brain.ammo, 0);
});
void test('cover selection chooses a reachable hidden point with a clear adjacent peek', () => {
  const g = harness(),
    b = makeBot(0);
  g.bots = [b];
  const cover = { x: 0, z: 0, w: 3, d: 2, h: 2, y: 0 };
  g.world.solids = [cover];
  const wall = new THREE.Mesh(
    new THREE.BoxGeometry(3, 2, 2),
    new THREE.MeshBasicMaterial(),
  );
  wall.position.y = 1;
  g.world.targets = [wall];
  g.scene.add(wall);
  g.scene.updateMatrixWorld(true);
  b.root.position.set(0, 0, 4);
  const threat = new THREE.Vector3(0, 0, -10);
  const result = g.selectCover(b, threat);
  assert.ok(result);
  assert.equal(
    g.hasSight(result.hide.clone().setY(1.45), threat.clone().setY(1.5)),
    false,
  );
  assert.equal(
    g.hasSight(result.peek.clone().setY(1.45), threat.clone().setY(1.5)),
    true,
  );
});

void test('an agent reaches cover, peeks and fires instead of reversing halfway between destinations', () => {
  const g = harness(),
    b = makeBot(0);
  g.bots = [b];
  g.scene.add(b.root);
  g.world.solids = [{ x: 0, z: 0, w: 3, d: 2, h: 2, y: 0 }];
  const wall = new THREE.Mesh(
    new THREE.BoxGeometry(3, 2, 2),
    new THREE.MeshBasicMaterial(),
  );
  wall.position.y = 1;
  g.world.targets = [wall];
  g.scene.add(wall);
  g.position.set(0, 0, -10);
  g.camera.position.set(0, 1.65, -10);
  b.root.position.set(0, 0, 4);
  b.root.rotation.y = Math.PI;
  g.scene.updateMatrixWorld(true);
  b.brain.lastKnown = g.position.clone();
  b.brain.memory = 7;
  b.brain.cover = g.selectCover(b, g.position);
  b.brain.state = 'cover';
  g.findPath = () => [];
  let shots = 0,
    reachedPeek = false,
    reachedHide = false;
  const cover = b.brain.cover!;
  g.botShoot = (bot: any) => {
    shots++;
    bot.shot = 0.55;
  };
  for (let i = 0; i < 600; i++) {
    g.elapsed += 1 / 60;
    g.scene.updateMatrixWorld(true);
    g.updateBot(b, 1 / 60);
    reachedPeek ||= b.root.position.distanceTo(cover.peek) < 0.35;
    reachedHide ||= b.root.position.distanceTo(cover.hide) < 0.35;
    assert.equal(
      canOccupy(b.root.position.x, b.root.position.z, 0, 1.8, g.world.solids),
      true,
    );
  }
  assert.equal(reachedPeek, true);
  assert.equal(reachedHide, true);
  assert.ok(shots > 0, 'agent should fire after reaching its exposed angle');
});
void test('a reload queued with a quick trigger is applied after the buffered shot', () => {
  const g = harness();
  g.weapons = [];
  g.state.time = 120;
  g.firing = false;
  g.pressed = true;
  g.triggerClock = 0.16;
  g.reloadRequested = true;
  g.reloadClock = 0;
  g.reloadStage = -1;
  g.elapsed = 0;
  g.muzzleClock = 0;
  g.update(1 / 60);
  assert.equal(g.inventory[0].ammo, 29);
  assert.equal(g.state.reloading, true);
  assert.equal(g.reloadRequested, false);
});
