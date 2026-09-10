import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { createActor } from './actor';
import { buildWorld, canOccupy, supportHeight } from './world';
import { makeWeapon, installWeaponModel } from './weapon';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import {
  skills,
  createBrain,
  angleDifference,
  seesDirection,
  patrolRoutes,
  rememberSound,
  type Cover,
} from './ai';
import { makeBot } from './bot';
import { GameAudio } from './audio';
export type GameState = {
  phase: 'menu' | 'ready' | 'playing' | 'paused' | 'ended';
  health: number;
  armor: number;
  ammo: number;
  reserve: number;
  weapon: number;
  kills: number;
  deaths: number;
  headshots: number;
  time: number;
  reloading: boolean;
  reloadProgress: number;
  hit: number;
  hurt: number;
  spread: number;
  feed: { id: number; name: string; self: boolean; headshot: boolean }[];
  fps: number;
  locked: boolean;
  dead: boolean;
  zone: string;
  shots: number;
  hits: number;
};
const defaults = (): GameState => ({
  phase: 'menu',
  health: 100,
  armor: 100,
  ammo: 30,
  reserve: 90,
  weapon: 0,
  kills: 0,
  deaths: 0,
  headshots: 0,
  time: 120,
  reloading: false,
  reloadProgress: 0,
  hit: 0,
  hurt: 0,
  spread: 0,
  feed: [],
  fps: 60,
  locked: false,
  dead: false,
  zone: '南部入口',
  shots: 0,
  hits: 0,
});
const ammoSize = [30, 12],
  reloadTime = [2.35, 1.65],
  fireInterval = [0.105, 0.22];
export const spawnPoints = [
  [0, 23],
  [11, 23],
  [-10, 17],
  [1, -11],
  [11, 2],
  [-1, 5],
  [5, -26],
  [3, -27],
  [1, 11],
  [14, -2],
];
type Bot = ReturnType<typeof makeBot>;
export class DesertGame {
  renderer: THREE.WebGLRenderer;
  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(72, 1, 0.06, 250);
  viewScene = new THREE.Scene();
  viewCamera = new THREE.PerspectiveCamera(62, 1, 0.03, 10);
  world: ReturnType<typeof buildWorld>;
  weapons = [makeWeapon(), makeWeapon(true)];
  bots: Bot[] = [];
  audio = new GameAudio();
  state = defaults();
  disposed = false;
  last = 0;
  elapsed = 0;
  hudTime = 0;
  fpsTime = 0;
  frames = 0;
  sensitivity = 1;
  difficulty = 1;
  position = new THREE.Vector3(0, 0, 23);
  velocity = new THREE.Vector3();
  yaw = 0;
  pitch = 0;
  eye = 1.65;
  onGround = true;
  keys = new Set<string>();
  firing = false;
  pressed = false;
  triggerClock = 0;
  dragMode = false;
  capturePending = false;
  lookPointer: number | null = null;
  dragging = false;
  touchX = 0;
  touchY = 0;
  recoilPitch = 0;
  recoilYaw = 0;
  kick = 0;
  muzzleClock = 0;
  burst = 0;
  fireClock = 0;
  reloadClock = 0;
  reloadStage = -1;
  reloadRequested = false;
  inspectClock = 0;
  switchClock = 0;
  stepClock = 0;
  deathClock = 0;
  protection = 2.5;
  hitClock = 0;
  feedClock = 0;
  feedID = 0;
  inventory = [
    { ammo: 30, reserve: 90 },
    { ammo: 12, reserve: 48 },
  ];
  ray = new THREE.Raycaster();
  effects: {
    mesh: THREE.Object3D;
    velocity: THREE.Vector3;
    life: number;
    max: number;
    gravity: boolean;
  }[] = [];
  decals: THREE.Mesh[] = [];
  particleGeometry = new THREE.IcosahedronGeometry(1, 0);
  shellGeometry = new THREE.CylinderGeometry(0.014, 0.014, 0.05, 5);
  decalGeometry = new THREE.CircleGeometry(0.038, 7);
  dustMaterial = new THREE.MeshBasicMaterial({
    color: 0xc6b38b,
    transparent: true,
    opacity: 0.65,
    depthWrite: false,
  });
  sparkMaterial = new THREE.MeshBasicMaterial({ color: 0xffd399 });
  shellMaterial = new THREE.MeshStandardMaterial({
    color: 0x967b37,
    metalness: 0.72,
    roughness: 0.38,
  });
  decalMaterial = new THREE.MeshBasicMaterial({
    color: 0x342e20,
    transparent: true,
    opacity: 0.75,
    depthWrite: false,
    polygonOffset: true,
    polygonOffsetFactor: -1,
  });
  listeners = new AbortController();
  webTools = new AbortController();
  nav = new Uint8Array(49 * 65);
  loadedResources: THREE.Object3D[] = [];
  environment: THREE.WebGLRenderTarget | null = null;
  assetsReady: Promise<void>;
  constructor(
    public canvas: HTMLCanvasElement,
    public radar: HTMLCanvasElement | null,
    public emit: (s: GameState) => void,
  ) {
    this.renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: true,
      powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.6));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.03;
    this.renderer.autoClear = false;
    this.scene.background = new THREE.Color(0x94bac7);
    this.scene.fog = new THREE.FogExp2(0xc7c8ac, 0.0065);
    this.scene.add(new THREE.HemisphereLight(0xc5dcf5, 0x796950, 0.95));
    const sun = new THREE.DirectionalLight(0xffecd5, 3.5);
    sun.position.set(-28, 27, 12);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.camera.left = -46;
    sun.shadow.camera.right = 46;
    sun.shadow.camera.top = 46;
    sun.shadow.camera.bottom = -46;
    sun.shadow.camera.near = 1;
    sun.shadow.camera.far = 125;
    sun.shadow.normalBias = 0.045;
    sun.shadow.bias = -0.00012;
    sun.shadow.radius = 3;
    this.scene.add(sun);
    const pmrem = new THREE.PMREMGenerator(this.renderer);
    const studio = new RoomEnvironment();
    this.environment = pmrem.fromScene(studio, 0.06);
    this.scene.environment = this.viewScene.environment =
      this.environment.texture;
    this.scene.environmentIntensity = 0.22;
    this.viewScene.environmentIntensity = 0.65;
    studio.dispose();
    pmrem.dispose();
    this.world = buildWorld(this.scene);
    this.viewScene.add(new THREE.HemisphereLight(0xd2e4eb, 0x5d5948, 2.2));
    const vl = new THREE.DirectionalLight(0xffdfb3, 3);
    vl.position.set(-3, 5, 1);
    this.viewScene.add(vl);
    this.viewScene.add(this.viewCamera);
    this.weapons.forEach((w) => this.viewCamera.add(w.root));
    this.weapons[1].root.visible = false;
    this.camera.rotation.order = 'YXZ';
    this.camera.position.set(6, 2.7, 24);
    this.camera.lookAt(0, 2, -10);
    for (let i = 0; i < 4; i++) {
      const b = makeBot(i);
      const p = spawnPoints[i + 3];
      b.root.position.set(p[0], 0, p[1]);
      this.bots.push(b);
      this.scene.add(b.root);
    }
    for (let z = 0; z < 65; z++)
      for (let x = 0; x < 49; x++)
        this.nav[z * 49 + x] = canOccupy(
          x - 24,
          z - 32,
          0,
          1.8,
          this.world.solids,
          0.43,
        )
          ? 1
          : 0;
    this.assetsReady = Promise.all([
      this.loadSoldiers(),
      this.loadWeapons(),
    ]).then(() => {});
    this.scene.updateMatrixWorld(true);
    this.bindInput();
    this.resize();
    this.registerTools();
    this.renderer.setAnimationLoop(this.frame);
    this.publish();
  }
  async loadWeapons() {
    await Promise.all(
      ['/assets/rifle.glb', '/assets/sidearm.glb'].map(async (url, i) => {
        const gltf = await new GLTFLoader().loadAsync(url);
        if (this.disposed) {
          this.disposeObject(gltf.scene);
          return;
        }
        this.loadedResources.push(gltf.scene);
        installWeaponModel(this.weapons[i], gltf.scene);
        if (i === 0)
          for (const bot of this.bots) {
            const gun = gltf.scene.clone(true);
            for (const name of ['MainArm', 'SupportArm'])
              gun.getObjectByName(name)?.removeFromParent();
            bot.weapon.clear();
            gun.scale.setScalar(0.58);
            gun.rotation.y = Math.PI;
            gun.position.set(-0.1, 1.27, 0.23);
            gun.traverse((o) => {
              if (o instanceof THREE.Mesh) o.castShadow = true;
            });
            bot.weapon.add(gun);
          }
      }),
    );
  }
  async loadSoldiers() {
    const gltf = await new GLTFLoader().loadAsync('/assets/operator.glb');
    if (this.disposed) {
      this.disposeObject(gltf.scene);
      return;
    }
    this.loadedResources.push(gltf.scene);
    for (const bot of this.bots) {
      const prepared = createActor(gltf.scene, gltf.animations);
      bot.visual.visible = false;
      bot.root.add(prepared.wrapper);
      bot.hitboxes = bot.proxies;
      bot.mixer = prepared.mixer;
      bot.pose = prepared.pose;
      bot.headBone = prepared.headBone || null;
      this.syncBotPose(bot);
      bot.actions = prepared.actions;
      bot.animation = bot.actions.idle ? 'idle' : Object.keys(bot.actions)[0];
    }
  }
  resize() {
    const w = this.canvas.clientWidth || innerWidth,
      h = this.canvas.clientHeight || innerHeight;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.viewCamera.aspect = w / h;
    this.viewCamera.updateProjectionMatrix();
  }
  configure(s: number, v: number, d: number) {
    this.sensitivity = Math.max(0.3, Math.min(2.5, s));
    this.difficulty = Math.max(0, Math.min(2, Math.round(d)));
    this.audio.setVolume(v);
  }
  publish() {
    const inv = this.inventory[this.state.weapon];
    this.state.ammo = inv.ammo;
    this.state.reserve = inv.reserve;
    this.emit({ ...this.state, feed: [...this.state.feed] });
  }
  start() {
    if (this.state.phase === 'playing') return;
    if (this.state.phase !== 'paused' && this.state.phase !== 'ready')
      this.reset();
    this.state.phase = 'ready';
    this.dragMode = false;
    this.reloadRequested = false;
    this.keys.clear();
    this.firing = this.pressed = false;
    this.triggerClock = 0;
    try {
      this.audio.init();
    } catch {}
    this.capture();
    this.publish();
  }
  startDragMode() {
    if (this.state.phase !== 'ready') return;
    this.dragMode = true;
    this.state.phase = 'playing';
    this.last = performance.now();
    try {
      this.audio.init();
    } catch {}
    this.publish();
  }
  restart() {
    this.reset();
    this.start();
  }
  reset() {
    this.state = defaults();
    this.inventory = [
      { ammo: 30, reserve: 90 },
      { ammo: 12, reserve: 48 },
    ];
    this.position.set(0, 0, 23);
    this.velocity.set(0, 0, 0);
    this.yaw = 0;
    this.pitch = 0;
    this.eye = 1.65;
    this.recoilPitch =
      this.recoilYaw =
      this.kick =
      this.burst =
      this.reloadClock =
      this.inspectClock =
      this.switchClock =
      this.deathClock =
        0;
    this.fireClock =
      this.muzzleClock =
      this.hitClock =
      this.feedClock =
      this.triggerClock =
        0;
    this.reloadStage = -1;
    this.stepClock = 0;
    this.dragMode = false;
    this.capturePending = false;
    this.lookPointer = null;
    this.protection = 2.5;
    this.onGround = true;
    this.reloadRequested = false;
    this.keys.clear();
    this.firing = this.pressed = false;
    this.bots.forEach((b, i) => this.respawnBot(b, i + 3));
    this.weapons[0].root.visible = true;
    this.weapons[1].root.visible = false;
    this.effects.forEach((e) => {
      this.scene.remove(e.mesh);
      if (e.mesh instanceof THREE.Line) {
        e.mesh.geometry.dispose();
        (e.mesh.material as THREE.Material).dispose();
      }
    });
    this.effects = [];
    this.decals.forEach((d) => this.scene.remove(d));
    this.decals = [];
    this.updateCamera(0);
  }
  pause() {
    if (this.state.phase !== 'playing' && this.state.phase !== 'ready') return;
    this.state.phase = 'paused';
    this.reloadRequested = false;
    this.keys.clear();
    this.firing = this.pressed = this.dragging = false;
    this.triggerClock = 0;
    this.lookPointer = null;
    this.audio.pause();
    if (document.pointerLockElement === this.canvas) document.exitPointerLock();
    this.publish();
  }
  capture() {
    if (this.state.phase !== 'ready' || this.capturePending) return;
    this.capturePending = true;
    const failed = () => {
      this.capturePending = false;
      this.state.locked = false;
      this.publish();
    };
    try {
      if (!this.canvas.requestPointerLock) {
        failed();
        return;
      }
      const pending = this.canvas.requestPointerLock();
      if (pending && typeof pending.catch === 'function') pending.catch(failed);
    } catch {
      failed();
    }
  }
  setKey(key: string, value: boolean) {
    if (value && this.state.phase === 'playing' && !this.state.dead)
      this.keys.add(key);
    else this.keys.delete(key);
  }
  setFire(value: boolean) {
    if (this.state.phase !== 'playing' || this.state.dead) return;
    if (value && !this.firing) {
      this.pressed = true;
      this.triggerClock = 0.16;
    }
    this.firing = value;
  }
  bindInput() {
    const opts = { signal: this.listeners.signal };
    window.addEventListener('resize', () => this.resize(), opts);
    document.addEventListener(
      'pointerlockchange',
      () => {
        const was = this.state.locked;
        this.state.locked = document.pointerLockElement === this.canvas;
        this.capturePending = false;
        if (this.state.locked && this.state.phase === 'ready') {
          this.dragMode = false;
          this.state.phase = 'playing';
          this.last = performance.now();
        } else if (
          was &&
          !this.state.locked &&
          this.state.phase === 'playing'
        ) {
          this.pause();
        } else if (this.state.locked && this.state.phase !== 'playing') {
          document.exitPointerLock();
        }
        this.publish();
      },
      opts,
    );
    document.addEventListener(
      'pointerlockerror',
      () => {
        this.capturePending = false;
        this.state.locked = false;
        this.publish();
      },
      opts,
    );
    document.addEventListener(
      'keydown',
      (e) => {
        if (e.code === 'Escape') {
          this.pause();
          return;
        }
        if (this.state.phase !== 'playing' || this.state.dead) return;
        if (
          [
            'Space',
            'ControlLeft',
            'ControlRight',
            'Tab',
            'KeyW',
            'KeyA',
            'KeyS',
            'KeyD',
            'ShiftLeft',
            'KeyR',
            'KeyC',
          ].includes(e.code)
        )
          e.preventDefault();
        if (!e.repeat) {
          if (e.code === 'KeyR') this.reloadRequested = true;
          if (e.code === 'Digit1') this.switchWeapon(0);
          if (e.code === 'Digit2') this.switchWeapon(1);
          if (e.code === 'KeyF' && !this.state.reloading)
            this.inspectClock = 2.25;
          if (e.code === 'Space' && this.onGround) {
            this.velocity.y = 5.3;
            this.onGround = false;
            this.audio.step(true);
          }
        }
        this.setKey(e.code, true);
      },
      opts,
    );
    document.addEventListener('keyup', (e) => this.setKey(e.code, false), opts);
    window.addEventListener(
      'blur',
      () => {
        if (this.state.phase === 'playing') this.pause();
      },
      opts,
    );
    document.addEventListener(
      'visibilitychange',
      () => {
        if (document.hidden) this.pause();
      },
      opts,
    );
    this.canvas.addEventListener(
      'contextmenu',
      (e) => e.preventDefault(),
      opts,
    );
    this.canvas.addEventListener(
      'pointerdown',
      (e) => {
        if (this.state.phase !== 'playing' || this.state.dead) return;
        this.touchX = e.clientX;
        this.touchY = e.clientY;
        if (e.pointerType === 'touch' || e.button === 2) {
          this.dragging = true;
          this.lookPointer = e.pointerId;
          this.canvas.setPointerCapture(e.pointerId);
        }
        if (e.pointerType !== 'touch' && e.button === 0) this.setFire(true);
      },
      opts,
    );
    document.addEventListener(
      'pointerup',
      (e) => {
        if (e.pointerType !== 'touch' && e.button === 0) this.setFire(false);
        if (
          e.pointerId === this.lookPointer &&
          (e.pointerType === 'touch' || e.button === 2)
        ) {
          this.dragging = false;
          this.lookPointer = null;
        }
      },
      opts,
    );
    document.addEventListener(
      'pointercancel',
      (e) => {
        this.setFire(false);
        if (e.pointerId === this.lookPointer) {
          this.dragging = false;
          this.lookPointer = null;
        }
        this.reloadRequested = false;
        this.keys.clear();
      },
      opts,
    );
    document.addEventListener(
      'pointermove',
      (e) => {
        if (
          this.state.phase !== 'playing' ||
          this.state.dead ||
          (!this.state.locked &&
            (!this.dragging || e.pointerId !== this.lookPointer))
        )
          return;
        const dx = this.state.locked ? e.movementX : e.clientX - this.touchX;
        const dy = this.state.locked ? e.movementY : e.clientY - this.touchY;
        this.touchX = e.clientX;
        this.touchY = e.clientY;
        this.yaw -=
          Math.max(-250, Math.min(250, dx)) * 0.0018 * this.sensitivity;
        this.pitch = THREE.MathUtils.clamp(
          this.pitch -
            Math.max(-250, Math.min(250, dy)) * 0.0018 * this.sensitivity,
          -1.42,
          1.42,
        );
      },
      opts,
    );
    this.canvas.addEventListener(
      'wheel',
      (e) => {
        if (this.state.phase === 'playing') {
          e.preventDefault();
          this.switchWeapon(1 - this.state.weapon);
        }
      },
      { ...opts, passive: false },
    );
  }
  switchWeapon(index: number) {
    if (
      this.state.phase !== 'playing' ||
      this.state.dead ||
      ![0, 1].includes(index) ||
      this.state.weapon === index
    )
      return;
    this.state.weapon = index;
    this.state.reloading = false;
    this.reloadClock = 0;
    this.state.reloadProgress = 0;
    this.muzzleClock = 0;
    this.pressed = false;
    this.triggerClock = 0;
    this.inspectClock = 0;
    this.switchClock = 0.3;
    this.burst = 0;
    this.weapons.forEach((w, i) => (w.root.visible = i === index));
    this.audio.mechanical(0);
    this.publish();
  }
  reload() {
    const inv = this.inventory[this.state.weapon];
    if (
      this.state.phase !== 'playing' ||
      this.state.dead ||
      this.state.reloading ||
      inv.ammo === ammoSize[this.state.weapon] ||
      inv.reserve <= 0
    )
      return;
    this.state.reloading = true;
    this.state.reloadProgress = 0;
    this.reloadClock = 0;
    this.reloadStage = -1;
    this.inspectClock = 0;
    this.audio.mechanical(0);
    this.publish();
  }
  updateReload(dt: number) {
    if (!this.state.reloading) return;
    this.reloadClock += dt;
    const p = this.reloadClock / reloadTime[this.state.weapon];
    this.state.reloadProgress = Math.min(1, p);
    const stage = p < 0.18 ? 0 : p < 0.6 ? 1 : p < 0.84 ? 2 : 3;
    if (stage !== this.reloadStage) {
      this.reloadStage = stage;
      if (stage > 0) this.audio.mechanical(stage === 2 ? 1 : 0);
    }
    if (p >= 1) {
      const inv = this.inventory[this.state.weapon],
        n = Math.min(ammoSize[this.state.weapon] - inv.ammo, inv.reserve);
      inv.ammo += n;
      inv.reserve -= n;
      this.state.reloading = false;
      this.reloadClock = 0;
      this.publish();
    }
  }
  frame = (time: number) => this.advanceFrame(time);
  advanceFrame(time: number) {
    if (this.disposed) return;
    const rawDelta = this.last
      ? Math.max(0, (time - this.last) / 1000)
      : 1 / 60;
    const dt = Math.min(0.25, rawDelta);
    this.last = time;
    if (this.state.phase === 'playing' || this.state.phase === 'menu')
      this.elapsed += dt;
    this.frames++;
    this.fpsTime += rawDelta;
    if (this.fpsTime > 0.75) {
      this.state.fps = Math.min(240, Math.round(this.frames / this.fpsTime));
      this.frames = 0;
      this.fpsTime = 0;
    }
    if (this.state.phase === 'playing') {
      const steps = Math.max(1, Math.ceil(dt * 60));
      for (let step = 0; step < steps && this.state.phase === 'playing'; step++)
        this.update(dt / steps);
    } else if (this.state.phase === 'menu') {
      this.camera.position.x = 6 + Math.sin(this.elapsed * 0.07) * 0.65;
      this.camera.lookAt(0, 2, -10);
      for (const b of this.bots) {
        b.mixer?.update(dt);
        this.syncBotPose(b);
      }
    }
    this.animateWeapon(dt);
    this.renderer.clear();
    this.renderer.render(this.scene, this.camera);
    this.renderer.clearDepth();
    this.renderer.render(this.viewScene, this.viewCamera);
    this.hudTime += dt;
    if (this.hudTime > 0.066) {
      this.hudTime = 0;
      this.drawRadar();
      this.publish();
    }
  }
  update(dt: number) {
    this.state.time = Math.max(0, this.state.time - dt);
    if (this.state.time <= 0 || this.state.kills >= 12) {
      this.finish();
      return;
    }
    this.protection = Math.max(0, this.protection - dt);
    this.fireClock -= dt;
    this.triggerClock = Math.max(0, this.triggerClock - dt);
    if (this.triggerClock <= 0) this.pressed = false;
    this.muzzleClock -= dt;
    this.hitClock -= dt;
    if (this.hitClock <= 0) this.state.hit = 0;
    this.state.hurt = Math.max(0, this.state.hurt - dt * 1.5);
    this.feedClock -= dt;
    if (this.feedClock <= 0 && this.state.feed.length) {
      this.state.feed.shift();
      this.feedClock = 3;
    }
    this.recoilPitch *= Math.exp(-dt * (this.firing ? 5 : 10));
    this.recoilYaw *= Math.exp(-dt * 9);
    this.kick *= Math.exp(-dt * 17);
    if (!this.firing) this.burst = Math.max(0, this.burst - dt * 8);
    if (this.state.dead) {
      this.deathClock -= dt;
      if (this.deathClock <= 0) this.respawnPlayer();
    } else {
      this.movePlayer(dt);
      this.updateReload(dt);
      this.updateCamera(dt);
      const trigger =
        this.state.weapon === 0 ? this.firing || this.pressed : this.pressed;
      if (trigger && this.fireClock <= 0) this.shoot();
      if (this.reloadRequested) {
        this.reloadRequested = false;
        this.reload();
      }
    }
    this.scene.updateMatrixWorld(true);
    for (const bot of this.bots) this.updateBot(bot, dt);
    for (let i = this.effects.length - 1; i >= 0; i--) {
      const e = this.effects[i];
      e.life -= dt;
      if (e.life <= 0) {
        this.scene.remove(e.mesh);
        if (e.mesh instanceof THREE.Line) {
          e.mesh.geometry.dispose();
          (e.mesh.material as THREE.Material).dispose();
        }
        this.effects.splice(i, 1);
        continue;
      }
      e.mesh.position.addScaledVector(e.velocity, dt);
      if (e.gravity) e.velocity.y -= dt * 9;
      if (e.mesh.position.y < 0.035 && e.gravity) {
        e.mesh.position.y = 0.035;
        e.velocity.y = Math.abs(e.velocity.y) * 0.3;
        e.velocity.x *= 0.8;
        e.velocity.z *= 0.8;
      }
      if (
        e.mesh instanceof THREE.Mesh &&
        e.mesh.geometry === this.shellGeometry
      )
        e.mesh.rotation.x += dt * 14;
    }
  }
  canMoveTo(x: number, z: number, y: number, height: number, movingBot?: Bot) {
    if (!canOccupy(x, z, y, height, this.world.solids, movingBot ? 0.34 : 0.32))
      return false;
    if (
      y < 1.8 &&
      this.bots.some(
        (other) =>
          other !== movingBot &&
          other.hp > 0 &&
          Math.hypot(x - other.root.position.x, z - other.root.position.z) <
            0.62,
      )
    )
      return false;
    if (
      movingBot &&
      !this.state.dead &&
      Math.hypot(x - this.position.x, z - this.position.z) < 0.66
    )
      return false;
    return true;
  }
  movePlayer(dt: number) {
    const crouch =
      this.keys.has('KeyC') ||
      this.keys.has('ControlLeft') ||
      this.keys.has('ControlRight');
    let height = crouch ? 1.02 : 1.65;
    if (
      height > this.eye &&
      !canOccupy(
        this.position.x,
        this.position.z,
        this.position.y,
        1.77,
        this.world.solids,
      )
    )
      height = 1.02;
    this.eye = THREE.MathUtils.damp(this.eye, height, 15, dt);
    const walk = this.keys.has('ShiftLeft') || this.keys.has('ShiftRight'),
      speed =
        (crouch ? 1.5 : walk ? 2.1 : 4.65) * (this.state.weapon ? 1.08 : 1);
    const f = (this.keys.has('KeyW') ? 1 : 0) - (this.keys.has('KeyS') ? 1 : 0),
      s = (this.keys.has('KeyD') ? 1 : 0) - (this.keys.has('KeyA') ? 1 : 0),
      input = new THREE.Vector3(s, 0, -f);
    if (input.lengthSq() > 1) input.normalize();
    input
      .applyAxisAngle(new THREE.Vector3(0, 1, 0), this.yaw)
      .multiplyScalar(speed);
    const acceleration = this.onGround ? 16 : 3;
    this.velocity.x = THREE.MathUtils.damp(
      this.velocity.x,
      input.x,
      acceleration,
      dt,
    );
    this.velocity.z = THREE.MathUtils.damp(
      this.velocity.z,
      input.z,
      acceleration,
      dt,
    );
    const nx = this.position.x + this.velocity.x * dt,
      nz = this.position.z + this.velocity.z * dt;
    if (this.canMoveTo(nx, this.position.z, this.position.y, this.eye + 0.12))
      this.position.x = nx;
    else this.velocity.x = 0;
    if (this.canMoveTo(this.position.x, nz, this.position.y, this.eye + 0.12))
      this.position.z = nz;
    else this.velocity.z = 0;
    this.velocity.y -= 14 * dt;
    const oldFeet = this.position.y,
      nextFeet = this.position.y + this.velocity.y * dt,
      floor = supportHeight(
        this.position.x,
        this.position.z,
        oldFeet,
        this.world.solids,
      );
    if (nextFeet <= floor && this.velocity.y <= 0) {
      if (!this.onGround && this.velocity.y < -3) this.audio.step(false, true);
      this.position.y = floor;
      this.velocity.y = 0;
      this.onGround = true;
    } else if (
      this.velocity.y > 0 &&
      !canOccupy(
        this.position.x,
        this.position.z,
        nextFeet,
        this.eye + 0.12,
        this.world.solids,
      )
    ) {
      this.velocity.y = 0;
    } else {
      this.position.y = nextFeet;
      this.onGround = false;
    }
    const moving = Math.hypot(this.velocity.x, this.velocity.z);
    this.stepClock -= dt;
    if (moving > 0.6 && this.onGround && this.stepClock <= 0) {
      this.audio.step(walk || crouch);
      this.hearNoise(this.position, walk || crouch ? 2.5 : 11);
      this.stepClock = walk ? 0.53 : crouch ? 0.65 : 0.34;
    }
    this.state.spread =
      0.018 + moving * 0.027 + this.burst * 0.006 + (!this.onGround ? 0.25 : 0);
    this.state.zone =
      this.position.z > 13
        ? '南部入口'
        : this.position.z < -18
          ? '北部庭院'
          : this.position.x > 9
            ? '东侧长街'
            : this.position.z < -10
              ? '中央拱门'
              : 'A 区通道';
  }
  updateCamera(_dt: number) {
    const speed = Math.hypot(this.velocity.x, this.velocity.z),
      bob = this.onGround
        ? Math.sin(this.elapsed * 12) * Math.min(speed / 4.6, 1) * 0.023
        : 0;
    this.camera.position.copy(this.position);
    this.camera.position.y += this.state.dead ? 0.78 : this.eye + bob;
    this.camera.rotation.set(
      this.pitch + this.recoilPitch,
      this.yaw + this.recoilYaw,
      0,
      'YXZ',
    );
    this.camera.updateMatrixWorld();
  }
  animateWeapon(dt: number) {
    const w = this.weapons[this.state.weapon],
      active = this.state.phase === 'playing';
    if (active) {
      this.inspectClock = Math.max(0, this.inspectClock - dt);
      this.switchClock = Math.max(0, this.switchClock - dt);
    }
    const moving =
      active && !this.state.dead
        ? Math.min(1, Math.hypot(this.velocity.x, this.velocity.z) / 4.6)
        : 0;
    const p = this.state.reloading ? this.state.reloadProgress : 0,
      reloadTilt = this.state.reloading
        ? Math.sin((Math.min(1, p * 1.8) * Math.PI) / 2) *
          Math.min(1, (1 - p) * 6)
        : 0;
    const inspect =
      this.inspectClock > 0
        ? Math.sin((1 - this.inspectClock / 2.25) * Math.PI)
        : 0;
    const sw = this.switchClock / 0.3;
    w.root.position.set(
      (this.state.weapon ? 0.2 : 0.25) +
        Math.sin(this.elapsed * 6) * 0.008 * moving -
        inspect * 0.06,
      (this.state.weapon ? -0.21 : -0.3) +
        Math.cos(this.elapsed * 12) * 0.008 * moving -
        reloadTilt * 0.08 -
        sw * 0.25,
      -0.45 + this.kick * 0.06 + reloadTilt * 0.08 + inspect * 0.03,
    );
    w.root.scale.setScalar(0.78);
    w.root.rotation.set(
      0.025 + this.kick * 0.09 - reloadTilt * 0.2 + inspect * 0.08,
      0.07 + inspect * 0.4,
      -0.015 +
        Math.sin(this.elapsed * 6) * 0.01 * moving -
        reloadTilt * 0.32 +
        inspect * 0.35,
    );
    const magDrop = this.state.reloading
      ? Math.sin(Math.max(0, Math.min(1, (p - 0.14) / 0.54)) * Math.PI) * 0.65
      : 0;
    w.magazine.position.y = w.magazineBaseY - magDrop;
    w.magazine.rotation.x = -magDrop * 0.3;
    const reach = this.state.reloading
      ? THREE.MathUtils.clamp(Math.min(p / 0.12, (1 - p) / 0.15), 0, 1)
      : 0;
    w.leftHand.position.y =
      -(this.state.weapon ? 0.14 : 0.08) * reach - magDrop;
    w.leftHand.position.z =
      (this.state.weapon ? 0 : 0.26) * reach - magDrop * 0.1;
    // The support hand follows the magazine out and back, then reaches the bolt.
    const rack = this.state.reloading
      ? Math.sin(THREE.MathUtils.clamp((p - 0.76) / 0.2, 0, 1) * Math.PI)
      : 0;
    w.leftHand.position.x = rack * 0.16 + reach * 0.02;
    w.leftHand.position.z += rack * 0.36;
    w.leftHand.rotation.z = magDrop * 0.3;
    w.bolt.position.z =
      this.kick * (this.state.weapon ? 0.065 : 0.022) + rack * 0.075;
    w.flash.visible = active && this.muzzleClock > 0 && !this.state.reloading;
    w.flash.rotation.z = Math.random() * 6;
    w.light.intensity = w.flash.visible ? 2.8 : 0;
    w.root.visible = !this.state.dead;
  }
  shoot() {
    const inv = this.inventory[this.state.weapon];
    if (this.state.reloading || this.state.dead || this.switchClock > 0) return;
    if (!inv.ammo) {
      this.reload();
      this.fireClock = 0.25;
      return;
    }
    inv.ammo--;
    this.pressed = false;
    this.triggerClock = 0;
    this.state.shots++;
    this.inspectClock = 0;
    this.fireClock = fireInterval[this.state.weapon];
    this.burst++;
    this.kick = 1;
    this.muzzleClock = 0.045;
    const moving = Math.hypot(this.velocity.x, this.velocity.z),
      spread =
        (this.state.weapon ? 0.0022 : 0.0012) +
        moving * 0.0045 +
        Math.max(0, this.burst - 3) * 0.00065 +
        (!this.onGround ? 0.028 : 0);
    const dir = this.camera.getWorldDirection(new THREE.Vector3());
    const right = new THREE.Vector3(1, 0, 0).applyQuaternion(
        this.camera.quaternion,
      ),
      up = new THREE.Vector3(0, 1, 0).applyQuaternion(this.camera.quaternion);
    dir
      .addScaledVector(right, (Math.random() - 0.5) * spread)
      .addScaledVector(up, (Math.random() - 0.5) * spread)
      .normalize();
    this.scene.updateMatrixWorld(true);
    this.ray.set(this.camera.position, dir);
    this.ray.far = 120;
    const hitMeshes = this.bots
        .filter((b) => b.hp > 0)
        .flatMap((b) => b.hitboxes),
      hit = this.ray.intersectObjects(
        [...this.world.targets, ...hitMeshes],
        false,
      )[0];
    const end = hit
      ? hit.point
      : this.camera.position.clone().addScaledVector(dir, 90);
    if (hit) {
      if (typeof hit.object.userData.bot === 'number') {
        const bot = this.bots[hit.object.userData.bot],
          head = hit.object.userData.part === 'head';
        rememberSound(bot.brain, this.position);
        bot.reaction = Math.min(bot.reaction, skills[this.difficulty].reaction);
        bot.hp -= head
          ? this.state.weapon
            ? 84
            : 110
          : this.state.weapon
            ? 28
            : 35;
        this.state.hits++;
        this.state.hit = head ? 2 : 1;
        this.hitClock = 0.16;
        this.audio.impact(head);
        this.impact(end, head ? 5 : 3, false);
        if (bot.hp <= 0) this.killBot(bot, head);
      } else {
        this.impact(end, 6, true);
        if (hit.face) {
          const normal = hit.face.normal
            .clone()
            .transformDirection(hit.object.matrixWorld);
          const mark = new THREE.Mesh(this.decalGeometry, this.decalMaterial);
          mark.position.copy(end).addScaledVector(normal, 0.008);
          mark.lookAt(end.clone().add(normal));
          this.scene.add(mark);
          this.decals.push(mark);
          if (this.decals.length > 75) this.scene.remove(this.decals.shift()!);
        }
      }
    }
    const muzzle = this.camera.position
      .clone()
      .addScaledVector(right, 0.23)
      .addScaledVector(up, -0.2)
      .addScaledVector(dir, 0.7);
    this.tracer(muzzle, end, 0xf5d09b, 0.035);
    const casing = new THREE.Mesh(this.shellGeometry, this.shellMaterial);
    casing.position
      .copy(this.camera.position)
      .addScaledVector(right, 0.27)
      .addScaledVector(dir, 0.5);
    this.scene.add(casing);
    this.effects.push({
      mesh: casing,
      velocity: right.multiplyScalar(2.3).add(new THREE.Vector3(0, 1.6, 0)),
      life: 2.5,
      max: 2.5,
      gravity: true,
    });
    this.recoilPitch = Math.min(
      0.14,
      this.recoilPitch +
        (this.state.weapon ? 0.03 : 0.017) +
        Math.min(this.burst, 10) * 0.0012,
    );
    this.recoilYaw += Math.sin(this.burst * 0.79) * 0.006;
    this.hearNoise(this.position, 42);
    this.audio.shot(!!this.state.weapon);
    this.publish();
  }
  tracer(
    start: THREE.Vector3,
    end: THREE.Vector3,
    color: number,
    life: number,
  ) {
    const line = new THREE.Line(
      new THREE.BufferGeometry().setFromPoints([start, end]),
      new THREE.LineBasicMaterial({
        color,
        transparent: true,
        opacity: 0.36,
        depthWrite: false,
      }),
    );
    this.scene.add(line);
    this.effects.push({
      mesh: line,
      velocity: new THREE.Vector3(),
      life,
      max: life,
      gravity: false,
    });
  }
  impact(p: THREE.Vector3, n: number, wall: boolean) {
    for (let i = 0; i < n; i++) {
      const m = new THREE.Mesh(
        this.particleGeometry,
        wall ? this.dustMaterial : this.sparkMaterial,
      );
      m.position.copy(p);
      m.scale.setScalar(wall ? 0.026 + Math.random() * 0.03 : 0.014);
      this.scene.add(m);
      this.effects.push({
        mesh: m,
        velocity: new THREE.Vector3(
          (Math.random() - 0.5) * 2,
          Math.random() * 1.5,
          (Math.random() - 0.5) * 2,
        ),
        life: 0.15 + Math.random() * 0.35,
        max: 0.5,
        gravity: true,
      });
    }
  }
  killBot(bot: Bot, head: boolean) {
    bot.hp = 0;
    bot.dead = 2.2;
    bot.light.intensity = 0;
    this.state.kills++;
    if (head) this.state.headshots++;
    this.state.feed.push({
      id: ++this.feedID,
      name: bot.name,
      self: true,
      headshot: head,
    });
    this.state.feed = this.state.feed.slice(-4);
    this.feedClock = 4;
    this.inventory[0].reserve = Math.min(90, this.inventory[0].reserve + 15);
    this.inventory[1].reserve = Math.min(48, this.inventory[1].reserve + 6);
  }
  hasSight(from: THREE.Vector3, to: THREE.Vector3) {
    const d = to.clone().sub(from);
    const len = d.length();
    this.ray.set(from, d.normalize());
    this.ray.far = Math.max(0, len - 0.15);
    return !this.ray.intersectObjects(this.world.targets, false).length;
  }
  hearNoise(point: THREE.Vector3, radius: number) {
    for (const bot of this.bots) {
      if (bot.hp <= 0 || bot.brain.visible) continue;
      const ear = bot.root.position.clone().setY(1.5);
      const audible = this.hasSight(ear, point.clone().setY(1.2))
        ? radius
        : radius * 0.55;
      if (bot.root.position.distanceTo(point) > audible) continue;
      // A sound gives an approximate, fixed location. Walking silently carries much less far.
      const heard = point.clone().setY(0);
      heard.x = Math.round(heard.x);
      heard.z = Math.round(heard.z);
      rememberSound(bot.brain, heard);
      bot.pathTime = 0;
    }
  }
  selectCover(bot: Bot, threat: THREE.Vector3): Cover | null {
    const pos = bot.root.position,
      eye = threat.clone().setY(1.5);
    let selected: Cover | null = null,
      best = Infinity;
    for (const s of this.world.solids) {
      if (
        s.y > 0.1 ||
        s.h < 1.35 ||
        Math.hypot(s.x - pos.x, s.z - pos.z) > Math.max(s.w, s.d) / 2 + 9
      )
        continue;
      for (const side of [-1, 1])
        for (const end of [-1, 1]) {
          const pairs = [
            {
              hide: new THREE.Vector3(
                s.x + side * (s.w / 2 + 0.65),
                0,
                s.z + end * (s.d / 2 - 0.6),
              ),
              peek: new THREE.Vector3(
                s.x + side * (s.w / 2 + 0.75),
                0,
                s.z + end * (s.d / 2 + 0.9),
              ),
            },
            {
              hide: new THREE.Vector3(
                s.x + side * (s.w / 2 - 0.6),
                0,
                s.z + end * (s.d / 2 + 0.65),
              ),
              peek: new THREE.Vector3(
                s.x + side * (s.w / 2 + 0.9),
                0,
                s.z + end * (s.d / 2 + 0.75),
              ),
            },
          ];
          for (const c of pairs) {
            const distance = c.hide.distanceTo(pos);
            if (distance > 9 || c.peek.distanceTo(threat) < 4) continue;
            if (
              ![c.hide, c.peek].every((p) =>
                canOccupy(p.x, p.z, 0, 1.8, this.world.solids, 0.43),
              )
            )
              continue;
            if (
              this.bots.some(
                (other) =>
                  other !== bot &&
                  other.hp > 0 &&
                  (other.brain.cover?.hide.distanceTo(c.hide) ?? 99) < 2,
              )
            )
              continue;
            if (
              this.hasSight(c.hide.clone().setY(1.45), eye) ||
              !this.hasSight(c.peek.clone().setY(1.45), eye)
            )
              continue;
            // Don't choose a close point on the far side of a long, impassable wall.
            if (!this.hasSight(pos.clone().setY(0.8), c.hide.clone().setY(0.8)))
              continue;
            const score =
              distance + Math.abs(c.peek.distanceTo(threat) - 12) * 0.08;
            if (score < best) {
              best = score;
              selected = c;
            }
          }
        }
    }
    return selected;
  }
  updateBot(bot: Bot, dt: number) {
    const brain = bot.brain,
      skill = skills[this.difficulty];
    if (bot.hp <= 0) {
      bot.light.intensity = 0;
      bot.muzzle.visible = false;
      bot.dead -= dt;
      bot.root.rotation.x = THREE.MathUtils.damp(
        bot.root.rotation.x,
        -Math.PI / 2,
        8,
        dt,
      );
      bot.root.position.y = -0.04;
      if (bot.dead < 0.9) bot.root.visible = false;
      if (bot.dead <= 0) this.respawnBot(bot);
      return;
    }
    bot.root.rotation.x = 0;
    bot.root.visible = true;
    bot.shot -= dt;
    bot.light.intensity = Math.max(0, bot.light.intensity - dt * 40);
    bot.muzzle.visible = bot.light.intensity > 0.4;
    bot.pathTime -= dt;
    brain.memory = Math.max(0, brain.memory - dt);
    brain.decision -= dt;
    brain.hold -= dt;
    brain.callClock -= dt;
    brain.senseClock -= dt;
    const pos = bot.root.position,
      origin = pos.clone().setY(1.55);
    if (brain.senseClock <= 0) {
      brain.senseClock = 0.1;
      brain.visible =
        !this.state.dead &&
        seesDirection(
          bot.root.rotation.y,
          pos,
          this.position,
          brain.memory > 0 ? 140 : 110,
        ) &&
        (this.hasSight(origin, this.camera.position) ||
          this.hasSight(
            origin,
            this.position.clone().add(new THREE.Vector3(0, this.eye * 0.65, 0)),
          ));
      if (brain.visible) {
        brain.lastKnown = this.position.clone();
        brain.memory = 7;
        brain.search = 0;
        if (brain.callClock <= 0) {
          // Nearby squadmates can investigate a contact report, but still have to see before shooting.
          for (const ally of this.bots)
            if (
              ally !== bot &&
              ally.hp > 0 &&
              !ally.brain.visible &&
              ally.root.position.distanceTo(pos) < 18
            ) {
              rememberSound(ally.brain, brain.lastKnown);
              ally.pathTime = 0;
            }
          brain.callClock = 2.5;
        }
      }
    }
    brain.visibleTime = brain.visible ? brain.visibleTime + dt : 0;
    if (brain.visible) bot.reaction = Math.max(0, bot.reaction - dt);
    else bot.reaction = skill.reaction;
    if (brain.reload > 0) {
      brain.reload = Math.max(0, brain.reload - dt);
      if (!brain.reload) {
        brain.ammo = 30;
        brain.burst = 0;
        bot.shot = 0.25;
      }
    } else if (!brain.ammo) {
      brain.reload = 2.35;
      brain.hold = 2.6;
      brain.state = 'cover';
      if (brain.lastKnown) brain.cover = this.selectCover(bot, brain.lastKnown);
    }
    let goal: THREE.Vector3 | null = null;
    let look: THREE.Vector3 | null = null;
    if (brain.lastKnown && brain.memory > 0) {
      look = brain.lastKnown;
      if (brain.visible || brain.reload > 0 || brain.cover) {
        if (brain.decision <= 0) {
          brain.decision = 1.2 + brain.id * 0.17;
          if (
            !brain.cover ||
            brain.cover.peek.distanceTo(brain.lastKnown) < 4 ||
            !this.hasSight(
              brain.cover.peek.clone().setY(1.5),
              brain.lastKnown.clone().setY(1.2),
            )
          ) {
            brain.cover = this.selectCover(bot, brain.lastKnown);
          }
        }
        if (brain.cover) {
          if (
            brain.reload > 0 ||
            (bot.hp < 45 && brain.hold <= 0 && brain.state === 'peek')
          ) {
            brain.state = 'cover';
            brain.hold = Math.max(brain.hold, 1.1);
          } else if (brain.hold <= 0) {
            brain.state = brain.state === 'peek' ? 'cover' : 'peek';
            brain.hold =
              brain.state === 'peek'
                ? 1.5 + Math.random() * 0.6
                : 0.6 + Math.random() * 0.5;
          }
          goal = brain.state === 'cover' ? brain.cover.hide : brain.cover.peek;
          // A hold starts after reaching the position; distant cover must not
          // make the agent alternate destinations halfway through every move.
          if (pos.distanceTo(goal) > 0.32 && brain.hold > 0) brain.hold += dt;
        } else {
          brain.state = 'engage';
          const distance = pos.distanceTo(brain.lastKnown);
          // Close a long angle; stop to fire at useful range, then take a short sidestep between bursts.
          if (distance > 18) goal = brain.lastKnown;
          else if (bot.shot > 0.22 && brain.reload <= 0) {
            const angle =
              Math.atan2(brain.lastKnown.x - pos.x, brain.lastKnown.z - pos.z) +
              Math.PI / 2;
            const side =
              (brain.id % 2 ? 1 : -1) *
              Math.sign(Math.sin(this.elapsed * 0.9 + brain.id));
            const p = pos
              .clone()
              .add(
                new THREE.Vector3(
                  Math.sin(angle) * side * 0.9,
                  0,
                  Math.cos(angle) * side * 0.9,
                ),
              );
            if (this.canMoveTo(p.x, p.z, 0, 1.8, bot)) goal = p;
          }
        }
      } else {
        brain.state = 'search';
        brain.cover = null;
        if (pos.distanceTo(brain.lastKnown) > 0.85) goal = brain.lastKnown;
        else {
          brain.search += dt;
          const a =
            bot.root.rotation.y + Math.sin(brain.search * 2 + brain.id) * 0.035;
          look = pos
            .clone()
            .add(new THREE.Vector3(Math.sin(a) * 4, 0, Math.cos(a) * 4));
          if (brain.search > 2.2) brain.memory = 0;
        }
      }
    } else {
      brain.state = 'patrol';
      brain.lastKnown = null;
      brain.cover = null;
      const route = patrolRoutes[brain.id];
      const point = route[brain.patrol % route.length];
      goal = new THREE.Vector3(point[0], 0, point[1]);
      if (pos.distanceTo(goal) < 0.75) {
        brain.patrol++;
        goal = null;
      }
    }
    const move = new THREE.Vector3();
    if (goal && pos.distanceTo(goal) > 0.22) {
      if (
        !brain.goal ||
        brain.goal.distanceTo(goal) > 0.6 ||
        bot.pathTime <= 0
      ) {
        bot.path = this.findPath(pos, goal);
        bot.pathTime = 0.8 + brain.id * 0.11;
        brain.goal = goal.clone();
      }
      // Take a direct step only when both body-height rays clear the complete segment.
      if (
        this.hasSight(pos.clone().setY(0.7), goal.clone().setY(0.7)) &&
        this.hasSight(pos.clone().setY(1.6), goal.clone().setY(1.6))
      )
        move.copy(goal).sub(pos).setY(0);
      else if (bot.path.length) {
        if (bot.path[0].distanceTo(pos) < 0.2) bot.path.shift();
        if (bot.path.length) move.copy(bot.path[0]).sub(pos).setY(0);
      }
      if (move.lengthSq() > 0.001) move.normalize();
    } else {
      bot.path = [];
      brain.goal = null;
    }
    if (!look && move.lengthSq() > 0.001) look = pos.clone().add(move);
    if (look) {
      const yaw = Math.atan2(look.x - pos.x, look.z - pos.z);
      bot.root.rotation.y += THREE.MathUtils.clamp(
        angleDifference(yaw, bot.root.rotation.y),
        -skill.turn * dt,
        skill.turn * dt,
      );
    }
    const targetYaw = brain.lastKnown
      ? Math.atan2(brain.lastKnown.x - pos.x, brain.lastKnown.z - pos.z)
      : bot.root.rotation.y;
    const aimed =
      Math.abs(angleDifference(targetYaw, bot.root.rotation.y)) < 0.085;
    if (
      brain.visible &&
      aimed &&
      bot.reaction <= 0 &&
      bot.shot <= 0 &&
      !brain.reload &&
      brain.state !== 'cover'
    ) {
      // Counter-strafe before a burst. Subsequent shots keep the feet planted.
      move.set(0, 0, 0);
      this.botShoot(bot, pos.distanceTo(this.position));
    }
    if (brain.burst > 0 && bot.shot < 0.15 && brain.visible) move.set(0, 0, 0);
    const speed = brain.visible ? 1.65 : brain.memory > 0 ? 2.7 : 2.05;
    const previous = pos.clone();
    const step = move.clone().multiplyScalar(speed * dt);
    if (this.canMoveTo(pos.x + step.x, pos.z, 0, 1.8, bot)) pos.x += step.x;
    if (this.canMoveTo(pos.x, pos.z + step.z, 0, 1.8, bot)) pos.z += step.z;
    bot.moving = pos.distanceTo(previous) / dt;
    if (move.lengthSq() > 0.1 && bot.moving < 0.15) {
      brain.blocked += dt;
      // Yield sideways to another body and refresh the route instead of pushing forever.
      if (brain.blocked > 0.35) {
        const side = new THREE.Vector3(-move.z, 0, move.x).multiplyScalar(
          (brain.id % 2 ? 1 : -1) * 1.7 * dt,
        );
        if (this.canMoveTo(pos.x + side.x, pos.z + side.z, 0, 1.8, bot))
          pos.add(side);
        bot.pathTime = 0;
      }
      if (brain.blocked > 1.8) {
        brain.cover = null;
        brain.patrol++;
        brain.goal = null;
        brain.blocked = 0;
      }
    } else brain.blocked = 0;
    brain.steps -= dt;
    if (bot.moving > 0.6 && brain.steps <= 0) {
      const dist = pos.distanceTo(this.position);
      if (dist < 16) {
        const relative = pos.clone().sub(this.position).normalize();
        const pan = relative.dot(
          new THREE.Vector3(Math.cos(this.yaw), 0, -Math.sin(this.yaw)),
        );
        this.audio.enemyStep?.(dist, pan);
      }
      brain.steps = 0.43;
    }
    bot.weapon.rotation.x = brain.reload > 0 ? -0.32 : 0;
    bot.weapon.rotation.z = brain.reload > 0 ? -0.18 : 0;
    if (bot.mixer) {
      const name =
        bot.moving > 0.2
          ? bot.moving > 2.5 && bot.actions.run
            ? 'run'
            : 'walk'
          : 'idle';
      if (bot.animation !== name && bot.actions[name]) {
        bot.actions[bot.animation]?.fadeOut(0.16);
        bot.actions[name].reset().fadeIn(0.16).play();
        bot.animation = name;
      }
      if (bot.actions[name])
        bot.actions[name].timeScale =
          name === 'idle'
            ? 1
            : Math.max(0.55, bot.moving / (name === 'run' ? 3.8 : 1.5));
      bot.mixer.update(dt);
      this.syncBotPose(bot);
    } else
      for (let i = 0; i < bot.parts.length; i++)
        bot.parts[i].rotation.x =
          Math.sin(this.elapsed * 8 + bot.phase + i * Math.PI) *
          Math.min(bot.moving, 0.8) *
          0.45;
  }
  syncBotPose(bot: Bot) {
    bot.pose?.();
    if (bot.headBone) {
      const center = bot.root.worldToLocal(
        bot.headBone.getWorldPosition(new THREE.Vector3()),
      );
      center.y += 0.09;
      bot.proxies[1].position.copy(center);
      bot.proxies[1].scale.setScalar(0.85);
      bot.proxies[1].updateWorldMatrix(true, false);
    }
  }
  botShoot(bot: Bot, dist: number) {
    const brain = bot.brain,
      skill = skills[this.difficulty];
    if (brain.reload > 0 || !brain.ammo) return;
    const origin = bot.root.localToWorld(new THREE.Vector3(-0.1, 1.27, 1.06));
    // A visible head over a crate doesn't permit firing through the crate from a lower muzzle.
    const aim = this.position
      .clone()
      .add(new THREE.Vector3(0, this.eye * 0.73, 0));
    if (!this.hasSight(origin, aim)) {
      bot.shot = 0.15;
      return;
    }
    brain.ammo--;
    brain.burst++;
    brain.radarUntil = this.elapsed + 1.2;
    brain.radarPosition = bot.root.position.clone();
    if (brain.burst >= skill.burst) {
      brain.burst = 0;
      bot.shot = skill.pause * (0.85 + Math.random() * 0.3);
    } else bot.shot = 0.11;
    bot.light.intensity = 3;
    const error =
      dist *
      (skill.spread + bot.moving * 0.006) *
      Math.max(0.6, 1.25 - brain.visibleTime * 0.18);
    aim.x += (Math.random() + Math.random() - 1) * error;
    aim.y += (Math.random() + Math.random() - 1) * error * 0.7;
    aim.z += (Math.random() + Math.random() - 1) * error;
    const direction = aim.clone().sub(origin).normalize();
    this.ray.set(origin, direction);
    this.ray.far = 90;
    const wall = this.ray.intersectObjects(this.world.targets, false)[0];
    const body = new THREE.Box3(
      this.position.clone().add(new THREE.Vector3(-0.27, 0.06, -0.27)),
      this.position.clone().add(new THREE.Vector3(0.27, this.eye + 0.12, 0.27)),
    );
    const contact = this.ray.ray.intersectBox(body, new THREE.Vector3());
    const hit =
      contact && (!wall || origin.distanceTo(contact) < wall.distance);
    const end = hit
      ? contact
      : wall?.point || origin.clone().addScaledVector(direction, 60);
    this.tracer(origin, end, 0xffbe7b, 0.045);
    const relative = bot.root.position.clone().sub(this.position).normalize();
    const pan = relative.dot(
      new THREE.Vector3(Math.cos(this.yaw), 0, -Math.sin(this.yaw)),
    );
    this.audio.shot(false, dist, pan);
    if (hit) this.damagePlayer(18 + Math.floor(Math.random() * 6), bot.name);
  }
  damagePlayer(damage: number, name: string) {
    if (this.state.dead || this.protection > 0) return;
    const absorbed = Math.min(this.state.armor, Math.floor(damage * 0.45));
    this.state.armor -= absorbed;
    this.state.health = Math.max(0, this.state.health - (damage - absorbed));
    this.state.hurt = 0.52;
    this.audio.hurt();
    if (!this.state.health) {
      this.state.dead = true;
      this.state.deaths++;
      this.deathClock = 2.2;
      this.state.reloading = false;
      this.firing = false;
      this.state.feed.push({
        id: ++this.feedID,
        name,
        self: false,
        headshot: false,
      });
      this.state.feed = this.state.feed.slice(-4);
      this.feedClock = 4;
      this.updateCamera(0);
    }
  }
  respawnPlayer() {
    const options = spawnPoints
      .slice(0, 3)
      .map((p) => ({
        p,
        d: Math.min(
          ...this.bots
            .filter((b) => b.hp > 0)
            .map((b) =>
              Math.hypot(b.root.position.x - p[0], b.root.position.z - p[1]),
            ),
        ),
      }))
      .sort((a, b) => b.d - a.d);
    const p = options[0].p;
    this.position.set(p[0], 0, p[1]);
    this.velocity.set(0, 0, 0);
    this.pitch = this.recoilPitch = this.recoilYaw = 0;
    this.yaw = 0;
    this.eye = 1.65;
    this.state.health = 100;
    this.state.armor = 100;
    this.state.dead = false;
    this.protection = 2.5;
    this.inventory = [
      { ammo: 30, reserve: 90 },
      { ammo: 12, reserve: 48 },
    ];
    this.onGround = true;
    this.state.reloading = false;
    this.state.reloadProgress = 0;
    this.reloadClock =
      this.fireClock =
      this.muzzleClock =
      this.triggerClock =
      this.inspectClock =
        0;
    this.pressed = this.firing = false;
    this.reloadRequested = false;
    this.keys.clear();
    this.updateCamera(0);
    this.publish();
  }
  respawnBot(bot: Bot, initialIndex?: number) {
    let p = spawnPoints[initialIndex ?? 3];
    if (initialIndex === undefined) {
      const candidates = spawnPoints
        .slice(3)
        .filter((p) => canOccupy(p[0], p[1], 0, 1.8, this.world.solids, 0.4));
      const ranked = candidates
        .map((p) => ({
          p,
          score:
            Math.hypot(p[0] - this.position.x, p[1] - this.position.z) +
            (this.hasSight(
              new THREE.Vector3(p[0], 1.6, p[1]),
              this.camera.position,
            )
              ? 0
              : 20) +
            Math.random() * 5,
        }))
        .sort((a, b) => b.score - a.score);
      const free = ranked.find(
        ({ p }) =>
          !this.bots.some(
            (other) =>
              other !== bot &&
              other.hp > 0 &&
              Math.hypot(
                other.root.position.x - p[0],
                other.root.position.z - p[1],
              ) < 1.2,
          ),
      );
      p = (free || ranked[0]).p;
    }
    bot.root.position.set(p[0], 0, p[1]);
    bot.brain = createBrain(bot.brain.id);
    bot.root.rotation.set(0, 0, 0);
    bot.root.visible = true;
    bot.hp = 100;
    bot.dead = 0;
    bot.shot = 1.5;
    bot.reaction = 1.1;
    bot.path = [];
    bot.pathTime = 0.2 + Math.random() * 0.4;
  }
  findPath(from: THREE.Vector3, to: THREE.Vector3) {
    const index = (v: THREE.Vector3) =>
      Math.max(0, Math.min(64, Math.round(v.z + 32))) * 49 +
      Math.max(0, Math.min(48, Math.round(v.x + 24)));
    const nearest = (i: number) => {
      if (this.nav[i]) return i;
      for (let d = 1; d < 4; d++)
        for (let z = -d; z <= d; z++)
          for (let x = -d; x <= d; x++) {
            const n = i + z * 49 + x;
            if (n >= 0 && n < this.nav.length && this.nav[n]) return n;
          }
      return i;
    };
    const start = nearest(index(from)),
      goal = nearest(index(to));
    if (start === goal) return [new THREE.Vector3(to.x, 0, to.z)];
    const prev = new Int32Array(this.nav.length).fill(-1),
      queue = new Int32Array(this.nav.length);
    let read = 0,
      write = 1;
    queue[0] = start;
    prev[start] = start;
    while (read < write) {
      const n = queue[read++];
      if (n === goal) break;
      const x = n % 49,
        z = Math.floor(n / 49);
      const neighbors = [
        x > 0 ? n - 1 : -1,
        x < 48 ? n + 1 : -1,
        z > 0 ? n - 49 : -1,
        z < 64 ? n + 49 : -1,
      ];
      for (const next of neighbors)
        if (next >= 0 && this.nav[next] && prev[next] === -1) {
          prev[next] = n;
          queue[write++] = next;
        }
    }
    if (prev[goal] === -1) return [];
    const result: THREE.Vector3[] = [];
    let n = goal;
    while (n !== start) {
      result.push(new THREE.Vector3((n % 49) - 24, 0, Math.floor(n / 49) - 32));
      n = prev[n];
    }
    return result.reverse();
  }
  finish() {
    this.state.phase = 'ended';
    this.state.reloading = false;
    this.firing = this.pressed = false;
    this.reloadRequested = false;
    this.keys.clear();
    this.audio.finish();
    if (document.pointerLockElement === this.canvas) document.exitPointerLock();
    this.publish();
  }
  drawRadar() {
    const ctx = this.radar?.getContext('2d');
    if (!ctx) return;
    ctx.clearRect(0, 0, 192, 216);
    ctx.fillStyle = '#d7c99b11';
    ctx.fillRect(15, 8, 162, 200);
    const sx = (x: number) => 96 + x * 3.15,
      sz = (z: number) => 108 + z * 3.05;
    ctx.fillStyle = '#c8c4a644';
    ctx.strokeStyle = '#d8d0aa66';
    for (const s of this.world.solids) {
      ctx.fillRect(
        sx(s.x - s.w / 2),
        sz(s.z - s.d / 2),
        s.w * 3.15,
        s.d * 3.05,
      );
      ctx.strokeRect(
        sx(s.x - s.w / 2),
        sz(s.z - s.d / 2),
        s.w * 3.15,
        s.d * 3.05,
      );
    }
    ctx.fillStyle = '#e9b66e';
    ctx.font = 'bold 16px Arial';
    ctx.fillText('A', 74, 66);
    ctx.fillStyle = '#9bbdcb';
    ctx.fillText('B', 141, 148);
    if (this.state.phase !== 'menu')
      for (const b of this.bots) {
        if (b.hp <= 0) continue;
        if (
          seesDirection(
            this.yaw + Math.PI,
            this.position,
            b.root.position,
            100,
          ) &&
          this.hasSight(this.camera.position, b.root.position.clone().setY(1.4))
        ) {
          b.brain.radarUntil = this.elapsed + 0.6;
          b.brain.radarPosition = b.root.position.clone();
        }
        if (b.brain.radarUntil < this.elapsed || !b.brain.radarPosition)
          continue;
        ctx.fillStyle = '#dd865e';
        ctx.beginPath();
        ctx.arc(
          sx(b.brain.radarPosition.x),
          sz(b.brain.radarPosition.z),
          2.5,
          0,
          Math.PI * 2,
        );
        ctx.fill();
      }
    const p =
      this.state.phase === 'menu' ? this.camera.position : this.position;
    ctx.save();
    ctx.translate(sx(p.x), sz(p.z));
    ctx.rotate(-this.yaw);
    ctx.fillStyle = '#d7edb2';
    ctx.beginPath();
    ctx.moveTo(0, -6);
    ctx.lineTo(-4, 4);
    ctx.lineTo(4, 4);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }
  registerTools() {
    type Tool = {
      name: string;
      description: string;
      inputSchema: object;
      annotations: { readOnlyHint: boolean };
      execute: (input: unknown) => unknown;
    };
    const context = (
      document as Document & {
        modelContext?: {
          registerTool: (
            tool: Tool,
            options: { signal: AbortSignal },
          ) => unknown;
        };
      }
    ).modelContext;
    if (!context?.registerTool) return;
    const register = (tool: Tool) => {
      try {
        void Promise.resolve(
          context.registerTool(tool, { signal: this.webTools.signal }),
        ).catch(() => {});
      } catch {}
    };
    const empty = (input: unknown) => {
      if (
        input === null ||
        typeof input !== 'object' ||
        Array.isArray(input) ||
        Object.keys(input).length
      )
        throw new Error('Expected an empty object.');
    };
    register({
      name: 'get_training_status',
      description:
        'Read the current DUSTLINE training score, health, weapon and remaining time.',
      inputSchema: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
      annotations: { readOnlyHint: true },
      execute: (input) => {
        empty(input);
        return {
          phase: this.state.phase,
          kills: this.state.kills,
          target: 12,
          time: Math.ceil(this.state.time),
          health: this.state.health,
          weapon: this.state.weapon === 0 ? 'rifle' : 'pistol',
        };
      },
    });
    register({
      name: 'pause_training',
      description:
        'Pause the active DUSTLINE round and show its menu, preserving the score.',
      inputSchema: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
      annotations: { readOnlyHint: false },
      execute: (input) => {
        empty(input);
        if (this.state.phase !== 'playing')
          throw new Error('No active training round.');
        this.pause();
        return { phase: this.state.phase, kills: this.state.kills };
      },
    });
  }
  disposeObject(root: THREE.Object3D) {
    root.traverse((o) => {
      if (o instanceof THREE.Mesh) {
        o.geometry.dispose();
        const materials = Array.isArray(o.material) ? o.material : [o.material];
        for (const m of materials) {
          for (const v of Object.values(m))
            if (v instanceof THREE.Texture) v.dispose();
          m.dispose();
        }
      }
    });
  }
  dispose() {
    this.disposed = true;
    this.renderer.setAnimationLoop(null);
    this.listeners.abort();
    this.webTools.abort();
    if (document.pointerLockElement === this.canvas) document.exitPointerLock();
    this.audio.dispose();
    this.world.dispose();
    this.bots.forEach((b) => b.mixer?.stopAllAction());
    this.disposeObject(this.scene);
    this.disposeObject(this.viewScene);
    this.particleGeometry.dispose();
    this.shellGeometry.dispose();
    this.decalGeometry.dispose();
    this.dustMaterial.dispose();
    this.sparkMaterial.dispose();
    this.shellMaterial.dispose();
    this.decalMaterial.dispose();
    this.environment?.dispose();
    this.renderer.dispose();
  }
}
