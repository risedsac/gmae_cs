// Original synthesized effects. No recorded game audio is used.
export class GameAudio {
  context: AudioContext | null = null;
  master: GainNode | null = null;
  noise: AudioBuffer | null = null;
  volume = 0.65;
  wind: AudioBufferSourceNode | null = null;
  init() {
    if (!this.context) {
      this.context = new AudioContext();
      const c = this.context;
      this.master = c.createGain();
      this.master.gain.value = this.volume * 0.52;
      const comp = c.createDynamicsCompressor();
      comp.threshold.value = -12;
      comp.knee.value = 18;
      comp.ratio.value = 7;
      comp.attack.value = 0.002;
      comp.release.value = 0.16;
      this.master.connect(comp);
      comp.connect(c.destination);
      this.noise = c.createBuffer(1, c.sampleRate * 2, c.sampleRate);
      const d = this.noise.getChannelData(0);
      for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
      this.wind = c.createBufferSource();
      this.wind.buffer = this.noise;
      this.wind.loop = true;
      const f = c.createBiquadFilter();
      f.type = 'lowpass';
      f.frequency.value = 430;
      const g = c.createGain();
      g.gain.value = 0.035;
      this.wind.connect(f);
      f.connect(g);
      g.connect(this.master);
      this.wind.start();
    }
    void this.context.resume().catch(() => {});
  }
  setVolume(v: number) {
    this.volume = v;
    if (this.context && this.master)
      this.master.gain.setTargetAtTime(
        v * 0.52,
        this.context.currentTime,
        0.05,
      );
  }
  burst(
    t: number,
    len: number,
    volume: number,
    frequency: number,
    pan = 0,
    type: BiquadFilterType = 'lowpass',
  ) {
    if (!this.context || !this.master || !this.noise) return;
    const c = this.context,
      src = c.createBufferSource(),
      g = c.createGain(),
      filter = c.createBiquadFilter(),
      p = c.createStereoPanner();
    src.buffer = this.noise;
    filter.type = type;
    filter.frequency.setValueAtTime(frequency, t);
    filter.Q.value = 0.65;
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(Math.max(0.0002, volume), t + 0.002);
    g.gain.exponentialRampToValueAtTime(0.0001, t + len);
    p.pan.value = Math.max(-1, Math.min(1, pan));
    src.connect(filter);
    filter.connect(g);
    g.connect(p);
    p.connect(this.master);
    src.start(t, Math.random());
    src.stop(t + len + 0.02);
    src.onended = () => {
      src.disconnect();
      g.disconnect();
      filter.disconnect();
      p.disconnect();
    };
  }
  tone(
    t: number,
    len: number,
    volume: number,
    freq: number,
    end: number,
    type: OscillatorType = 'sine',
  ) {
    if (!this.context || !this.master) return;
    const c = this.context,
      o = c.createOscillator(),
      g = c.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, t);
    o.frequency.exponentialRampToValueAtTime(Math.max(10, end), t + len);
    g.gain.setValueAtTime(volume, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + len);
    o.connect(g);
    g.connect(this.master);
    o.start(t);
    o.stop(t + len + 0.01);
    o.onended = () => {
      o.disconnect();
      g.disconnect();
    };
  }
  shot(pistol = false, distance = 0, pan = 0) {
    if (!this.context) return;
    const t = this.context.currentTime,
      vol = distance ? Math.min(0.65, 7 / (distance + 5)) : 1;
    this.burst(t, 0.027, 0.7 * vol, 11000, pan, 'highpass');
    this.burst(
      t + 0.003,
      pistol ? 0.12 : 0.18,
      0.95 * vol,
      pistol ? 2500 : 1700,
      pan,
    );
    this.tone(t, 0.1, 0.54 * vol, pistol ? 180 : 120, 43);
    this.burst(t + 0.085, 0.18, 0.2 * vol, 1100, -pan * 0.4);
    this.burst(t + 0.2, 0.28, 0.085 * vol, 750, pan * 0.5);
    if (!distance) this.burst(t + 0.063, 0.026, 0.18, 4200, 0.4, 'highpass');
  }
  step(quiet = false, land = false) {
    if (!this.context) return;
    const t = this.context.currentTime;
    this.burst(
      t,
      land ? 0.16 : 0.085,
      (quiet ? 0.07 : 0.15) * (land ? 1.6 : 1),
      1900,
      0,
      'bandpass',
    );
    this.tone(t, 0.055, quiet ? 0.025 : 0.065, 115, 55);
  }
  enemyStep(distance: number, pan: number) {
    if (!this.context) return;
    const t = this.context.currentTime,
      volume = Math.max(0, 1 - distance / 17) * 0.13;
    this.burst(t, 0.075, volume, 1600, pan, 'bandpass');
    this.burst(t + 0.045, 0.045, volume * 0.45, 3200, pan, 'highpass');
  }
  mechanical(stage: number) {
    if (!this.context) return;
    const t = this.context.currentTime;
    this.burst(t, 0.035, 0.22, stage === 0 ? 2700 : 4800, 0, 'highpass');
    this.tone(t, 0.027, 0.06, stage === 0 ? 850 : 1650, 240, 'triangle');
    if (stage === 1) this.burst(t + 0.05, 0.045, 0.12, 1600);
  }
  impact(head = false) {
    if (!this.context) return;
    const t = this.context.currentTime;
    this.burst(t, 0.05, 0.23, head ? 3900 : 1000);
    if (head) this.tone(t, 0.08, 0.09, 1400, 700, 'triangle');
  }
  hurt() {
    if (this.context) {
      this.burst(this.context.currentTime, 0.12, 0.32, 750);
      this.tone(this.context.currentTime, 0.1, 0.15, 75, 30);
    }
  }
  finish() {
    if (!this.context) return;
    const t = this.context.currentTime;
    [440, 554, 660].forEach((f, i) =>
      this.tone(t + i * 0.12, 0.3, 0.1, f, f, 'triangle'),
    );
  }
  pause() {
    void this.context?.suspend().catch(() => {});
  }
  dispose() {
    this.wind?.stop();
    void this.context?.close().catch(() => {});
  }
}
