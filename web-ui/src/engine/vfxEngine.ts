// 60fps Command-Signature & Tactical Combo Synergy VFX Engine for Aexus Colosseum
// Pure HTML5 Canvas procedural renderer tuned for crisp Apple-Light architectural telemetry.

import { EbpfEvent, MatchState, SeatState, TargetFortress } from '../types/pit';

export type WeaponArchetype =
  | 'SONAR_SCAN'
  | 'HTTP_PHOTON'
  | 'SQLI_SWARM'
  | 'NEURAL_HELIX'
  | 'TESLA_RCE'
  | 'SYPHON_CHAIN'
  | 'GRAIL_TRACTOR'
  | 'ROOT_SUPERNOVA'
  | 'NANO_WELD'
  | 'SHIELD_DEFLECT'
  | 'PRISM_CRED'
  | 'AI_THINK_ORBIT';

export type ComboID =
  | 'LOCK_ON_STRIKE'
  | 'VAULT_MELTDOWN'
  | 'NEURAL_MIND_HACK'
  | 'PARASITE_GODSLAYER'
  | 'SOVEREIGN_IRON_CURTAIN'
  | 'TRIPLE_AEGIS'
  | 'TRI_VECTOR_OVERLOAD'
  | 'CROSSFIRE_VORTEX';

export interface WeaponMeta {
  archetype: WeaponArchetype;
  tag: string;
  zhLabel: string;
  color: string;
  glow: string;
  durationMs: number;
}

export const WEAPON_META: Record<WeaponArchetype, WeaponMeta> = {
  SONAR_SCAN: {
    archetype: 'SONAR_SCAN',
    tag: 'SONAR',
    zhLabel: 'nmap 声呐扫描',
    color: '#0284C7',
    glow: 'rgba(2, 132, 199, 0.35)',
    durationMs: 2400,
  },
  HTTP_PHOTON: {
    archetype: 'HTTP_PHOTON',
    tag: 'HTTP',
    zhLabel: 'curl 光子穿刺',
    color: '#007AFF',
    glow: 'rgba(0, 122, 255, 0.35)',
    durationMs: 2100,
  },
  SQLI_SWARM: {
    archetype: 'SQLI_SWARM',
    tag: 'SQLI',
    zhLabel: 'sqlmap 破甲蜂群弹幕',
    color: '#EA580C',
    glow: 'rgba(234, 88, 12, 0.40)',
    durationMs: 2600,
  },
  NEURAL_HELIX: {
    archetype: 'NEURAL_HELIX',
    tag: 'PROMPT',
    zhLabel: 'Prompt 神经双螺旋',
    color: '#9333EA',
    glow: 'rgba(147, 51, 234, 0.42)',
    durationMs: 2600,
  },
  TESLA_RCE: {
    archetype: 'TESLA_RCE',
    tag: 'RCE',
    zhLabel: 'RCE 特斯拉闪电',
    color: '#DC2E33',
    glow: 'rgba(220, 46, 51, 0.50)',
    durationMs: 2400,
  },
  SYPHON_CHAIN: {
    archetype: 'SYPHON_CHAIN',
    tag: 'REVSHELL',
    zhLabel: '反向 Shell 虹吸锁链',
    color: '#DC2E33',
    glow: 'rgba(220, 46, 51, 0.45)',
    durationMs: 3000,
  },
  GRAIL_TRACTOR: {
    archetype: 'GRAIL_TRACTOR',
    tag: 'GRAIL',
    zhLabel: '圣杯晶体牵引光束',
    color: '#D97706',
    glow: 'rgba(245, 158, 11, 0.50)',
    durationMs: 2900,
  },
  ROOT_SUPERNOVA: {
    archetype: 'ROOT_SUPERNOVA',
    tag: 'ROOT',
    zhLabel: 'UID=0 超新星核爆波',
    color: '#DC2E33',
    glow: 'rgba(245, 158, 11, 0.55)',
    durationMs: 2600,
  },
  NANO_WELD: {
    archetype: 'NANO_WELD',
    tag: 'PATCH',
    zhLabel: '纳米热补丁六角焊盾',
    color: '#007AFF',
    glow: 'rgba(16, 185, 129, 0.45)',
    durationMs: 2700,
  },
  SHIELD_DEFLECT: {
    archetype: 'SHIELD_DEFLECT',
    tag: 'DEFLECT',
    zhLabel: '艾吉斯护盾物理弹反',
    color: '#0EA5E9',
    glow: 'rgba(14, 165, 233, 0.48)',
    durationMs: 2100,
  },
  PRISM_CRED: {
    archetype: 'PRISM_CRED',
    tag: 'CRED',
    zhLabel: '凭据棱镜折射光束',
    color: '#7C3AED',
    glow: 'rgba(124, 58, 237, 0.40)',
    durationMs: 2100,
  },
  AI_THINK_ORBIT: {
    archetype: 'AI_THINK_ORBIT',
    tag: 'THINK',
    zhLabel: 'DeepSeek 突触思考',
    color: '#6366F1',
    glow: 'rgba(99, 102, 241, 0.35)',
    durationMs: 1400,
  },
};

export interface ActiveComboBanner {
  id: string;
  comboId: ComboID;
  multiplier: number;
  title: string;
  subtitle: string;
  actorName: string;
  color: string;
  createdAt: number;
  durationMs: number;
}

interface ProjectileFX {
  id: string;
  archetype: WeaponArchetype;
  seatId: string;
  seatName: string;
  seatColor: string;
  targetId: string;
  label: string;
  cmdline: string;
  createdAt: number;
  durationMs: number;
  seed: number;
  isLockOn?: boolean;
  isGodslayer?: boolean;
}

interface Particle {
  nx: number;
  ny: number;
  vx: number;
  vy: number;
  radius: number;
  color: string;
  alpha: number;
  decay: number;
  kind: 'spark' | 'ring' | 'shard' | 'glyph';
  glyph?: string;
}

interface ShockwaveFX {
  nx: number;
  ny: number;
  maxRadiusNorm: number;
  color: string;
  secondaryColor?: string;
  lineWidth: number;
  createdAt: number;
  durationMs: number;
  badgeText?: string;
}

interface FloatingBadgeFX {
  nx: number;
  ny: number;
  text: string;
  color: string;
  createdAt: number;
  durationMs: number;
}

interface ImpactArcFX {
  seatId: string;
  targetId: string;
  color: string;
  createdAt: number;
  durationMs: number;
}

interface SeatHistoryEntry {
  archetype: WeaponArchetype;
  ts: number;
}

export function classifyEventArchetype(evt: EbpfEvent): WeaponArchetype {
  const cmd = `${evt.cmdline ?? ''} ${evt.cleartext_payload ?? ''} ${evt.hit_location ?? ''}`.toLowerCase();
  const probe = (evt.probe ?? '').toLowerCase();

  if (cmd.includes('/pit/bin/prompt-inject') || cmd.includes('/api/vault/chat')) {
    return 'NEURAL_HELIX';
  }
  if (cmd.includes('/pit/bin/sqlmap') || cmd.includes('/api/ledger/search') || cmd.includes('flag-vault')) {
    return 'SQLI_SWARM';
  }
  if (cmd.includes('/pit/bin/git-patch') || evt.vfx_type === 'NANO_PATCH_WELD') {
    return 'NANO_WELD';
  }
  if (cmd.includes('/diagnostics/ping') || cmd.includes('rce_ping')) {
    return 'TESLA_RCE';
  }
  if (cmd.includes('/etc/shadow') || cmd.includes('.env') || cmd.includes('id_rsa')) {
    return 'PRISM_CRED';
  }
  if (cmd.includes('/pit/bin/nmap') || evt.vfx_type === 'SONAR_SWEEP') {
    return 'SONAR_SCAN';
  }

  switch (evt.vfx_type) {
    case 'ARMOR_PIERCING_BARRAGE':
      return 'SQLI_SWARM';
    case 'SSL_CLEARTEXT_INTERCEPT':
      return 'NEURAL_HELIX';
    case 'RCE_PARASITE_BREACH':
      return 'TESLA_RCE';
    case 'REVERSE_SHELL_CHAIN':
      return 'SYPHON_CHAIN';
    case 'GRAIL_HEART_STOLEN':
      return 'GRAIL_TRACTOR';
    case 'ROOT_SHOCKWAVE':
      return 'ROOT_SUPERNOVA';
    default:
      if (probe.includes('commit_creds')) return 'ROOT_SUPERNOVA';
      if (probe.includes('ssl')) return 'NEURAL_HELIX';
      return 'HTTP_PHOTON';
  }
}

export function archetypeFromTerminalLine(text: string): {
  archetype: WeaponArchetype | null;
  cmdLabel: string;
} {
  const low = text.toLowerCase();
  if (low.includes('[blocked:')) {
    const vecMatch = /\[blocked:([a-z0-9_]+)\]/i.exec(text);
    return {
      archetype: 'SHIELD_DEFLECT',
      cmdLabel: `🛡️ ${vecMatch?.[1] ?? 'attack'} 被热补丁弹反`,
    };
  }
  if (low.includes('git-patch') || low.includes('[nano_weld]')) {
    return { archetype: 'NANO_WELD', cmdLabel: '$ git-patch 纳米热修复' };
  }
  if (low.includes('sqlmap') || low.includes('sqli_ledger')) {
    return { archetype: 'SQLI_SWARM', cmdLabel: '$ sqlmap /api/ledger/search' };
  }
  if (low.includes('prompt-inject') || low.includes('prompt_chat')) {
    return { archetype: 'NEURAL_HELIX', cmdLabel: '$ prompt-inject /vault/chat' };
  }
  if (low.includes('rce_ping') || low.includes('/diagnostics/ping')) {
    return { archetype: 'TESLA_RCE', cmdLabel: '$ curl RCE /diagnostics/ping' };
  }
  return { archetype: null, cmdLabel: '' };
}

export class ColosseumVFXEngine {
  private initialized = false;
  private seenEvents = new Set<string>();
  private seenTerminals = new Set<string>();
  private projectiles: ProjectileFX[] = [];
  private particles: Particle[] = [];
  private shockwaves: ShockwaveFX[] = [];
  private badges: FloatingBadgeFX[] = [];
  private impactArcs: ImpactArcFX[] = [];
  private comboBanners: ActiveComboBanner[] = [];
  private seatHistory: Record<string, SeatHistoryEntry[]> = {};
  private globalRecentHits: { seatId: string; seatColor: string; ts: number }[] = [];
  private comboCooldowns: Record<string, number> = {};
  public seatComboState: Record<string, { multiplier: number; label: string; untilMs: number }> = {};
  public seatLastCmd: Record<string, { text: string; color: string; untilMs: number }> = {};
  public hexShieldUntilMs = 0;
  public tripleAegisUntilMs = 0;
  public crossfireVortexUntilMs = 0;
  public spotlightUntilMs = 0;
  public shakeEnergy = 0;
  public organFlashUntil: Record<string, { color: string; untilMs: number }> = {};
  private onComboCallback?: (combo: ActiveComboBanner) => void;

  public setComboListener(cb: (combo: ActiveComboBanner) => void): void {
    this.onComboCallback = cb;
  }

  public dispose(): void {
    this.projectiles = [];
    this.particles = [];
    this.shockwaves = [];
    this.badges = [];
    this.impactArcs = [];
    this.comboBanners = [];
  }

  public getActiveBanners(now: number): ActiveComboBanner[] {
    this.comboBanners = this.comboBanners.filter((b) => now - b.createdAt < b.durationMs);
    return this.comboBanners;
  }

  public ingestMatchState(match: MatchState): void {
    if (match.status === 'completed' || match.status === 'finished') {
      this.dispose();
      this.seatLastCmd = {};
      this.seatComboState = {};
      this.shakeEnergy = 0;
      return;
    }

    const now = performance.now();
    const wallNow = Date.now();
    const isInitial = !this.initialized;
    this.initialized = true;

    const seatById: Record<string, SeatState> = {};
    match.seats.forEach((s) => {
      seatById[s.id] = s;
    });

    // If any target already has patched organs, sustain subtle Aegis shimmer
    const primaryTarget = match.targets[0];
    if (match.targets.some((tg) => tg.organs.some((o) => o.state === 'patched'))) {
      this.hexShieldUntilMs = Math.max(this.hexShieldUntilMs, now + 3500);
    }

    // Ingest new eBPF kernel events (newest first in match.events)
    const freshEvents = [...match.events].reverse();
    for (const evt of freshEvents) {
      if (this.seenEvents.has(evt.id)) continue;
      this.seenEvents.add(evt.id);
      if (this.seenEvents.size > 500) {
        const first = this.seenEvents.values().next().value;
        if (first) this.seenEvents.delete(first);
      }
      if (isInitial && wallNow - evt.ts_ms > 2800) {
        continue;
      }

      const seat = seatById[evt.source_seat_id] ?? match.seats[0];
      if (!seat) continue;

      const evtTarget = match.targets.find((tg) => tg.id === evt.target_id) ?? primaryTarget;
      const arch = classifyEventArchetype(evt);
      this.spawnEffect(arch, seat, evtTarget, evt.cmdline || WEAPON_META[arch].zhLabel, now, evt.organ_layer);
    }

    // Ingest live terminal entries for BLOCKED shield ricochets & high-level command badges
    Object.entries(match.terminals).forEach(([sid, entries]) => {
      const seat = seatById[sid];
      if (!seat) return;
      for (const entry of entries) {
        if (this.seenTerminals.has(entry.id)) continue;
        this.seenTerminals.add(entry.id);
        if (this.seenTerminals.size > 400) {
          const first = this.seenTerminals.values().next().value;
          if (first) this.seenTerminals.delete(first);
        }
        if (isInitial && wallNow - entry.ts_ms > 2800) continue;

        const { archetype, cmdLabel } = archetypeFromTerminalLine(entry.text);
        if (archetype === 'SHIELD_DEFLECT') {
          this.spawnEffect('SHIELD_DEFLECT', seat, primaryTarget, cmdLabel, now, 'code_organ');
        } else if (archetype && cmdLabel) {
          this.seatLastCmd[seat.id] = {
            text: cmdLabel,
            color: WEAPON_META[archetype].color,
            untilMs: now + 3800,
          };
          if (archetype === 'NANO_WELD' || archetype === 'SQLI_SWARM' || archetype === 'NEURAL_HELIX') {
            this.spawnEffect(archetype, seat, primaryTarget, cmdLabel, now);
          }
        }
      }
    });
  }

  private spawnEffect(
    archetype: WeaponArchetype,
    seat: SeatState,
    target: TargetFortress | undefined,
    label: string,
    now: number,
    organLayer?: string
  ): void {
    const meta = WEAPON_META[archetype];
    const seed = Math.abs((seat.id.charCodeAt(seat.id.length - 1) * 97 + Math.floor(now * 13)) % 997);

    // Directional impact arc on target fortress facing attacker seat
    this.impactArcs.push({
      seatId: seat.id,
      targetId: target?.id ?? 'target-grail',
      color: meta.color,
      createdAt: now,
      durationMs: 950,
    });
    if (this.impactArcs.length > 18) {
      this.impactArcs = this.impactArcs.slice(-18);
    }

    // Seat recent command badge
    this.seatLastCmd[seat.id] = {
      text: label.length > 34 ? `${label.slice(0, 33)}…` : label,
      color: meta.color,
      untilMs: now + 3200,
    };

    if (organLayer) {
      this.organFlashUntil[organLayer] = {
        color: meta.color,
        untilMs: now + 1500,
      };
    }

    // Track per-seat combo history (20s window) & check combos BEFORE pushing current projectile
    const seatHist = (this.seatHistory[seat.id] ?? []).filter((h) => now - h.ts < 20000);
    seatHist.push({ archetype, ts: now });
    this.seatHistory[seat.id] = seatHist;

    this.globalRecentHits = this.globalRecentHits.filter((g) => now - g.ts < 3500);
    this.globalRecentHits.push({ seatId: seat.id, seatColor: seat.team_color, ts: now });

    const comboHit = this.evaluateCombos(seat, seatHist, now);

    this.projectiles.push({
      id: `pfx-${Math.floor(now * 100)}-${Math.random().toString(36).slice(2, 6)}`,
      archetype,
      seatId: seat.id,
      seatName: seat.name,
      seatColor: seat.team_color,
      targetId: target?.id ?? 'target-grail',
      label: meta.zhLabel,
      cmdline: label,
      createdAt: now,
      durationMs: meta.durationMs,
      seed,
      isLockOn: comboHit?.comboId === 'LOCK_ON_STRIKE',
      isGodslayer: comboHit?.comboId === 'PARASITE_GODSLAYER',
    });
    if (this.projectiles.length > 36) {
      this.projectiles = this.projectiles.slice(-36);
    }

    // Specialized environment bursts
    if (archetype === 'TESLA_RCE') {
      this.shakeEnergy = Math.max(this.shakeEnergy, 4.2);
      this.emitNormalizedBurst(0, 0, 26, '#DC2E33', '#FCA5A5', 'spark', 1.0);
      this.shockwaves.push({
        nx: 0,
        ny: 0,
        maxRadiusNorm: 0.42,
        color: '#DC2E33',
        lineWidth: 2.6,
        createdAt: now,
        durationMs: 950,
      });
    } else if (archetype === 'ROOT_SUPERNOVA') {
      this.shakeEnergy = Math.max(this.shakeEnergy, 6.0);
      this.emitNormalizedBurst(0, 0, 38, '#DC2E33', '#F59E0B', 'spark', 1.35);
      this.shockwaves.push(
        {
          nx: 0,
          ny: 0,
          maxRadiusNorm: 0.96,
          color: '#DC2E33',
          secondaryColor: '#F59E0B',
          lineWidth: 3.5,
          createdAt: now,
          durationMs: 1450,
          badgeText: '⚡ UID=0 ROOT OVERRIDE',
        },
        {
          nx: 0,
          ny: 0,
          maxRadiusNorm: 0.7,
          color: '#F59E0B',
          lineWidth: 2.2,
          createdAt: now + 120,
          durationMs: 1150,
        }
      );
    } else if (archetype === 'NANO_WELD') {
      this.hexShieldUntilMs = Math.max(this.hexShieldUntilMs, now + 6500);
      this.emitNormalizedBurst(0, 0, 22, '#007AFF', '#10B981', 'spark', 0.85);
      this.shockwaves.push({
        nx: 0,
        ny: 0,
        maxRadiusNorm: 0.36,
        color: '#007AFF',
        secondaryColor: '#10B981',
        lineWidth: 2.4,
        createdAt: now,
        durationMs: 900,
      });
    } else if (archetype === 'SHIELD_DEFLECT') {
      this.hexShieldUntilMs = Math.max(this.hexShieldUntilMs, now + 5000);
      this.emitNormalizedBurst(0, 0, 18, '#0EA5E9', '#FFFFFF', 'shard', 0.95);
      this.badges.push({
        nx: 0,
        ny: -0.26,
        text: '🛡️ 热补丁护盾弹反 BLOCKED',
        color: '#0284C7',
        createdAt: now,
        durationMs: 1650,
      });
    } else if (archetype === 'SQLI_SWARM') {
      this.emitNormalizedBurst(0, 0, 16, '#EA580C', '#FBBF24', 'shard', 0.78);
    } else if (archetype === 'NEURAL_HELIX') {
      this.emitNormalizedBurst(0, 0, 14, '#9333EA', '#EC4899', 'glyph', 0.72);
    } else if (archetype === 'GRAIL_TRACTOR') {
      this.emitNormalizedBurst(0, 0, 24, '#F59E0B', '#FEF08A', 'shard', 1.0);
    }
  }

  private evaluateCombos(
    seat: SeatState,
    hist: SeatHistoryEntry[],
    now: number
  ): ActiveComboBanner | null {
    const recentSet = new Set(hist.map((h) => h.archetype));
    const latest = hist[hist.length - 1]?.archetype;
    const prev = hist.length >= 2 ? hist[hist.length - 2]?.archetype : undefined;

    const tryTrigger = (
      comboId: ComboID,
      multiplier: number,
      title: string,
      subtitle: string,
      color: string,
      cooldownMs = 5500
    ): ActiveComboBanner | null => {
      const ck = `${seat.id}:${comboId}`;
      if ((this.comboCooldowns[ck] ?? 0) > now) return null;
      this.comboCooldowns[ck] = now + cooldownMs;

      const banner: ActiveComboBanner = {
        id: `cmb-${comboId}-${Math.floor(now)}`,
        comboId,
        multiplier,
        title,
        subtitle,
        actorName: seat.name,
        color,
        createdAt: now,
        durationMs: 3600,
      };
      this.comboBanners.unshift(banner);
      if (this.comboBanners.length > 3) this.comboBanners.length = 3;

      this.seatComboState[seat.id] = {
        multiplier,
        label: title,
        untilMs: now + 6000,
      };
      this.onComboCallback?.(banner);
      return banner;
    };

    // Priority 1: COMBO x3 Parasite Godslayer (TESLA_RCE + SYPHON_CHAIN + GRAIL_TRACTOR)
    if (
      recentSet.has('TESLA_RCE') &&
      recentSet.has('SYPHON_CHAIN') &&
      recentSet.has('GRAIL_TRACTOR') &&
      (latest === 'GRAIL_TRACTOR' || latest === 'SYPHON_CHAIN' || latest === 'TESLA_RCE')
    ) {
      const hit = tryTrigger(
        'PARASITE_GODSLAYER',
        3,
        '💥 COMBO ×3 · 寄生弑神链',
        `${seat.name} 完成 RCE 破胸 → 反向控制链 → 圣杯晶体强夺！`,
        '#DC2E33',
        6500
      );
      if (hit) {
        this.spotlightUntilMs = now + 2400;
        this.shakeEnergy = Math.max(this.shakeEnergy, 5.5);
        this.emitNormalizedBurst(0, 0, 44, '#DC2E33', '#F59E0B', 'spark', 1.45);
        this.shockwaves.push({
          nx: 0,
          ny: 0,
          maxRadiusNorm: 0.88,
          color: '#DC2E33',
          secondaryColor: '#F59E0B',
          lineWidth: 3.6,
          createdAt: now,
          durationMs: 1400,
        });
        return hit;
      }
    }

    // Priority 2: COMBO x3 Triple Aegis (NANO_WELD + SHIELD_DEFLECT)
    if (
      recentSet.has('NANO_WELD') &&
      recentSet.has('SHIELD_DEFLECT') &&
      (latest === 'SHIELD_DEFLECT' || latest === 'NANO_WELD')
    ) {
      const hit = tryTrigger(
        'TRIPLE_AEGIS',
        3,
        '🛡️ COMBO ×3 · 神圣艾吉斯三重护盾',
        `纳米热补丁 + 护盾弹反共振，中央要塞三重免疫阵列激活！`,
        '#007AFF',
        6000
      );
      if (hit) {
        this.tripleAegisUntilMs = Math.max(this.tripleAegisUntilMs, now + 8000);
        this.hexShieldUntilMs = Math.max(this.hexShieldUntilMs, now + 8000);
        this.shockwaves.push({
          nx: 0,
          ny: 0,
          maxRadiusNorm: 0.65,
          color: '#007AFF',
          secondaryColor: '#10B981',
          lineWidth: 2.8,
          createdAt: now,
          durationMs: 1100,
        });
        return hit;
      }
    }

    // Priority 3: COMBO x2 Sovereign Iron Curtain (GRAIL_TRACTOR -> NANO_WELD)
    if (recentSet.has('GRAIL_TRACTOR') && latest === 'NANO_WELD') {
      const hit = tryTrigger(
        'SOVEREIGN_IRON_CURTAIN',
        2,
        '👑 COMBO ×2 · 王权铁幕',
        `${seat.name} 夺取圣杯并立即焊死漏洞，展开 360° 蓝金防护穹顶！`,
        '#D97706',
        5500
      );
      if (hit) {
        this.hexShieldUntilMs = Math.max(this.hexShieldUntilMs, now + 8000);
        this.shockwaves.push({
          nx: 0,
          ny: 0,
          maxRadiusNorm: 0.72,
          color: '#D97706',
          secondaryColor: '#007AFF',
          lineWidth: 3.0,
          createdAt: now,
          durationMs: 1200,
        });
        return hit;
      }
    }

    // Priority 4: COMBO x3 Tri-Vector Overload (>=3 distinct offensive tools)
    const offensiveCount = (
      ['SONAR_SCAN', 'HTTP_PHOTON', 'SQLI_SWARM', 'NEURAL_HELIX', 'TESLA_RCE'] as WeaponArchetype[]
    ).filter((a) => recentSet.has(a)).length;
    if (offensiveCount >= 3) {
      const hit = tryTrigger(
        'TRI_VECTOR_OVERLOAD',
        3,
        '⚡ COMBO ×3 · 全域三向量过载',
        `${seat.name} 多维武器库并发压制，三色光谱集火轰击中枢！`,
        '#7C3AED',
        7500
      );
      if (hit) {
        this.emitNormalizedBurst(0, 0, 30, '#7C3AED', '#007AFF', 'spark', 1.2);
        return hit;
      }
    }

    // Priority 5: COMBO x2 Vault Meltdown / Neural Mind-Hack / Lock-On Strike
    if (recentSet.has('SQLI_SWARM') && latest === 'GRAIL_TRACTOR') {
      const hit = tryTrigger(
        'VAULT_MELTDOWN',
        2,
        '🧬 COMBO ×2 · 金库熔穿',
        `${seat.name} SQLmap 破甲钻穿账本金库，直接抽取圣杯 Flag！`,
        '#EA580C'
      );
      if (hit) return hit;
    }

    if (recentSet.has('NEURAL_HELIX') && latest === 'GRAIL_TRACTOR') {
      const hit = tryTrigger(
        'NEURAL_MIND_HACK',
        2,
        '🔮 COMBO ×2 · 神经夺舍',
        `${seat.name} Prompt 提示注入击穿 AI 防线，强行越权夺杯！`,
        '#9333EA'
      );
      if (hit) return hit;
    }

    if (
      prev === 'SONAR_SCAN' &&
      (latest === 'HTTP_PHOTON' || latest === 'SQLI_SWARM' || latest === 'TESLA_RCE')
    ) {
      const hit = tryTrigger(
        'LOCK_ON_STRIKE',
        2,
        '🎯 COMBO ×2 · 鹰眼锁定强袭',
        `${seat.name} 声呐探明端口后零延迟精确制导命中！`,
        '#0284C7'
      );
      if (hit) return hit;
    }

    // Crossfire Vortex: >= 2 distinct seats strike within 3.5s
    const distinctAttackers = new Set(this.globalRecentHits.map((g) => g.seatId));
    if (distinctAttackers.size >= 2) {
      const ck = `global:CROSSFIRE_VORTEX`;
      if ((this.comboCooldowns[ck] ?? 0) <= now) {
        this.comboCooldowns[ck] = now + 6000;
        this.crossfireVortexUntilMs = now + 4500;
        const banner: ActiveComboBanner = {
          id: `cmb-cross-${Math.floor(now)}`,
          comboId: 'CROSSFIRE_VORTEX',
          multiplier: distinctAttackers.size,
          title: `🌪️ CROSSFIRE ×${distinctAttackers.size} · 群雄合围混战`,
          subtitle: `${distinctAttackers.size} 支 AI 战队同屏对圣杯要塞发动立体交叉火力！`,
          actorName: 'MULTI-FACTION',
          color: '#EA580C',
          createdAt: now,
          durationMs: 3200,
        };
        this.comboBanners.unshift(banner);
        if (this.comboBanners.length > 3) this.comboBanners.length = 3;
        this.onComboCallback?.(banner);
        return banner;
      }
    }

    return null;
  }

  private emitNormalizedBurst(
    nx: number,
    ny: number,
    count: number,
    c1: string,
    c2: string,
    kind: Particle['kind'],
    speedMul = 1.0
  ): void {
    const glyphs = ['{λ}', '0x7F', 'EXEC', 'ROOT', 'SQL', 'SYN'];
    for (let i = 0; i < count; i++) {
      const ang = (Math.PI * 2 * i) / count + (Math.random() - 0.5) * 0.45;
      const spd = (0.004 + Math.random() * 0.011) * speedMul;
      this.particles.push({
        nx,
        ny,
        vx: Math.cos(ang) * spd,
        vy: Math.sin(ang) * spd,
        radius: kind === 'shard' ? 3.2 + Math.random() * 2.5 : 2.0 + Math.random() * 2.2,
        color: i % 2 === 0 ? c1 : c2,
        alpha: 1,
        decay: 0.02 + Math.random() * 0.018,
        kind,
        glyph: kind === 'glyph' ? glyphs[i % glyphs.length] : undefined,
      });
    }
    if (this.particles.length > 260) {
      this.particles = this.particles.slice(-260);
    }
  }

  public getShakeOffset(dpr: number): { dx: number; dy: number } {
    if (this.shakeEnergy < 0.12) {
      this.shakeEnergy = 0;
      return { dx: 0, dy: 0 };
    }
    const dx = (Math.random() - 0.5) * 2 * this.shakeEnergy * dpr;
    const dy = (Math.random() - 0.5) * 2 * this.shakeEnergy * dpr;
    this.shakeEnergy *= 0.87;
    return { dx, dy };
  }

  public renderFrame(
    ctx: CanvasRenderingContext2D,
    w: number,
    h: number,
    cx: number,
    cy: number,
    maxR: number,
    dpr: number,
    now: number,
    seatPos: Record<string, { x: number; y: number; seat: SeatState }>,
    primaryTarget: TargetFortress | undefined,
    targetPos?: Record<string, { x: number; y: number; r: number; target: TargetFortress }>
  ): void {
    // 1. Subtle Spotlight Vignette during Parasite Godslayer COMBO x3
    if (now < this.spotlightUntilMs) {
      const frac = Math.min(1, (this.spotlightUntilMs - now) / 800);
      const vg = ctx.createRadialGradient(cx, cy, maxR * 0.15, cx, cy, Math.max(w, h) * 0.72);
      vg.addColorStop(0, 'rgba(220, 46, 51, 0)');
      vg.addColorStop(1, `rgba(15, 23, 42, ${0.14 * frac})`);
      ctx.fillStyle = vg;
      ctx.fillRect(0, 0, w, h);
    }

    // 2. Crossfire Interference Vortex under Central Fortress
    if (now < this.crossfireVortexUntilMs) {
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(now * 0.004);
      const vr = 82 * dpr;
      for (let arm = 0; arm < 4; arm++) {
        ctx.rotate(Math.PI / 2);
        ctx.beginPath();
        ctx.arc(0, 0, vr + arm * 5 * dpr, 0.15, Math.PI * 0.7);
        ctx.strokeStyle =
          arm % 2 === 0 ? 'rgba(234, 88, 12, 0.36)' : 'rgba(147, 51, 234, 0.34)';
        ctx.lineWidth = 2.6 * dpr;
        ctx.stroke();
      }
      ctx.restore();
    }

    // 3. Render Hexagonal Honeycomb Aegis Shield Dome & Triple Aegis Sacred Rings
    if (now < this.hexShieldUntilMs || primaryTarget?.is_patched) {
      const shieldAlpha = now < this.hexShieldUntilMs ? 0.58 : 0.28;
      const domeR = 76 * dpr;
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(now * 0.00055);

      ctx.beginPath();
      for (let i = 0; i < 6; i++) {
        const a = (Math.PI / 3) * i;
        const hx = Math.cos(a) * domeR;
        const hy = Math.sin(a) * domeR;
        if (i === 0) ctx.moveTo(hx, hy);
        else ctx.lineTo(hx, hy);
      }
      ctx.closePath();
      ctx.fillStyle = `rgba(0, 122, 255, ${shieldAlpha * 0.09})`;
      ctx.fill();
      ctx.lineWidth = 2.2 * dpr;
      ctx.strokeStyle = `rgba(0, 122, 255, ${shieldAlpha})`;
      ctx.stroke();

      if (now < this.tripleAegisUntilMs) {
        [-1, 1].forEach((dir, idx) => {
          ctx.save();
          ctx.rotate(dir * now * 0.0014);
          ctx.beginPath();
          ctx.arc(0, 0, domeR + (9 + idx * 7) * dpr, 0, Math.PI * 2);
          ctx.setLineDash([12 * dpr, 8 * dpr]);
          ctx.lineWidth = 1.8 * dpr;
          ctx.strokeStyle = idx === 0 ? 'rgba(16, 185, 129, 0.65)' : 'rgba(217, 119, 6, 0.55)';
          ctx.stroke();
          ctx.setLineDash([]);
          ctx.restore();
        });
      }
      ctx.restore();
    }

    // 4. Prune & Render Shockwaves
    this.shockwaves = this.shockwaves.filter((sw) => now - sw.createdAt < sw.durationMs);
    for (const sw of this.shockwaves) {
      if (now < sw.createdAt) continue;
      const t = Math.max(0, Math.min(1, (now - sw.createdAt) / Math.max(1, sw.durationMs)));
      const ease = 1 - Math.pow(1 - t, 3);
      const r = Math.max(1, ease * maxR * sw.maxRadiusNorm);
      const alpha = Math.max(0, (1 - t) * 0.78);
      ctx.save();
      ctx.beginPath();
      ctx.arc(cx + sw.nx * maxR, cy + sw.ny * maxR, r, 0, Math.PI * 2);
      ctx.strokeStyle = sw.color;
      ctx.globalAlpha = alpha;
      ctx.lineWidth = Math.max(0.5, sw.lineWidth * (1 - t * 0.45) * dpr);
      ctx.stroke();

      if (sw.secondaryColor) {
        ctx.beginPath();
        ctx.arc(cx + sw.nx * maxR, cy + sw.ny * maxR, Math.max(0.5, r * 0.78), 0, Math.PI * 2);
        ctx.strokeStyle = sw.secondaryColor;
        ctx.globalAlpha = alpha * 0.7;
        ctx.lineWidth = 1.6 * dpr;
        ctx.stroke();
      }
      if (sw.badgeText && t < 0.7) {
        ctx.globalAlpha = Math.max(0, 1 - t / 0.7);
        this.drawCanvasPill(
          ctx,
          sw.badgeText,
          cx,
          cy - Math.min(r * 0.7, 92 * dpr),
          '#FFFFFF',
          sw.color,
          dpr
        );
      }
      ctx.restore();
    }

    // 4b. Directional Organ Impact Arcs around Target Fortress facing each attacker seat
    this.impactArcs = this.impactArcs.filter((arc) => now - arc.createdAt < arc.durationMs);
    for (const arc of this.impactArcs) {
      const sNode = seatPos[arc.seatId];
      if (!sNode) continue;
      const tNode = targetPos?.[arc.targetId];
      const tx = tNode ? tNode.x : cx;
      const ty = tNode ? tNode.y : cy;
      const baseR = tNode ? tNode.r : 72 * dpr;
      const t = Math.max(0, Math.min(1, (now - arc.createdAt) / Math.max(1, arc.durationMs)));
      const baseAng = Math.atan2(sNode.y - ty, sNode.x - tx);
      const halfSpan = 0.61; // ~70 deg total directional arc
      const arcR = Math.max(20, baseR + (2 + t * 14) * dpr);
      const alpha = Math.max(0, 1 - t);
      ctx.save();
      ctx.beginPath();
      ctx.arc(tx, ty, arcR, baseAng - halfSpan, baseAng + halfSpan);
      ctx.strokeStyle = arc.color;
      ctx.globalAlpha = alpha * 0.85;
      ctx.lineWidth = Math.max(1, (4.2 - t * 2.2) * dpr);
      ctx.lineCap = 'round';
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(tx, ty, Math.max(16, arcR - 3 * dpr), baseAng - halfSpan * 0.65, baseAng + halfSpan * 0.65);
      ctx.strokeStyle = '#FFFFFF';
      ctx.globalAlpha = alpha * 0.7;
      ctx.lineWidth = 1.4 * dpr;
      ctx.stroke();
      ctx.restore();
    }

    // 5. Prune & Render Active Weapon Projectiles
    this.projectiles = this.projectiles.filter((p) => now - p.createdAt < p.durationMs);
    const drawnLabelForBeam = new Set<string>();
    const seatLabelCounts: Record<string, number> = {};

    for (const p of this.projectiles) {
      const sNode = seatPos[p.seatId];
      if (!sNode) continue;
      const tNode = targetPos?.[p.targetId];
      const tx = tNode ? tNode.x : cx;
      const ty = tNode ? tNode.y : cy;
      const t = Math.max(0, Math.min(1, (now - p.createdAt) / Math.max(1, p.durationMs)));
      const sx = sNode.x;
      const sy = sNode.y;
      const angle = Math.atan2(ty - sy, tx - sx);
      const dist = Math.hypot(tx - sx, ty - sy);

      this.renderWeaponProjectile(ctx, p, sx, sy, tx, ty, angle, dist, t, dpr, now);

      // Clean deduplicated stacked pill callout along mid-beam (max 2 stacked callouts per beam, zero overlap)
      const labelKey = `${p.seatId}:${p.archetype}`;
      const usedSlots = seatLabelCounts[p.seatId] ?? 0;
      if (!drawnLabelForBeam.has(labelKey) && usedSlots < 2 && t > 0.08 && t < 0.92) {
        drawnLabelForBeam.add(labelKey);
        seatLabelCounts[p.seatId] = usedSlots + 1;
        const tFrac = usedSlots === 0 ? 0.36 : 0.56;
        const sideSign = usedSlots === 0 ? -1 : 1;
        const perpOff = sideSign * 16 * dpr;
        const lx = sx + (tx - sx) * tFrac - Math.sin(angle) * perpOff;
        const ly = sy + (ty - sy) * tFrac + Math.cos(angle) * perpOff;
        const meta = WEAPON_META[p.archetype];
        this.drawCanvasPill(
          ctx,
          p.isLockOn ? `🎯 ${meta.zhLabel}` : meta.zhLabel,
          lx,
          ly,
          'rgba(255,255,255,0.95)',
          meta.color,
          dpr,
          1 - Math.max(0, (t - 0.72) / 0.28)
        );
      }
    }

    // 6. Update & Render Particles
    const aliveParticles: Particle[] = [];
    for (const pt of this.particles) {
      pt.nx += pt.vx;
      pt.ny += pt.vy;
      pt.vx *= 0.96;
      pt.vy *= 0.96;
      pt.alpha -= pt.decay;
      if (pt.alpha <= 0.02) continue;
      aliveParticles.push(pt);

      const px = cx + pt.nx * maxR;
      const py = cy + pt.ny * maxR;
      ctx.save();
      ctx.globalAlpha = Math.max(0, Math.min(1, pt.alpha));
      if (pt.kind === 'glyph' && pt.glyph) {
        ctx.font = `700 ${9 * dpr}px "SF Mono", monospace`;
        ctx.fillStyle = pt.color;
        ctx.textAlign = 'center';
        ctx.fillText(pt.glyph, px, py);
      } else if (pt.kind === 'shard') {
        ctx.translate(px, py);
        ctx.rotate(now * 0.008 + pt.nx * 10);
        ctx.fillStyle = pt.color;
        const sz = Math.max(1, pt.radius * dpr);
        ctx.fillRect(-sz * 0.5, -sz * 0.5, sz, sz);
      } else {
        ctx.beginPath();
        ctx.arc(px, py, Math.max(0.5, pt.radius * dpr), 0, Math.PI * 2);
        ctx.fillStyle = pt.color;
        ctx.fill();
      }
      ctx.restore();
    }
    this.particles = aliveParticles;

    // 7. Render Floating Status Badges (e.g. SHIELD DEFLECT)
    this.badges = this.badges.filter((b) => now - b.createdAt < b.durationMs);
    for (const b of this.badges) {
      if (now < b.createdAt) continue;
      const t = Math.max(0, Math.min(1, (now - b.createdAt) / Math.max(1, b.durationMs)));
      const alpha = Math.max(0, t < 0.7 ? 1 : 1 - (t - 0.7) / 0.3);
      this.drawCanvasPill(
        ctx,
        b.text,
        cx + b.nx * maxR,
        cy + (b.ny - t * 0.08) * maxR,
        'rgba(255,255,255,0.96)',
        b.color,
        dpr,
        alpha
      );
    }
  }

  private renderWeaponProjectile(
    ctx: CanvasRenderingContext2D,
    p: ProjectileFX,
    sx: number,
    sy: number,
    cx: number,
    cy: number,
    angle: number,
    dist: number,
    t: number,
    dpr: number,
    now: number
  ): void {
    const alpha = Math.max(0.05, Math.min(1, t > 0.8 ? (1 - t) / 0.2 : 1));
    ctx.save();
    ctx.globalAlpha = alpha;

    switch (p.archetype) {
      case 'SONAR_SCAN': {
        // 65 deg sweeping sonar radar cone from seat + 3 expanding rings on target
        const sweep = Math.sin(now * 0.009) * 0.32;
        const coneLen = Math.max(14 * dpr, dist * Math.max(0.08, Math.min(1, t * 1.4)));
        const coneGrad = ctx.createRadialGradient(sx, sy, 8 * dpr, sx, sy, Math.max(16 * dpr, coneLen));
        coneGrad.addColorStop(0, 'rgba(2, 132, 199, 0.28)');
        coneGrad.addColorStop(1, 'rgba(2, 132, 199, 0.0)');
        ctx.beginPath();
        ctx.moveTo(sx, sy);
        ctx.arc(sx, sy, coneLen, angle - 0.42 + sweep, angle + 0.42 + sweep);
        ctx.closePath();
        ctx.fillStyle = coneGrad;
        ctx.fill();

        // 3 acoustic wave rings hitting central target
        [0, 0.25, 0.5].forEach((phase) => {
          const wt = (((t * 1.5 + phase) % 1) + 1) % 1;
          ctx.beginPath();
          ctx.arc(cx, cy, Math.max(1, (22 + wt * 54) * dpr), 0, Math.PI * 2);
          ctx.strokeStyle = `rgba(2, 132, 199, ${(1 - wt) * 0.55})`;
          ctx.lineWidth = 1.8 * dpr;
          ctx.stroke();
        });
        break;
      }

      case 'HTTP_PHOTON': {
        const travel = Math.max(0.05, Math.min(1, t * 1.35));
        const perpX = -Math.sin(angle) * 4.5 * dpr;
        const perpY = Math.cos(angle) * 4.5 * dpr;
        [-1, 1].forEach((side) => {
          const hx = sx + (cx - sx) * travel + perpX * side;
          const hy = sy + (cy - sy) * travel + perpY * side;
          const tailStart = Math.max(0, travel - 0.3);
          const tx = sx + (cx - sx) * tailStart + perpX * side;
          const ty = sy + (cy - sy) * tailStart + perpY * side;
          const grad = ctx.createLinearGradient(tx, ty, hx, hy);
          grad.addColorStop(0, 'rgba(0, 122, 255, 0)');
          grad.addColorStop(1, '#007AFF');
          ctx.beginPath();
          ctx.moveTo(tx, ty);
          ctx.lineTo(hx, hy);
          ctx.strokeStyle = grad;
          ctx.lineWidth = 2.6 * dpr;
          ctx.stroke();

          ctx.beginPath();
          ctx.arc(hx, hy, 3.6 * dpr, 0, Math.PI * 2);
          ctx.fillStyle = '#FFFFFF';
          ctx.fill();
          ctx.strokeStyle = '#007AFF';
          ctx.lineWidth = 1.6 * dpr;
          ctx.stroke();
        });
        break;
      }

      case 'SQLI_SWARM': {
        // 5 curved Bezier missiles fanning along parabolic arcs
        const perpX = -Math.sin(angle);
        const perpY = Math.cos(angle);
        [-58, -28, 0, 28, 58].forEach((spread, idx) => {
          const mt = Math.min(1, Math.max(0, t * 1.45 - idx * 0.06));
          if (mt <= 0) return;
          const ctrlX = (sx + cx) * 0.5 + perpX * spread * dpr;
          const ctrlY = (sy + cy) * 0.5 + perpY * spread * dpr;
          const mx = (1 - mt) ** 2 * sx + 2 * (1 - mt) * mt * ctrlX + mt ** 2 * cx;
          const my = (1 - mt) ** 2 * sy + 2 * (1 - mt) * mt * ctrlY + mt ** 2 * cy;

          ctx.beginPath();
          ctx.moveTo(sx, sy);
          ctx.quadraticCurveTo(ctrlX, ctrlY, cx, cy);
          ctx.strokeStyle = 'rgba(234, 88, 12, 0.20)';
          ctx.lineWidth = 1.4 * dpr;
          ctx.stroke();

          // Missile head + ember halo
          ctx.beginPath();
          ctx.arc(mx, my, 6.2 * dpr, 0, Math.PI * 2);
          ctx.fillStyle = 'rgba(245, 158, 11, 0.35)';
          ctx.fill();
          ctx.beginPath();
          ctx.arc(mx, my, 3.2 * dpr, 0, Math.PI * 2);
          ctx.fillStyle = idx % 2 === 0 ? '#EA580C' : '#F59E0B';
          ctx.fill();
        });
        break;
      }

      case 'NEURAL_HELIX': {
        // Twin intertwined sinusoidal strands with DNA cross rungs
        const steps = 28;
        const perpX = -Math.sin(angle);
        const perpY = Math.cos(angle);
        const reach = Math.min(1, t * 1.4);
        const strandA: { x: number; y: number }[] = [];
        const strandB: { x: number; y: number }[] = [];
        for (let i = 0; i <= steps; i++) {
          const f = (i / steps) * reach;
          const wave = Math.sin(f * Math.PI * 5 - now * 0.012) * 14 * dpr * Math.sin(f * Math.PI);
          const bx = sx + (cx - sx) * f;
          const by = sy + (cy - sy) * f;
          strandA.push({ x: bx + perpX * wave, y: by + perpY * wave });
          strandB.push({ x: bx - perpX * wave, y: by - perpY * wave });
        }
        [
          { pts: strandA, col: '#9333EA' },
          { pts: strandB, col: '#EC4899' },
        ].forEach(({ pts, col }) => {
          ctx.beginPath();
          pts.forEach((pt, idx) => (idx === 0 ? ctx.moveTo(pt.x, pt.y) : ctx.lineTo(pt.x, pt.y)));
          ctx.strokeStyle = col;
          ctx.lineWidth = 2.4 * dpr;
          ctx.stroke();
        });
        for (let i = 3; i < strandA.length; i += 4) {
          ctx.beginPath();
          ctx.moveTo(strandA[i].x, strandA[i].y);
          ctx.lineTo(strandB[i].x, strandB[i].y);
          ctx.strokeStyle = 'rgba(168, 85, 247, 0.45)';
          ctx.lineWidth = 1.2 * dpr;
          ctx.stroke();
        }
        break;
      }

      case 'TESLA_RCE': {
        // Procedural jagged forked Tesla lightning bolt!
        const segments = 12;
        const perpX = -Math.sin(angle);
        const perpY = Math.cos(angle);
        const points: { x: number; y: number }[] = [{ x: sx, y: sy }];
        for (let i = 1; i < segments; i++) {
          const f = i / segments;
          const env = Math.sin(f * Math.PI);
          const jit =
            Math.sin(now * 0.045 + i * 7.3 + p.seed) * (p.isGodslayer ? 24 : 16) * dpr * env;
          points.push({
            x: sx + (cx - sx) * f + perpX * jit,
            y: sy + (cy - sy) * f + perpY * jit,
          });
        }
        points.push({ x: cx, y: cy });

        // Outer crimson plasma glow
        ctx.beginPath();
        points.forEach((pt, i) => (i === 0 ? ctx.moveTo(pt.x, pt.y) : ctx.lineTo(pt.x, pt.y)));
        ctx.strokeStyle = 'rgba(220, 46, 51, 0.55)';
        ctx.lineWidth = (p.isGodslayer ? 10 : 7) * dpr;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        ctx.stroke();

        // Inner hot core
        ctx.beginPath();
        points.forEach((pt, i) => (i === 0 ? ctx.moveTo(pt.x, pt.y) : ctx.lineTo(pt.x, pt.y)));
        ctx.strokeStyle = '#FFF5F5';
        ctx.lineWidth = (p.isGodslayer ? 3.2 : 2.1) * dpr;
        ctx.stroke();

        // Side fork branches
        [3, 7].forEach((bIdx, k) => {
          const origin = points[bIdx];
          if (!origin) return;
          const dir = k % 2 === 0 ? 1 : -1;
          ctx.beginPath();
          ctx.moveTo(origin.x, origin.y);
          ctx.lineTo(origin.x + perpX * 20 * dir * dpr, origin.y + perpY * 20 * dir * dpr);
          ctx.lineTo(
            origin.x + Math.cos(angle) * 24 * dpr + perpX * 32 * dir * dpr,
            origin.y + Math.sin(angle) * 24 * dpr + perpY * 32 * dir * dpr
          );
          ctx.strokeStyle = 'rgba(220, 46, 51, 0.72)';
          ctx.lineWidth = 1.6 * dpr;
          ctx.stroke();
        });
        break;
      }

      case 'SYPHON_CHAIN': {
        // Dashed reverse-shell tether + golden siphoned diamonds moving Target -> Attacker
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.lineTo(sx, sy);
        ctx.strokeStyle = '#DC2E33';
        ctx.lineWidth = 2.8 * dpr;
        ctx.setLineDash([8 * dpr, 5 * dpr]);
        ctx.lineDashOffset = now * 0.05;
        ctx.stroke();
        ctx.setLineDash([]);

        [0, 0.33, 0.66].forEach((ph) => {
          const frac = (now * 0.0011 + ph) % 1;
          const gx = cx + (sx - cx) * frac;
          const gy = cy + (sy - cy) * frac;
          ctx.save();
          ctx.translate(gx, gy);
          ctx.rotate(angle + Math.PI / 4);
          ctx.fillStyle = '#F59E0B';
          const sz = 7.5 * dpr;
          ctx.fillRect(-sz * 0.5, -sz * 0.5, sz, sz);
          ctx.restore();
        });
        break;
      }

      case 'GRAIL_TRACTOR': {
        // Golden tractor beam + rotating 3D-projected Golden Octahedron Crystal Target -> Seat
        const grad = ctx.createLinearGradient(cx, cy, sx, sy);
        grad.addColorStop(0, 'rgba(245, 158, 11, 0.62)');
        grad.addColorStop(0.5, 'rgba(251, 191, 36, 0.32)');
        grad.addColorStop(1, 'rgba(217, 119, 6, 0.55)');
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.lineTo(sx, sy);
        ctx.strokeStyle = grad;
        ctx.lineWidth = Math.max(1, 11 * dpr * (1 - t * 0.4));
        ctx.lineCap = 'round';
        ctx.stroke();

        // Extracted rotating Golden Grail Octahedron Crystal moving Target -> Seat
        const ease = 1 - Math.pow(1 - Math.min(1, t * 1.15), 2);
        const gx = cx + (sx - cx) * ease;
        const gy = cy + (sy - cy) * ease;
        this.drawRotatingCrystal(ctx, gx, gy, 13 * dpr, now * 0.004, '#F59E0B', '#FEF3C7', dpr);
        break;
      }

      case 'ROOT_SUPERNOVA': {
        // Intense vertical orbital light pillar + crimson-gold core beam
        const grad = ctx.createLinearGradient(sx, sy, cx, cy);
        grad.addColorStop(0, '#DC2E33');
        grad.addColorStop(1, '#F59E0B');
        ctx.beginPath();
        ctx.moveTo(sx, sy);
        ctx.lineTo(cx, cy);
        ctx.strokeStyle = grad;
        ctx.lineWidth = 4.5 * dpr;
        ctx.stroke();

        const pillarW = Math.max(2 * dpr, 28 * dpr * (1 - t * 0.7));
        const pGrad = ctx.createLinearGradient(cx - pillarW, cy, cx + pillarW, cy);
        pGrad.addColorStop(0, 'rgba(245, 158, 11, 0)');
        pGrad.addColorStop(0.5, 'rgba(245, 158, 11, 0.42)');
        pGrad.addColorStop(1, 'rgba(245, 158, 11, 0)');
        ctx.fillStyle = pGrad;
        ctx.fillRect(cx - pillarW, 0, pillarW * 2, cy);
        break;
      }

      case 'NANO_WELD': {
        // Dual cyan-emerald surgical welding laser sweeping across fortress
        const sweepAngle = angle + Math.sin(now * 0.015) * 0.12;
        const wx = cx + Math.cos(sweepAngle + Math.PI) * 52 * dpr;
        const wy = cy + Math.sin(sweepAngle + Math.PI) * 52 * dpr;
        const wGrad = ctx.createLinearGradient(sx, sy, wx, wy);
        wGrad.addColorStop(0, '#007AFF');
        wGrad.addColorStop(1, '#10B981');
        ctx.beginPath();
        ctx.moveTo(sx, sy);
        ctx.lineTo(wx, wy);
        ctx.strokeStyle = wGrad;
        ctx.lineWidth = 3.2 * dpr;
        ctx.stroke();

        // Welding flare arc at contact point
        ctx.beginPath();
        ctx.arc(wx, wy, 7 * dpr, 0, Math.PI * 2);
        ctx.fillStyle = '#FFFFFF';
        ctx.fill();
        ctx.strokeStyle = '#10B981';
        ctx.lineWidth = 2.4 * dpr;
        ctx.stroke();
        break;
      }

      case 'SHIELD_DEFLECT': {
        // Projectile flies to shield radius (~76px from center) then ricochets away!
        const shieldHitFrac = Math.max(0.3, (dist - 76 * dpr) / Math.max(1, dist));
        const impactX = sx + (cx - sx) * shieldHitFrac;
        const impactY = sy + (cy - sy) * shieldHitFrac;
        if (t < 0.42) {
          const u = t / 0.42;
          const mx = sx + (impactX - sx) * u;
          const my = sy + (impactY - sy) * u;
          ctx.beginPath();
          ctx.moveTo(sx, sy);
          ctx.lineTo(mx, my);
          ctx.strokeStyle = '#DC2E33';
          ctx.lineWidth = 2.4 * dpr;
          ctx.stroke();
          ctx.beginPath();
          ctx.arc(mx, my, 4.5 * dpr, 0, Math.PI * 2);
          ctx.fillStyle = '#DC2E33';
          ctx.fill();
        } else {
          const u = Math.max(0, Math.min(1, (t - 0.42) / 0.58));
          const deflectAngle = angle + Math.PI + (p.seed % 2 === 0 ? 0.85 : -0.85);
          const rx = impactX + Math.cos(deflectAngle) * u * 150 * dpr;
          const ry = impactY + Math.sin(deflectAngle) * u * 150 * dpr;
          ctx.beginPath();
          ctx.moveTo(impactX, impactY);
          ctx.lineTo(rx, ry);
          ctx.strokeStyle = '#0EA5E9';
          ctx.lineWidth = 2.4 * dpr;
          ctx.setLineDash([6 * dpr, 4 * dpr]);
          ctx.stroke();
          ctx.setLineDash([]);

          ctx.beginPath();
          ctx.arc(impactX, impactY, Math.max(1, (8 + u * 22) * dpr), 0, Math.PI * 2);
          ctx.strokeStyle = `rgba(14, 165, 233, ${Math.max(0, 1 - u)})`;
          ctx.lineWidth = 2.2 * dpr;
          ctx.stroke();
        }
        break;
      }

      case 'PRISM_CRED': {
        const midX = (sx + cx) * 0.5;
        const midY = (sy + cy) * 0.5;
        ctx.beginPath();
        ctx.moveTo(sx, sy);
        ctx.lineTo(midX, midY);
        ctx.strokeStyle = '#7C3AED';
        ctx.lineWidth = 3 * dpr;
        ctx.stroke();

        const perpX = -Math.sin(angle);
        const perpY = Math.cos(angle);
        [
          { off: -16, col: '#06B6D4' },
          { off: 0, col: '#7C3AED' },
          { off: 16, col: '#EC4899' },
        ].forEach(({ off, col }) => {
          ctx.beginPath();
          ctx.moveTo(midX, midY);
          ctx.lineTo(cx + perpX * off * dpr, cy + perpY * off * dpr);
          ctx.strokeStyle = col;
          ctx.lineWidth = 2 * dpr;
          ctx.stroke();
        });
        break;
      }

      default:
        break;
    }

    // Lock-on Reticle Overlay on COMBO x2 Eagle Lock-On Strike
    if (p.isLockOn) {
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(now * 0.004);
      const rr = 68 * dpr;
      ctx.strokeStyle = '#0284C7';
      ctx.lineWidth = 2 * dpr;
      for (let i = 0; i < 4; i++) {
        ctx.rotate(Math.PI / 2);
        ctx.beginPath();
        ctx.arc(0, 0, rr, -0.35, 0.35);
        ctx.stroke();
      }
      ctx.restore();
    }

    ctx.restore();
  }

  private drawRotatingCrystal(
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    size: number,
    rot: number,
    stroke: string,
    fill: string,
    dpr: number
  ): void {
    ctx.save();
    ctx.translate(x, y);
    const wMod = Math.max(0.35, Math.abs(Math.cos(rot))) * size;
    ctx.beginPath();
    ctx.moveTo(0, -size * 1.25);
    ctx.lineTo(wMod, 0);
    ctx.lineTo(0, size * 1.25);
    ctx.lineTo(-wMod, 0);
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
    ctx.strokeStyle = stroke;
    ctx.lineWidth = 2 * dpr;
    ctx.stroke();

    ctx.beginPath();
    ctx.moveTo(0, -size * 1.25);
    ctx.lineTo(0, size * 1.25);
    ctx.moveTo(-wMod, 0);
    ctx.lineTo(wMod, 0);
    ctx.strokeStyle = stroke;
    ctx.lineWidth = 1.1 * dpr;
    ctx.stroke();
    ctx.restore();
  }

  private drawCanvasPill(
    ctx: CanvasRenderingContext2D,
    text: string,
    lx: number,
    ly: number,
    bg: string,
    color: string,
    dpr: number,
    alpha = 1
  ): void {
    ctx.save();
    ctx.globalAlpha = Math.max(0, Math.min(1, alpha));
    ctx.font = `700 ${10 * dpr}px -apple-system, "PingFang SC", sans-serif`;
    const tw = ctx.measureText(text).width;
    const padX = 7.5 * dpr;
    const pillW = tw + padX * 2;
    const pillH = 19 * dpr;
    ctx.beginPath();
    ctx.roundRect(lx - pillW * 0.5, ly - pillH * 0.5, pillW, pillH, 9.5 * dpr);
    ctx.fillStyle = bg;
    ctx.fill();
    ctx.lineWidth = 1 * dpr;
    ctx.strokeStyle = 'rgba(0,0,0,0.08)';
    ctx.stroke();
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = color;
    ctx.fillText(text, lx, ly + 0.5 * dpr);
    ctx.restore();
  }
}
