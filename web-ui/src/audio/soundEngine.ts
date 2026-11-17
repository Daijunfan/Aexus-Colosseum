// Procedural Sci-Fi Esports Broadcast Sound FX Engine (Web Audio API — zero external assets)

import { VFXType } from '../types/pit';

class TacticalSoundEngine {
  private ctx: AudioContext | null = null;
  private enabled = false;
  private lastPlayedByType: Record<string, number> = {};

  public isEnabled(): boolean {
    return this.enabled;
  }

  public setEnabled(next: boolean): void {
    this.enabled = next;
    if (next) {
      this.ensureContext();
      this.playUiConfirm();
    }
  }

  public toggle(): boolean {
    this.setEnabled(!this.enabled);
    return this.enabled;
  }

  private ensureContext(): AudioContext | null {
    if (typeof window === 'undefined') return null;
    if (!this.ctx) {
      const AudioCtx =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (AudioCtx) {
        this.ctx = new AudioCtx();
      }
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume().catch(() => {});
    }
    return this.ctx;
  }

  private throttled(key: string, minGapMs: number): boolean {
    const now = performance.now();
    const prev = this.lastPlayedByType[key] ?? 0;
    if (now - prev < minGapMs) return true;
    this.lastPlayedByType[key] = now;
    return false;
  }

  public playUiConfirm(): void {
    const ctx = this.ensureContext();
    if (!ctx || !this.enabled) return;
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(640, now);
    osc.frequency.exponentialRampToValueAtTime(1180, now + 0.08);
    gain.gain.setValueAtTime(0.08, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.11);
    osc.connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.12);
  }

  public playVfx(vfx: VFXType): void {
    if (!this.enabled) return;
    switch (vfx) {
      case 'SONAR_SWEEP':
        this.playSonarPing();
        break;
      case 'ARMOR_PIERCING_BARRAGE':
        this.playBarrageBurst();
        break;
      case 'PRECISION_EXPLOIT_BEAM':
      case 'SSL_CLEARTEXT_INTERCEPT':
        this.playPrecisionBeam();
        break;
      case 'RCE_PARASITE_BREACH':
      case 'GRAIL_HEART_STOLEN':
        this.playRceImpact();
        break;
      case 'REVERSE_SHELL_CHAIN':
        this.playChainClank();
        break;
      case 'NANO_PATCH_WELD':
        this.playWeldSpark();
        break;
      case 'ROOT_SHOCKWAVE':
        this.playFirstBloodSubBass();
        break;
    }
  }

  // Submarine / orbital radar resonant ping
  public playSonarPing(): void {
    if (!this.enabled || this.throttled('sonar', 700)) return;
    const ctx = this.ensureContext();
    if (!ctx) return;
    const now = ctx.currentTime;

    const osc = ctx.createOscillator();
    const filter = ctx.createBiquadFilter();
    const gain = ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(1046, now);
    osc.frequency.exponentialRampToValueAtTime(784, now + 0.36);

    filter.type = 'bandpass';
    filter.frequency.setValueAtTime(1000, now);
    filter.Q.setValueAtTime(8, now);

    gain.gain.setValueAtTime(0.001, now);
    gain.gain.linearRampToValueAtTime(0.11, now + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.0008, now + 0.42);

    osc.connect(filter).connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.45);
  }

  // Rapid kinetic armor-piercing tracer pulses
  public playBarrageBurst(): void {
    if (!this.enabled || this.throttled('barrage', 450)) return;
    const ctx = this.ensureContext();
    if (!ctx) return;
    const base = ctx.currentTime;

    for (let i = 0; i < 3; i++) {
      const t = base + i * 0.045;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(420 - i * 35, t);
      osc.frequency.exponentialRampToValueAtTime(110, t + 0.038);
      gain.gain.setValueAtTime(0.075, t);
      gain.gain.exponentialRampToValueAtTime(0.001, t + 0.04);
      osc.connect(gain).connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.042);
    }
  }

  // High-energy railgun beam
  public playPrecisionBeam(): void {
    if (!this.enabled || this.throttled('beam', 550)) return;
    const ctx = this.ensureContext();
    if (!ctx) return;
    const now = ctx.currentTime;

    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(880, now);
    osc.frequency.exponentialRampToValueAtTime(190, now + 0.22);

    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(2400, now);
    filter.frequency.exponentialRampToValueAtTime(400, now + 0.22);

    gain.gain.setValueAtTime(0.08, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.24);

    osc.connect(filter).connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.25);
  }

  // Heavy RCE breach transient
  public playRceImpact(): void {
    if (!this.enabled || this.throttled('rce', 800)) return;
    const ctx = this.ensureContext();
    if (!ctx) return;
    const now = ctx.currentTime;

    // Sub impact
    const sub = ctx.createOscillator();
    const subGain = ctx.createGain();
    sub.type = 'sine';
    sub.frequency.setValueAtTime(135, now);
    sub.frequency.exponentialRampToValueAtTime(34, now + 0.42);
    subGain.gain.setValueAtTime(0.22, now);
    subGain.gain.exponentialRampToValueAtTime(0.001, now + 0.45);
    sub.connect(subGain).connect(ctx.destination);
    sub.start(now);
    sub.stop(now + 0.46);

    // Metallic crunch
    const crunch = ctx.createOscillator();
    const crunchGain = ctx.createGain();
    crunch.type = 'square';
    crunch.frequency.setValueAtTime(290, now);
    crunch.frequency.exponentialRampToValueAtTime(72, now + 0.16);
    crunchGain.gain.setValueAtTime(0.08, now);
    crunchGain.gain.exponentialRampToValueAtTime(0.001, now + 0.18);
    crunch.connect(crunchGain).connect(ctx.destination);
    crunch.start(now);
    crunch.stop(now + 0.19);
  }

  // Metallic barbed chain latch clank (Reverse Shell Hooked)
  public playChainClank(): void {
    if (!this.enabled || this.throttled('chain', 900)) return;
    const ctx = this.ensureContext();
    if (!ctx) return;
    const base = ctx.currentTime;

    const freqs = [1420, 1960, 1180];
    freqs.forEach((f, idx) => {
      const t = base + idx * 0.055;
      const osc = ctx.createOscillator();
      const hp = ctx.createBiquadFilter();
      const gain = ctx.createGain();
      osc.type = 'square';
      osc.frequency.setValueAtTime(f, t);
      osc.frequency.exponentialRampToValueAtTime(f * 0.55, t + 0.09);
      hp.type = 'highpass';
      hp.frequency.setValueAtTime(700, t);
      gain.gain.setValueAtTime(0.07, t);
      gain.gain.exponentialRampToValueAtTime(0.001, t + 0.1);
      osc.connect(hp).connect(gain).connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.11);
    });
  }

  // Electric cyan Nano-Patch plasma weld spark + harmonic heal chime
  public playWeldSpark(): void {
    if (!this.enabled || this.throttled('weld', 800)) return;
    const ctx = this.ensureContext();
    if (!ctx) return;
    const now = ctx.currentTime;

    // White noise spark buffer
    const bufferSize = Math.floor(ctx.sampleRate * 0.18);
    const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      data[i] = (Math.random() * 2 - 1) * Math.exp(-i / (bufferSize * 0.35));
    }
    const noise = ctx.createBufferSource();
    noise.buffer = buffer;

    const bp = ctx.createBiquadFilter();
    bp.type = 'bandpass';
    bp.frequency.setValueAtTime(3400, now);
    bp.Q.setValueAtTime(3.5, now);

    const nGain = ctx.createGain();
    nGain.gain.setValueAtTime(0.12, now);
    nGain.gain.exponentialRampToValueAtTime(0.001, now + 0.18);
    noise.connect(bp).connect(nGain).connect(ctx.destination);
    noise.start(now);

    // Ascending cyan harmonic
    const chime = ctx.createOscillator();
    const cGain = ctx.createGain();
    chime.type = 'triangle';
    chime.frequency.setValueAtTime(587.33, now + 0.04); // D5
    chime.frequency.exponentialRampToValueAtTime(1174.66, now + 0.28); // D6
    cGain.gain.setValueAtTime(0.09, now + 0.04);
    cGain.gain.exponentialRampToValueAtTime(0.001, now + 0.32);
    chime.connect(cGain).connect(ctx.destination);
    chime.start(now + 0.04);
    chime.stop(now + 0.33);
  }

  // Urgent ICU medical ECG flatline alarm
  public playFlatlineAlarm(): void {
    if (!this.enabled || this.throttled('flatline', 2200)) return;
    const ctx = this.ensureContext();
    if (!ctx) return;
    const now = ctx.currentTime;

    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(988, now);
    gain.gain.setValueAtTime(0.001, now);
    gain.gain.linearRampToValueAtTime(0.11, now + 0.02);
    gain.gain.setValueAtTime(0.11, now + 0.52);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.62);

    osc.connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.64);
  }

  // First Blood / Root Shockwave stadium sub-bass drop + golden brass fifth
  public playFirstBloodSubBass(): void {
    if (!this.enabled || this.throttled('firstblood', 1400)) return;
    const ctx = this.ensureContext();
    if (!ctx) return;
    const now = ctx.currentTime;

    const sub = ctx.createOscillator();
    const subGain = ctx.createGain();
    sub.type = 'sine';
    sub.frequency.setValueAtTime(92, now);
    sub.frequency.exponentialRampToValueAtTime(27.5, now + 0.75);
    subGain.gain.setValueAtTime(0.28, now);
    subGain.gain.exponentialRampToValueAtTime(0.001, now + 0.8);
    sub.connect(subGain).connect(ctx.destination);
    sub.start(now);
    sub.stop(now + 0.82);

    [220, 329.63, 440].forEach((freq) => {
      const horn = ctx.createOscillator();
      const filter = ctx.createBiquadFilter();
      const hGain = ctx.createGain();
      horn.type = 'sawtooth';
      horn.frequency.setValueAtTime(freq, now);
      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(1100, now);
      filter.frequency.exponentialRampToValueAtTime(320, now + 0.65);
      hGain.gain.setValueAtTime(0.045, now);
      hGain.gain.exponentialRampToValueAtTime(0.001, now + 0.68);
      horn.connect(filter).connect(hGain).connect(ctx.destination);
      horn.start(now);
      horn.stop(now + 0.7);
    });
  }

  // Rising harmonic combo chord (C-E-G-B or power fifth arpeggio)
  public playComboChord(multiplier = 2): void {
    if (!this.enabled || this.throttled('combo', 700)) return;
    const ctx = this.ensureContext();
    if (!ctx) return;
    const base = ctx.currentTime;
    const notes = multiplier >= 3 ? [523.25, 659.25, 783.99, 1046.5] : [440, 554.37, 659.25];
    notes.forEach((freq, idx) => {
      const t = base + idx * 0.045;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, t);
      gain.gain.setValueAtTime(0.08, t);
      gain.gain.exponentialRampToValueAtTime(0.001, t + 0.28);
      osc.connect(gain).connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.3);
    });
  }

  // Sapphire hexagonal forcefield ricochet ping
  public playShieldDeflect(): void {
    if (!this.enabled || this.throttled('deflect', 500)) return;
    const ctx = this.ensureContext();
    if (!ctx) return;
    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(1680, now);
    osc.frequency.exponentialRampToValueAtTime(620, now + 0.14);
    gain.gain.setValueAtTime(0.09, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.16);
    osc.connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.17);
  }
}

export const soundEngine = new TacticalSoundEngine();
