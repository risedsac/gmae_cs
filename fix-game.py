from pathlib import Path
p=Path('lib/game.ts');s=p.read_text()
def method(name,next_name,replacement):
 global s
 a=s.index('  '+name+'(');b=s.index('  '+next_name+'(',a);s=s[:a]+replacement+'\n'+s[b:]
s=s.replace("'menu' | 'playing' | 'paused' | 'ended'", "'menu' | 'ready' | 'playing' | 'paused' | 'ended'")
s=s.replace('  pressed = false;', '  pressed = false;\n  triggerClock = 0;\n  dragMode = false;\n  capturePending = false;\n  lookPointer: number | null = null;')
method('start','restart','''  start() {
    if (this.state.phase === 'playing') return;
    if (this.state.phase !== 'paused' && this.state.phase !== 'ready') this.reset();
    this.state.phase = 'ready';
    this.dragMode = false;
    this.keys.clear();
    this.firing = this.pressed = false;
    this.triggerClock = 0;
    try { this.audio.init(); } catch {}
    this.capture();
    this.publish();
  }
  startDragMode() {
    if (this.state.phase !== 'ready') return;
    this.dragMode = true;
    this.state.phase = 'playing';
    this.last = performance.now();
    try { this.audio.init(); } catch {}
    this.publish();
  }''')
s=s.replace('    this.fireClock = 0;\n    this.protection', '''    this.fireClock = this.muzzleClock = this.hitClock = this.feedClock = this.triggerClock = 0;
    this.reloadStage = -1;
    this.stepClock = 0;
    this.dragMode = false;
    this.capturePending = false;
    this.lookPointer = null;
    this.protection''')
s=s.replace('    this.effects.forEach((e) => this.scene.remove(e.mesh));', '''    this.effects.forEach((e) => {
      this.scene.remove(e.mesh);
      if (e.mesh instanceof THREE.Line) {
        e.mesh.geometry.dispose();
        (e.mesh.material as THREE.Material).dispose();
      }
    });''')
method('pause','capture','''  pause() {
    if (this.state.phase !== 'playing' && this.state.phase !== 'ready') return;
    this.state.phase = 'paused';
    this.keys.clear();
    this.firing = this.pressed = this.dragging = false;
    this.triggerClock = 0;
    this.lookPointer = null;
    this.audio.pause();
    if (document.pointerLockElement === this.canvas) document.exitPointerLock();
    this.publish();
  }''')
method('capture','setKey','''  capture() {
    if (this.state.phase !== 'ready' || this.capturePending) return;
    this.capturePending = true;
    const failed = () => {
      this.capturePending = false;
      this.state.locked = false;
      this.publish();
    };
    try {
      if (!this.canvas.requestPointerLock) { failed(); return; }
      const pending = this.canvas.requestPointerLock();
      if (pending && typeof pending.catch === 'function') pending.catch(failed);
    } catch { failed(); }
  }''')
method('setKey','setFire','''  setKey(key: string, value: boolean) {
    if (value && this.state.phase === 'playing' && !this.state.dead) this.keys.add(key);
    else this.keys.delete(key);
  }''')
method('setFire','bindInput','''  setFire(value: boolean) {
    if (this.state.phase !== 'playing' || this.state.dead) return;
    if (value && !this.firing) {
      this.pressed = true;
      this.triggerClock = .16;
    }
    this.firing = value;
  }''')
method('bindInput','switchWeapon','''  bindInput() {
    const opts = { signal: this.listeners.signal };
    window.addEventListener('resize', () => this.resize(), opts);
    document.addEventListener('pointerlockchange', () => {
      const was = this.state.locked;
      this.state.locked = document.pointerLockElement === this.canvas;
      this.capturePending = false;
      if (this.state.locked && this.state.phase === 'ready') {
        this.dragMode = false;
        this.state.phase = 'playing';
        this.last = performance.now();
      } else if (was && !this.state.locked && this.state.phase === 'playing') {
        this.pause();
      } else if (this.state.locked && this.state.phase !== 'playing') {
        document.exitPointerLock();
      }
      this.publish();
    }, opts);
    document.addEventListener('pointerlockerror', () => {
      this.capturePending = false;
      this.state.locked = false;
      this.publish();
    }, opts);
    document.addEventListener('keydown', e => {
      if (e.code === 'Escape') { this.pause(); return; }
      if (this.state.phase !== 'playing' || this.state.dead) return;
      if (['Space','ControlLeft','ControlRight','Tab','KeyW','KeyA','KeyS','KeyD','ShiftLeft','KeyR','KeyC'].includes(e.code)) e.preventDefault();
      if (!e.repeat) {
        if (e.code === 'KeyR') this.reload();
        if (e.code === 'Digit1') this.switchWeapon(0);
        if (e.code === 'Digit2') this.switchWeapon(1);
        if (e.code === 'KeyF' && !this.state.reloading) this.inspectClock = 2.25;
        if (e.code === 'Space' && this.onGround) {
          this.velocity.y = 5.3;
          this.onGround = false;
          this.audio.step(true);
        }
      }
      this.setKey(e.code, true);
    }, opts);
    document.addEventListener('keyup', e => this.setKey(e.code, false), opts);
    window.addEventListener('blur', () => { if (this.state.phase === 'playing') this.pause(); }, opts);
    document.addEventListener('visibilitychange', () => { if (document.hidden) this.pause(); }, opts);
    this.canvas.addEventListener('contextmenu', e => e.preventDefault(), opts);
    this.canvas.addEventListener('pointerdown', e => {
      if (this.state.phase !== 'playing' || this.state.dead) return;
      this.touchX = e.clientX;
      this.touchY = e.clientY;
      if (e.pointerType === 'touch' || e.button === 2) {
        this.dragging = true;
        this.lookPointer = e.pointerId;
        this.canvas.setPointerCapture(e.pointerId);
      }
      if (e.pointerType !== 'touch' && e.button === 0) this.setFire(true);
    }, opts);
    document.addEventListener('pointerup', e => {
      if (e.pointerType !== 'touch' && e.button === 0) this.setFire(false);
      if (e.pointerId === this.lookPointer && (e.pointerType === 'touch' || e.button === 2)) {
        this.dragging = false;
        this.lookPointer = null;
      }
    }, opts);
    document.addEventListener('pointercancel', e => {
      this.setFire(false);
      if (e.pointerId === this.lookPointer) { this.dragging = false; this.lookPointer = null; }
      this.keys.clear();
    }, opts);
    document.addEventListener('pointermove', e => {
      if (this.state.phase !== 'playing' || this.state.dead || (!this.state.locked && (!this.dragging || e.pointerId !== this.lookPointer))) return;
      const dx = this.state.locked ? e.movementX : e.clientX - this.touchX;
      const dy = this.state.locked ? e.movementY : e.clientY - this.touchY;
      this.touchX = e.clientX;
      this.touchY = e.clientY;
      this.yaw -= Math.max(-250, Math.min(250, dx)) * .0018 * this.sensitivity;
      this.pitch = THREE.MathUtils.clamp(this.pitch - Math.max(-250, Math.min(250, dy)) * .0018 * this.sensitivity, -1.42, 1.42);
    }, opts);
    this.canvas.addEventListener('wheel', e => {
      if (this.state.phase === 'playing') { e.preventDefault(); this.switchWeapon(1 - this.state.weapon); }
    }, { ...opts, passive: false });
  }''')
s=s.replace('    if (this.state.dead || this.state.weapon === index) return;', "    if (this.state.phase !== 'playing' || this.state.dead || ![0, 1].includes(index) || this.state.weapon === index) return;")
s=s.replace('    this.reloadClock = 0;\n    this.inspectClock = 0;\n    this.switchClock', '    this.reloadClock = 0;\n    this.state.reloadProgress = 0;\n    this.muzzleClock = 0;\n    this.pressed = false;\n    this.triggerClock = 0;\n    this.inspectClock = 0;\n    this.switchClock')
s=s.replace('    this.state.reloading = true;\n    this.reloadClock', '    this.state.reloading = true;\n    this.state.reloadProgress = 0;\n    this.reloadClock')
a=s.index('    const dt = Math.min(',s.index('  frame ='));b=s.index('    this.frames++;',a)
s=s[:a]+'''    const rawDelta = this.last ? Math.max(0, (time - this.last) / 1000) : 1 / 60;
    const dt = Math.min(.25, rawDelta);
    this.last = time;
    if (this.state.phase === 'playing' || this.state.phase === 'menu') this.elapsed += dt;
'''+s[b:]
s=s.replace('    this.fpsTime += dt;', '    this.fpsTime += rawDelta;')
s=s.replace("    if (this.state.phase === 'playing') this.update(dt);", "    if (this.state.phase === 'playing') {\n      const steps = Math.max(1, Math.ceil(dt * 60));\n      for (let step = 0; step < steps && this.state.phase === 'playing'; step++) this.update(dt / steps);\n    }")
s=s.replace('    this.fireClock -= dt;\n    this.muzzleClock', '    this.fireClock -= dt;\n    this.triggerClock = Math.max(0, this.triggerClock - dt);\n    if (this.triggerClock <= 0) this.pressed = false;\n    this.muzzleClock')
a=s.index('      if (\n        this.firing &&',s.index('  update(dt:'));b=s.index('\n    }',a)
s=s[:a]+'''      const trigger = this.state.weapon === 0 ? this.firing || this.pressed : this.pressed;
      if (trigger && this.fireClock <= 0) this.shoot();'''+s[b:]
s=s.replace('    inv.ammo--;\n    this.state.shots++;', '    inv.ammo--;\n    this.pressed = false;\n    this.triggerClock = 0;\n    this.state.shots++;')
s=s.replace('    this.inventory = [\n      { ammo: 30, reserve: 90 },\n      { ammo: 12, reserve: 48 },\n    ];\n    this.publish();\n  }\n  respawnBot', '''    this.inventory = [
      { ammo: 30, reserve: 90 },
      { ammo: 12, reserve: 48 },
    ];
    this.onGround = true;
    this.state.reloading = false;
    this.state.reloadProgress = 0;
    this.reloadClock = this.fireClock = this.muzzleClock = this.triggerClock = this.inspectClock = 0;
    this.pressed = this.firing = false;
    this.keys.clear();
    this.updateCamera(0);
    this.publish();
  }
  respawnBot''')
s=s.replace('      p = ranked[0].p;', '''      const free = ranked.find(({ p }) => !this.bots.some(other => other !== bot && other.hp > 0 && Math.hypot(other.root.position.x - p[0], other.root.position.z - p[1]) < 1.2));
      p = (free || ranked[0]).p;''')
p.write_text(s)
p=Path('app/page.tsx');s=p.read_text().replace("const playing = state.phase === 'playing',", "const awaitingControls = state.phase === 'ready',\n    playing = state.phase === 'playing' || awaitingControls,")
s=s.replace('          {!state.locked && !state.dead && (', "          {state.phase === 'playing' && !state.locked && !state.dead && (")
s=s.replace('''            <button
              className="capture-hint"
              onClick={() => game.current?.capture()}
            >
              点击画面锁定鼠标 · 如不支持，可按住左键拖动瞄准
            </button>''', '''            <div className="capture-hint">拖动模式：按住右键瞄准，左键射击</div>''')
s=s.replace('          <div className="touch-controls">', '          <div className="touch-controls" hidden={awaitingControls}>')
a=s.index('      {playing && (',s.index('          <div className="mobile-notice">'))
s=s[:a]+'''      {awaitingControls && <section className="ready-screen" aria-label="准备控制">
        <div className="ready-card">
          <Mouse size={28} />
          <h2>准备好再出发</h2>
          <p>锁定鼠标后开始计时。此时敌人不会攻击。</p>
          <button className="deploy-button" onClick={() => game.current?.capture()}>锁定鼠标并开始 <ArrowUpRight size={20}/></button>
          <button className="drag-start" onClick={() => game.current?.startDragMode()}>使用拖动模式开始</button>
          <small>当前窗口无法锁定鼠标时，可使用右键拖动瞄准、左键射击。触屏使用屏幕控件。</small>
        </div>
      </section>}
'''+s[a:]
p.write_text(s)
