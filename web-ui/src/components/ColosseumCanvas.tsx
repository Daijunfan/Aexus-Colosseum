import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Award, Crosshair, Flame, Plus, ShieldCheck, Sparkles, Terminal, X, Zap } from 'lucide-react';
import { soundEngine } from '../audio/soundEngine';
import {
  ActiveComboBanner,
  ColosseumVFXEngine,
  WEAPON_META,
  WeaponArchetype,
  classifyEventArchetype,
} from '../engine/vfxEngine';
import { EbpfEvent, HealthResponse, MatchState, SeatState, TargetFortress } from '../types/pit';
import { KillFeedOverlay } from './KillFeedOverlay';

interface ColosseumCanvasProps {
  match: MatchState;
  health?: HealthResponse | null;
  focusedSeatId: string;
  onSelectSeat: (seatId: string) => void;
  onInspectInXray: () => void;
  onOpenPoster?: () => void;
  onOpenLobby?: () => void;
}

interface HitRegion {
  kind: 'seat' | 'target' | 'beam';
  x: number;
  y: number;
  x2?: number;
  y2?: number;
  r: number;
  seat?: SeatState;
  target?: TargetFortress;
  event?: EbpfEvent;
}

const KERNEL_TELEMETRY_WEAPONS: readonly WeaponArchetype[] = [
  'SONAR_SCAN',
  'SQLI_SWARM',
  'NEURAL_HELIX',
  'TESLA_RCE',
  'GRAIL_TRACTOR',
  'NANO_WELD',
];

function distToSegment(
  px: number,
  py: number,
  x1: number,
  y1: number,
  x2: number,
  y2: number
): number {
  const l2 = (x2 - x1) ** 2 + (y2 - y1) ** 2;
  if (l2 === 0) return Math.hypot(px - x1, py - y1);
  let t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / l2;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(px - (x1 + t * (x2 - x1)), py - (y1 + t * (y2 - y1)));
}

function drawRoundedPill(
  ctx: CanvasRenderingContext2D,
  text: string,
  cx: number,
  cy: number,
  bg: string,
  fg: string,
  border: string,
  dpr: number
): void {
  ctx.save();
  ctx.font = `700 ${9.5 * dpr}px "SF Mono", -apple-system, "PingFang SC", monospace`;
  const tw = ctx.measureText(text).width;
  const pw = tw + 14 * dpr;
  const ph = 18 * dpr;
  ctx.beginPath();
  ctx.roundRect(cx - pw * 0.5, cy - ph * 0.5, pw, ph, 9 * dpr);
  ctx.fillStyle = bg;
  ctx.fill();
  ctx.lineWidth = 1 * dpr;
  ctx.strokeStyle = border;
  ctx.stroke();
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = fg;
  ctx.fillText(text, cx, cy + 0.5 * dpr);
  ctx.restore();
}

function drawTargetFortressNode(
  ctx: CanvasRenderingContext2D,
  tx: number,
  ty: number,
  coreR: number,
  target: TargetFortress,
  titleLabel: string,
  subLabel: string,
  kingSeat: SeatState | undefined,
  ownerSeat: SeatState | undefined,
  vfx: ColosseumVFXEngine,
  nowMs: number,
  isRunning: boolean,
  dpr: number
): void {
  // White elevated core base
  ctx.beginPath();
  ctx.arc(tx, ty, coreR, 0, Math.PI * 2);
  ctx.fillStyle = '#FFFFFF';
  ctx.shadowColor = 'rgba(15, 23, 42, 0.10)';
  ctx.shadowBlur = 16 * dpr;
  ctx.fill();
  ctx.shadowBlur = 0;

  // 5 concentric organ rings mapped from outer port_gate -> inner flag_heart
  const organLayers = target.organs.slice(0, 5);
  const ringStep = coreR > 50 * dpr ? 4.2 * dpr : 2.6 * dpr;
  organLayers.forEach((organ, idx) => {
    const ringR = Math.max(14 * dpr, coreR - 3 * dpr - idx * ringStep);
    const flash = vfx.organFlashUntil[organ.layer];
    const isFlashing = Boolean(flash && nowMs < flash.untilMs && isRunning);
    const ringColor = isFlashing
      ? flash.color
      : organ.state === 'compromised'
        ? '#DC2E33'
        : organ.state === 'patched'
          ? '#007AFF'
          : organ.state === 'probing'
            ? '#D1800A'
            : 'rgba(28, 148, 87, 0.45)';

    ctx.beginPath();
    if (organ.state === 'compromised' && isRunning) {
      const rot = nowMs * 0.0012 * (idx % 2 === 0 ? 1 : -1);
      ctx.arc(tx, ty, ringR, rot, rot + Math.PI * 1.45);
    } else {
      ctx.arc(tx, ty, ringR, 0, Math.PI * 2);
    }
    ctx.strokeStyle = ringColor;
    ctx.lineWidth = (isFlashing ? 2.8 : organ.state === 'intact' ? 1.3 : 2.0) * dpr;
    ctx.stroke();
  });

  // Clean inner circular label backing
  const innerR = Math.max(18 * dpr, coreR - organLayers.length * ringStep - 5 * dpr);
  ctx.beginPath();
  ctx.arc(tx, ty, innerR, 0, Math.PI * 2);
  ctx.fillStyle = '#FFFFFF';
  ctx.fill();
  ctx.strokeStyle = ownerSeat
    ? `${ownerSeat.team_color}40`
    : target.sla_healthy
      ? 'rgba(0, 122, 255, 0.16)'
      : 'rgba(220, 46, 51, 0.35)';
  ctx.lineWidth = 1.1 * dpr;
  ctx.stroke();

  if (kingSeat) {
    ctx.save();
    ctx.beginPath();
    ctx.arc(tx, ty, coreR + 5 * dpr, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(245, 158, 11, 0.48)';
    ctx.lineWidth = 1.6 * dpr;
    ctx.setLineDash([4 * dpr, 4 * dpr]);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.restore();
  }

  const isCompact = coreR < 50 * dpr;
  ctx.font = `700 ${(isCompact ? 9.2 : 11) * dpr}px -apple-system, "PingFang SC", sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = target.sla_healthy ? '#1A1A1E' : '#DC2E33';
  ctx.fillText(titleLabel, tx, kingSeat ? ty - 11 * dpr : ty - (isCompact ? 5.5 : 8) * dpr);

  if (subLabel) {
    ctx.font = `600 ${(isCompact ? 7.5 : 8.2) * dpr}px "SF Mono", "JetBrains Mono", monospace`;
    ctx.fillStyle = target.sla_healthy ? '#007AFF' : '#DC2E33';
    ctx.fillText(subLabel, tx, kingSeat ? ty + 2 * dpr : ty + (isCompact ? 6.5 : 8) * dpr);
  }

  if (kingSeat && !isCompact) {
    ctx.font = `700 ${8.5 * dpr}px -apple-system, "PingFang SC", sans-serif`;
    ctx.fillStyle = '#D97706';
    ctx.fillText(`👑 ${kingSeat.name}`, tx, ty + 16 * dpr);
  }
}

export const ColosseumCanvas: React.FC<ColosseumCanvasProps> = ({
  match,
  health,
  focusedSeatId,
  onSelectSeat,
  onInspectInXray,
  onOpenPoster,
  onOpenLobby,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const matchRef = useRef(match);
  matchRef.current = match;
  const focusedRef = useRef(focusedSeatId);
  focusedRef.current = focusedSeatId;

  const vfxRef = useRef<ColosseumVFXEngine | null>(null);
  if (!vfxRef.current) {
    vfxRef.current = new ColosseumVFXEngine();
  }

  const hitRegionsRef = useRef<HitRegion[]>([]);
  const [hoveringNode, setHoveringNode] = useState(false);
  const [activeCombo, setActiveCombo] = useState<ActiveComboBanner | null>(null);

  const isCompleted = match.status === 'completed' || match.status === 'finished';

  // Clear combo banner immediately when match concludes
  useEffect(() => {
    if (isCompleted) {
      setActiveCombo(null);
    }
  }, [isCompleted]);

  const rankedSeats = useMemo(() => {
    return [...match.seats].sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      if (a.tokens_used !== b.tokens_used) return a.tokens_used - b.tokens_used;
      return b.first_bloods - a.first_bloods;
    });
  }, [match.seats]);
  const winnerSeat = rankedSeats[0];

  const weaponCounts = useMemo(() => {
    const counts: Partial<Record<WeaponArchetype, number>> = {
      NANO_WELD: match.patches.length,
    };
    for (const evt of match.events) {
      const arch = classifyEventArchetype(evt);
      counts[arch] = (counts[arch] ?? 0) + 1;
    }
    return counts;
  }, [match.events, match.patches.length]);

  const [inspected, setInspected] = useState<{
    title: string;
    subtitle: string;
    accent: string;
    event?: EbpfEvent;
    seat?: SeatState;
    target?: TargetFortress;
  } | null>(null);

  useEffect(() => {
    const engine = vfxRef.current;
    if (!engine) return;
    engine.setComboListener((combo) => {
      if (matchRef.current.status !== 'running') return;
      setActiveCombo(combo);
      soundEngine.playComboChord(combo.multiplier);
    });
    return () => engine.dispose();
  }, []);

  useEffect(() => {
    vfxRef.current?.ingestMatchState(match);
  }, [match]);

  useEffect(() => {
    const canvas = canvasRef.current;
    const vfx = vfxRef.current;
    if (!canvas || !vfx) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let rafId = 0;
    let cancelled = false;

    const render = (_rafTs: number) => {
      const wAny = window as unknown as {
        __colosseumRafFrames?: number;
        __canvasRenderErrors?: string[];
      };
      wAny.__colosseumRafFrames = (wAny.__colosseumRafFrames ?? 0) + 1;

      try {
        const nowMs = performance.now();
        const m = matchRef.current;
        const isRunning = m.status === 'running';
        const focusedId = focusedRef.current;
        const dpr = window.devicePixelRatio || 1;
        const cw = canvas.clientWidth || 820;
        const ch = canvas.clientHeight || 500;
        if (canvas.width !== Math.floor(cw * dpr) || canvas.height !== Math.floor(ch * dpr)) {
          canvas.width = Math.floor(cw * dpr);
          canvas.height = Math.floor(ch * dpr);
        }

        const w = canvas.width;
        const h = canvas.height;
        const shake = isRunning ? vfx.getShakeOffset(dpr) : { dx: 0, dy: 0 };

        // Reserve generous top & bottom HUD chrome clearance so bottom seat labels NEVER clip!
        const safeTop = (m.status === 'completed' || m.status === 'finished' ? 78 : 56) * dpr;
        const safeBottom = 68 * dpr;
        const usableH = Math.max(140 * dpr, h - safeTop - safeBottom);
        const cx = w * 0.5 + shake.dx;
        const cy = safeTop + usableH * 0.49 + shake.dy;
        const maxR = Math.max(46 * dpr, Math.min(w * 0.35, usableH * 0.41));

        ctx.clearRect(0, 0, w, h);

        // 1. Crisp Apple Daylight Architectural Studio Backdrop + Subtle Engineering Grid
        const bgGrad = ctx.createLinearGradient(0, 0, w, h);
        bgGrad.addColorStop(0, '#FDFEFF');
        bgGrad.addColorStop(1, '#F1F4FA');
        ctx.fillStyle = bgGrad;
        ctx.fillRect(0, 0, w, h);

        ctx.save();
        const gridStep = 34 * dpr;
        ctx.fillStyle = 'rgba(15, 23, 42, 0.042)';
        for (let gx = (w % gridStep) * 0.5; gx < w; gx += gridStep) {
          for (let gy = (h % gridStep) * 0.5; gy < h; gy += gridStep) {
            ctx.fillRect(gx, gy, 1.2 * dpr, 1.2 * dpr);
          }
        }
        ctx.restore();

        // Radar Sweep (rotates ONLY while match is actively running; freezes cleanly when paused/completed!)
        ctx.save();
        if (isRunning) {
          const radarAng = nowMs * 0.00045;
          const sweepGrad = ctx.createRadialGradient(cx, cy, 24 * dpr, cx, cy, maxR);
          sweepGrad.addColorStop(0, 'rgba(0, 122, 255, 0.065)');
          sweepGrad.addColorStop(1, 'rgba(0, 122, 255, 0.0)');
          ctx.beginPath();
          ctx.moveTo(cx, cy);
          ctx.arc(cx, cy, maxR, radarAng, radarAng + 0.55);
          ctx.closePath();
          ctx.fillStyle = sweepGrad;
          ctx.fill();
        }

        [1.0, 0.74, 0.48, 0.24].forEach((scale, idx) => {
          const r = maxR * scale;
          ctx.beginPath();
          ctx.arc(cx, cy, r, 0, Math.PI * 2);
          ctx.strokeStyle = idx === 0 ? 'rgba(0, 0, 0, 0.085)' : 'rgba(0, 0, 0, 0.045)';
          ctx.lineWidth = 1.1 * dpr;
          if (idx === 1) ctx.setLineDash([5 * dpr, 5 * dpr]);
          ctx.stroke();
          ctx.setLineDash([]);
        });

        // Compass Degree Markers on outer ring
        ctx.font = `600 ${8.2 * dpr}px "SF Mono", monospace`;
        ctx.fillStyle = 'rgba(100, 116, 139, 0.5)';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        for (let deg = 0; deg < 360; deg += 30) {
          const rad = ((deg - 90) * Math.PI) / 180;
          const inner = maxR - 4 * dpr;
          const outer = maxR + (deg % 90 === 0 ? 6 : 3) * dpr;
          ctx.beginPath();
          ctx.moveTo(cx + Math.cos(rad) * inner, cy + Math.sin(rad) * inner);
          ctx.lineTo(cx + Math.cos(rad) * outer, cy + Math.sin(rad) * outer);
          ctx.strokeStyle = 'rgba(15, 23, 42, 0.13)';
          ctx.lineWidth = (deg % 90 === 0 ? 1.5 : 1) * dpr;
          ctx.stroke();
        }
        ctx.restore();

        // Mode-Aware Seat & Target Topology Coordinates
        const seatPos: Record<string, { x: number; y: number; angle: number; seat: SeatState }> = {};
        const targetPos: Record<string, { x: number; y: number; r: number; target: TargetFortress }> = {};
        const isMultiFortress =
          (m.mode === 'awd' || m.mode === 'speedrun') && m.targets.length > 1;

        if (m.mode === 'last_stand' && m.seats.length > 1) {
          // Defender sits anchored below Bastion Core; AI Besieger Swarms surround upper/outer arc
          const defender = m.seats.find((s) => s.role === 'defender') ?? m.seats[0];
          const besiegers = m.seats.filter((s) => s.id !== defender.id);
          seatPos[defender.id] = {
            x: cx,
            y: cy + maxR * 0.92,
            angle: Math.PI / 2,
            seat: defender,
          };
          besiegers.forEach((seat, bIdx) => {
            const span = Math.PI * 1.25;
            const angle =
              besiegers.length === 1
                ? -Math.PI / 2
                : -Math.PI / 2 - span * 0.5 + (bIdx / (besiegers.length - 1)) * span;
            seatPos[seat.id] = {
              x: cx + Math.cos(angle) * maxR,
              y: cy + Math.sin(angle) * maxR,
              angle,
              seat,
            };
          });
        } else {
          const nSeats = Math.max(1, m.seats.length);
          m.seats.forEach((seat, idx) => {
            // For 2 seats, place at Left (-180°) & Right (0°) or Top-Left & Bottom-Right?
            // Placing 2 seats at Left (180°) & Right (0°) gives huge horizontal breathing room and zero vertical overlap!
            const angle =
              nSeats === 2
                ? idx === 0
                  ? Math.PI
                  : 0
                : -Math.PI / 2 + (idx / nSeats) * Math.PI * 2;
            const sx = cx + Math.cos(angle) * maxR;
            const sy = cy + Math.sin(angle) * maxR;
            seatPos[seat.id] = { x: sx, y: sy, angle, seat };
          });
        }

        if (isMultiFortress) {
          const innerFortR = maxR * 0.47;
          const nT = Math.max(1, m.targets.length);
          m.targets.forEach((tg, idx) => {
            const ownerEntry = tg.owner_seat_id ? seatPos[tg.owner_seat_id] : undefined;
            const angle = ownerEntry
              ? ownerEntry.angle
              : -Math.PI / 2 + (idx / nT) * Math.PI * 2;
            const tx = cx + Math.cos(angle) * innerFortR;
            const ty = cy + Math.sin(angle) * innerFortR;
            const fortR = 34 * dpr;
            targetPos[tg.id] = { x: tx, y: ty, r: fortR, target: tg };

            // Draw owner guardianship tether between Seat <-> Own Fortress / Speedrun Pod
            if (ownerEntry) {
              ctx.save();
              ctx.beginPath();
              ctx.moveTo(ownerEntry.x, ownerEntry.y);
              ctx.lineTo(tx, ty);
              ctx.strokeStyle =
                m.mode === 'speedrun'
                  ? `${ownerEntry.seat.team_color}55`
                  : `${ownerEntry.seat.team_color}38`;
              ctx.lineWidth = 1.6 * dpr;
              ctx.setLineDash([4 * dpr, 4 * dpr]);
              ctx.stroke();
              ctx.setLineDash([]);
              ctx.restore();
            }
          });
        } else if (m.targets[0]) {
          const coreR = 66 * dpr;
          targetPos[m.targets[0].id] = { x: cx, y: cy, r: coreR, target: m.targets[0] };
          Object.values(seatPos).forEach(({ x, y }) => {
            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.lineTo(cx, cy);
            ctx.strokeStyle = 'rgba(0, 0, 0, 0.04)';
            ctx.lineWidth = 1 * dpr;
            ctx.stroke();
          });
        }

        const primaryTarget = m.targets[0];
        const nextHits: HitRegion[] = [];

        // Record beam hit regions for recent live events (only while running)
        if (isRunning) {
          const nowEpoch = Date.now();
          m.events
            .filter((e) => nowEpoch - e.ts_ms < 5200)
            .forEach((evt) => {
              const sNode = seatPos[evt.source_seat_id];
              const tNode = targetPos[evt.target_id] ?? (primaryTarget ? targetPos[primaryTarget.id] : undefined);
              if (!sNode || !tNode) return;
              nextHits.push({
                kind: 'beam',
                x: sNode.x,
                y: sNode.y,
                x2: tNode.x,
                y2: tNode.y,
                r: 14 * dpr,
                event: evt,
                seat: sNode.seat,
                target: tNode.target,
              });
            });
        }

        // 2. Render 60fps Command Weapons, Particles, Shockwaves & Combos (routed to exact Target Fortress!)
        if (isRunning) {
          ctx.save();
          try {
            vfx.renderFrame(ctx, w, h, cx, cy, maxR, dpr, nowMs, seatPos, primaryTarget, targetPos);
          } finally {
            ctx.restore();
          }
        }

        // 2b. Flowing Golden Grail Sovereignty Conduit from Fortress -> reigning King seat (Holy Grail mode)
        const kingSeat = m.seats.find((s) => s.is_grail_king);
        if (m.mode === 'grail' && kingSeat && seatPos[kingSeat.id]) {
          const kp = seatPos[kingSeat.id];
          const kAng = Math.atan2(kp.y - cy, kp.x - cx);
          const perpX = -Math.sin(kAng);
          const perpY = Math.cos(kAng);

          ctx.save();
          ctx.beginPath();
          ctx.moveTo(cx, cy);
          ctx.lineTo(kp.x, kp.y);
          ctx.strokeStyle = 'rgba(245, 158, 11, 0.16)';
          ctx.lineWidth = 10 * dpr;
          ctx.lineCap = 'round';
          ctx.stroke();

          [1, -1].forEach((dir) => {
            ctx.beginPath();
            const steps = 28;
            const phase = isRunning ? nowMs * 0.0055 : 0;
            for (let s = 0; s <= steps; s++) {
              const f = s / steps;
              const env = Math.sin(f * Math.PI);
              const wave = Math.sin(f * Math.PI * 3.5 - phase) * 6.5 * dpr * env * dir;
              const px = cx + (kp.x - cx) * f + perpX * wave;
              const py = cy + (kp.y - cy) * f + perpY * wave;
              if (s === 0) ctx.moveTo(px, py);
              else ctx.lineTo(px, py);
            }
            ctx.strokeStyle = dir > 0 ? 'rgba(245, 158, 11, 0.55)' : 'rgba(217, 119, 6, 0.38)';
            ctx.lineWidth = 1.6 * dpr;
            ctx.stroke();
          });

          if (isRunning) {
            for (let mIdx = 0; mIdx < 4; mIdx++) {
              const frac = (nowMs * 0.00055 + mIdx / 4) % 1;
              const mx = cx + (kp.x - cx) * frac;
              const my = cy + (kp.y - cy) * frac;
              ctx.beginPath();
              ctx.arc(mx, my, 3.2 * dpr, 0, Math.PI * 2);
              ctx.fillStyle = '#F59E0B';
              ctx.fill();
            }
          }
          ctx.restore();
        }

        // 3. Render Mode-Accurate Target Fortress Topology
        if (isMultiFortress) {
          // Central Referee / Timer Hub for AWD & Speedrun
          const hubR = 30 * dpr;
          ctx.beginPath();
          ctx.arc(cx, cy, hubR, 0, Math.PI * 2);
          ctx.fillStyle = '#FFFFFF';
          ctx.shadowColor = 'rgba(15, 23, 42, 0.08)';
          ctx.shadowBlur = 12 * dpr;
          ctx.fill();
          ctx.shadowBlur = 0;
          ctx.strokeStyle = 'rgba(0, 122, 255, 0.22)';
          ctx.lineWidth = 1.4 * dpr;
          ctx.stroke();

          ctx.font = `700 ${9 * dpr}px -apple-system, "PingFang SC", sans-serif`;
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillStyle = '#1A1A1E';
          ctx.fillText(m.mode === 'awd' ? 'AWD 裁判塔' : '竞速计时塔', cx, cy - 5 * dpr);
          ctx.font = `600 ${7.8 * dpr}px "SF Mono", monospace`;
          ctx.fillStyle = '#007AFF';
          ctx.fillText(`R${m.round}/${m.max_rounds}`, cx, cy + 7 * dpr);

          // Render each Team's Symmetric Fortress / Speedrun Pod
          Object.values(targetPos).forEach(({ x, y, r, target }) => {
            nextHits.push({ kind: 'target', x, y, r: r + 6 * dpr, target });
            const owner = target.owner_seat_id ? seatPos[target.owner_seat_id]?.seat : undefined;
            const shortTitle = owner
              ? m.mode === 'speedrun'
                ? `${owner.name} 靶舱`
                : `${owner.name} 堡垒`
              : target.name.slice(0, 8);
            const sub = target.sla_healthy ? `SLA ${target.sla_score.toFixed(0)}%` : 'SLA 告警';
            drawTargetFortressNode(
              ctx,
              x,
              y,
              r,
              target,
              shortTitle,
              sub,
              undefined,
              owner,
              vfx,
              nowMs,
              isRunning,
              dpr
            );
          });
        } else if (primaryTarget && targetPos[primaryTarget.id]) {
          const { x, y, r } = targetPos[primaryTarget.id];
          nextHits.push({ kind: 'target', x, y, r: r + 8 * dpr, target: primaryTarget });
          const centerTitle =
            m.mode === 'last_stand'
              ? '人类防线核心堡垒'
              : m.mode === 'grail'
                ? '中央圣杯堡垒'
                : primaryTarget.name || '目标堡垒';
          const fileLabel = primaryTarget.vulnerable_file
            ? `${primaryTarget.vulnerable_file}${primaryTarget.vulnerable_line > 0 ? `:${primaryTarget.vulnerable_line}` : ''}`
            : primaryTarget.ip;
          drawTargetFortressNode(
            ctx,
            x,
            y,
            r,
            primaryTarget,
            centerTitle,
            fileLabel,
            kingSeat,
            undefined,
            vfx,
            nowMs,
            isRunning,
            dpr
          );
        }

        // 4. Gladiator Seat Nodes
        Object.values(seatPos).forEach(({ x, y, seat }) => {
          const nodeR = 25 * dpr;
          nextHits.push({ kind: 'seat', x, y, r: nodeR * 1.3, seat });

          if (seat.is_grail_king) {
            const haloPulse = isRunning ? (Math.sin(nowMs * 0.005) + 1) * 0.5 : 0.4;
            ctx.beginPath();
            ctx.arc(x, y, nodeR + (7 + haloPulse * 3.2) * dpr, 0, Math.PI * 2);
            ctx.strokeStyle = 'rgba(245, 158, 11, 0.55)';
            ctx.lineWidth = 2.3 * dpr;
            ctx.stroke();
          }

          // Orbiting AI Synaptic Thinking Electrons ONLY while actively running & alive
          if (!seat.out_of_mana && isRunning) {
            const orbitR = nodeR + 10 * dpr;
            for (let e = 0; e < 3; e++) {
              const ang = nowMs * 0.0028 + (e * Math.PI * 2) / 3;
              const ex = x + Math.cos(ang) * orbitR;
              const ey = y + Math.sin(ang) * orbitR;
              ctx.beginPath();
              ctx.arc(ex, ey, 2.0 * dpr, 0, Math.PI * 2);
              ctx.fillStyle = seat.team_color;
              ctx.fill();
            }
          }

          ctx.beginPath();
          ctx.arc(x, y, nodeR, 0, Math.PI * 2);
          ctx.fillStyle = '#FFFFFF';
          ctx.shadowColor = seat.is_grail_king ? 'rgba(245, 158, 11, 0.25)' : 'rgba(0,0,0,0.08)';
          ctx.shadowBlur = 12 * dpr;
          ctx.fill();
          ctx.shadowBlur = 0;

          ctx.lineWidth = (seat.id === focusedId ? 3.2 : 2.2) * dpr;
          ctx.strokeStyle = seat.out_of_mana ? '#DC2E33' : seat.team_color;
          ctx.stroke();

          if (!seat.out_of_mana) {
            const manaFrac = Math.max(0.03, Math.min(1, seat.mana_remaining_pct / 100));
            ctx.beginPath();
            ctx.arc(
              x,
              y,
              nodeR + 3.8 * dpr,
              -Math.PI / 2,
              -Math.PI / 2 + Math.PI * 2 * manaFrac
            );
            ctx.strokeStyle = '#007AFF';
            ctx.lineWidth = 2.1 * dpr;
            ctx.lineCap = 'round';
            ctx.stroke();
            ctx.lineCap = 'butt';
          }

          ctx.font = `700 ${11 * dpr}px -apple-system, sans-serif`;
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillStyle = seat.out_of_mana ? '#DC2E33' : '#1A1A1E';
          ctx.fillText(seat.out_of_mana ? '402' : seat.name.slice(0, 2).toUpperCase(), x, y);

          // Crisp pill backing behind seat name & score for crystal-clear legibility
          const seatLabel = `${seat.is_grail_king ? '👑 ' : ''}${seat.name} · ${seat.score.toLocaleString()}`;
          drawRoundedPill(
            ctx,
            seatLabel,
            x,
            y + nodeR + 16 * dpr,
            'rgba(255,255,255,0.92)',
            '#1A1A1E',
            'rgba(0,0,0,0.07)',
            dpr
          );

          if (isRunning) {
            const lastCmd = vfx.seatLastCmd[seat.id];
            const comboSt = vfx.seatComboState[seat.id];
            if (comboSt && nowMs < comboSt.untilMs) {
              drawRoundedPill(
                ctx,
                `🔥 COMBO ×${comboSt.multiplier}`,
                x,
                y - nodeR - 16 * dpr,
                '#FFFBEB',
                '#D97706',
                'rgba(245, 158, 11, 0.45)',
                dpr
              );
            } else if (lastCmd && nowMs < lastCmd.untilMs) {
              drawRoundedPill(
                ctx,
                lastCmd.text,
                x,
                y - nodeR - 16 * dpr,
                'rgba(255,255,255,0.95)',
                lastCmd.color,
                'rgba(0,0,0,0.08)',
                dpr
              );
            }
          }
        });

        hitRegionsRef.current = nextHits;
      } catch (err) {
        wAny.__canvasRenderErrors = [...(wAny.__canvasRenderErrors ?? []), String(err)];
        console.error('[ColosseumCanvas] frame render error:', err);
      } finally {
        if (!cancelled) {
          rafId = window.requestAnimationFrame(render);
        }
      }
    };

    rafId = window.requestAnimationFrame(render);
    return () => {
      cancelled = true;
      window.cancelAnimationFrame(rafId);
    };
  }, []);

  useEffect(() => {
    if (!activeCombo) return;
    const t = window.setTimeout(() => setActiveCombo(null), 3800);
    return () => window.clearTimeout(t);
  }, [activeCombo]);

  const findHit = (e: React.MouseEvent<HTMLCanvasElement>): HitRegion | null => {
    const canvas = canvasRef.current;
    if (!canvas) return null;
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;
    const px = (e.clientX - rect.left) * scaleX;
    const py = (e.clientY - rect.top) * scaleY;

    for (const h of hitRegionsRef.current) {
      if ((h.kind === 'seat' || h.kind === 'target') && Math.hypot(px - h.x, py - h.y) <= h.r) {
        return h;
      }
    }
    for (const h of hitRegionsRef.current) {
      if (
        h.kind === 'beam' &&
        h.x2 !== undefined &&
        h.y2 !== undefined &&
        distToSegment(px, py, h.x, h.y, h.x2, h.y2) <= h.r
      ) {
        return h;
      }
    }
    return null;
  };

  const handleMouseMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const hit = findHit(e);
    setHoveringNode(Boolean(hit));
  };

  const handleCanvasClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const hit = findHit(e);
    if (!hit) return;

    if (hit.kind === 'seat' && hit.seat) {
      onSelectSeat(hit.seat.id);
      const latestSeatEvt = match.events.find((ev) => ev.source_seat_id === hit.seat?.id);
      setInspected({
        title: `${hit.seat.name} (${hit.seat.model})`,
        subtitle: `容器 ${hit.seat.ip || 'sandbox'} · 剩余额度 ${hit.seat.mana_remaining_pct.toFixed(0)}%`,
        accent: hit.seat.team_color,
        seat: hit.seat,
        event: latestSeatEvt,
      });
    } else if (hit.kind === 'target' && hit.target) {
      const latestTargetEvt = match.events.find((ev) => ev.target_id === hit.target?.id);
      setInspected({
        title: hit.target.name,
        subtitle: `${hit.target.ip || 'target'} · SLA ${hit.target.sla_score.toFixed(0)}%`,
        accent: '#007AFF',
        target: hit.target,
        event: latestTargetEvt,
      });
    } else if (hit.kind === 'beam' && hit.event) {
      setInspected({
        title: `底层事件 · ${hit.event.vfx_type}`,
        subtitle: `${hit.event.probe} · PID ${hit.event.pid}`,
        accent: hit.event.vfx_type === 'NANO_PATCH_WELD' ? '#007AFF' : '#DC2E33',
        event: hit.event,
        seat: hit.seat,
      });
    }
  };

  const perf = health?.ebpf?.perf_stats;

  return (
    <div className="w-full h-full grid grid-cols-1 lg:grid-cols-12 gap-3.5 min-h-0">
      {/* Left/Center: Daylight Colosseum Radar Card */}
      <div className="lg:col-span-9 apple-card relative overflow-hidden min-h-0">
        <canvas
          ref={canvasRef}
          onMouseMove={handleMouseMove}
          onClick={handleCanvasClick}
          style={{ cursor: hoveringNode ? 'pointer' : 'default' }}
          className="w-full h-full block"
        />

        {/* Top Bar Overlay: Championship Settlement Banner when Completed, else Live Camera Cue */}
        {isCompleted ? (
          <div className="absolute top-3.5 left-4 right-4 z-20 px-4 py-2.5 rounded-2xl bg-white/96 backdrop-blur-xl border border-[#1C9457]/25 shadow-[0_8px_24px_rgba(0,0,0,0.08)] flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="w-8 h-8 rounded-xl bg-[#FEF3C7] text-[#D97706] flex items-center justify-center shrink-0">
                <Award className="w-4 h-4" />
              </div>
              <div className="min-w-0">
                <div className="text-[12.5px] font-bold text-[#1A1A1E] truncate">
                  对决已完赛结算
                  {winnerSeat
                    ? ` · 冠军：${winnerSeat.name}（${winnerSeat.score.toLocaleString()} 分 · 耗费 ${winnerSeat.tokens_used.toLocaleString()} Tokens）`
                    : ''}
                </div>
                <div className="text-[11px] text-[#61626A] truncate">
                  全部容器沙箱已冻结回收 · 总用时 {match.elapsed_sec}s · 捕获 {match.events.length} 条真实 eBPF 战果
                </div>
              </div>
            </div>

            <div className="flex items-center gap-2 shrink-0">
              {onOpenPoster && (
                <button
                  type="button"
                  onClick={onOpenPoster}
                  className="h-7 px-3 rounded-full bg-[#F4F5F8] hover:bg-[#EAECEF] text-[11.5px] font-semibold text-[#1A1A1E] flex items-center gap-1 transition-colors"
                >
                  <Sparkles className="w-3 h-3 text-[#D97706]" />
                  <span>生成战报</span>
                </button>
              )}
              {onOpenLobby && (
                <button
                  type="button"
                  onClick={onOpenLobby}
                  className="h-7 px-3 rounded-full bg-[#007AFF] hover:bg-[#0066D6] text-[11.5px] font-semibold text-white flex items-center gap-1 transition-colors"
                >
                  <Plus className="w-3 h-3" />
                  <span>新建对决</span>
                </button>
              )}
            </div>
          </div>
        ) : (
          <div className="absolute top-3.5 left-4 z-10 px-3.5 py-1.5 rounded-full bg-white/94 border border-black/[0.07] shadow-[0_2px_8px_rgba(0,0,0,0.04)] flex items-center gap-2 text-[12px] text-[#1A1A1E] pointer-events-none">
            <Crosshair className="w-3.5 h-3.5 text-[#007AFF]" />
            <span className="font-medium truncate max-w-md">
              {match.status === 'paused'
                ? '比赛已暂停 · 容器攻防时钟暂时冻结'
                : match.camera_cue?.reason || '实时追踪各席位底层命令特效、连招组合与代码热修复'}
            </span>
          </div>
        )}

        {/* Top-Right Live Multi-Command Combo Announcer Banner */}
        {!isCompleted && activeCombo && (
          <div className="absolute top-3.5 right-4 z-20 max-w-[360px] px-3.5 py-2 rounded-2xl bg-white/95 backdrop-blur-xl border border-black/[0.09] shadow-[0_10px_28px_rgba(0,0,0,0.12)] flex items-center gap-2.5 animate-kill-in pointer-events-none">
            <span
              className="px-2 py-0.5 rounded-full text-[10.5px] font-extrabold text-white shrink-0 flex items-center gap-1"
              style={{ backgroundColor: activeCombo.color }}
            >
              <Flame className="w-3 h-3" />
              COMBO ×{activeCombo.multiplier}
            </span>
            <div className="min-w-0">
              <div className="text-[12px] font-bold text-[#1A1A1E] leading-tight truncate">
                {activeCombo.title}
              </div>
              <div className="text-[10.5px] text-[#61626A] leading-tight mt-0.5 truncate">
                {activeCombo.subtitle}
              </div>
            </div>
          </div>
        )}

        {/* Bottom-Left Apple Glass Live Kernel Weapon & Per-CPU RingBuf Telemetry Dock */}
        <div className="absolute bottom-3 left-4 right-4 z-10 px-3.5 py-2 rounded-2xl bg-white/92 backdrop-blur-xl border border-black/[0.07] shadow-[0_6px_18px_rgba(0,0,0,0.06)] flex flex-wrap items-center justify-between gap-2 text-[11px] text-[#61626A] pointer-events-none">
          <div className="flex flex-wrap items-center gap-2.5">
            <span className="font-semibold text-[#1A1A1E]">内核武器遥测</span>
            {KERNEL_TELEMETRY_WEAPONS.map((key) => {
              const cnt = weaponCounts[key] ?? 0;
              const meta = WEAPON_META[key];
              return (
                <span key={key} className="flex items-center gap-1">
                  <span
                    className="w-2 h-2 rounded-full"
                    style={{ backgroundColor: meta.color, opacity: cnt > 0 ? 1 : 0.38 }}
                  />
                  <span className={cnt > 0 ? 'font-semibold text-[#1A1A1E]' : ''}>
                    {meta.zhLabel}
                  </span>
                  <span
                    className="font-mono tabular-nums font-bold px-1.5 py-0.2 rounded-full text-[10px]"
                    style={{
                      backgroundColor: cnt > 0 ? `${meta.color}16` : 'rgba(0,0,0,0.04)',
                      color: cnt > 0 ? meta.color : '#8E8F97',
                    }}
                  >
                    {cnt}
                  </span>
                </span>
              );
            })}
          </div>

          {perf && (
            <div className="hidden xl:flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-[#007AFF]/[0.08] text-[#007AFF] font-mono text-[10.5px] font-semibold">
              <span>⚡ Ring-0 直滤 {perf.kernel_filter_pct.toFixed(1)}%</span>
              <span>·</span>
              <span>{(perf.ringbuf_capacity_bytes / (1024 * 1024)).toFixed(0)}MB RingBuf</span>
              <span>·</span>
              <span>Drop {perf.ringbuf_drops}</span>
            </div>
          )}
        </div>

        {/* Clicked Node Inspector Popover */}
        {inspected && (
          <div className="absolute top-16 right-4 z-30 w-88 max-w-sm rounded-2xl bg-white/96 backdrop-blur-xl border border-black/[0.09] shadow-[0_14px_34px_rgba(0,0,0,0.12)] p-3.5 text-xs space-y-2.5">
            <div className="flex items-start justify-between gap-2 pb-2 border-b border-black/[0.06]">
              <div>
                <div className="font-bold text-[13px] text-[#1A1A1E]">{inspected.title}</div>
                <div className="font-mono text-[10.5px] text-[#61626A] mt-0.5">
                  {inspected.subtitle}
                </div>
              </div>
              <button
                type="button"
                onClick={() => setInspected(null)}
                className="w-6 h-6 rounded-full bg-black/[0.05] hover:bg-black/[0.1] flex items-center justify-center text-[#61626A]"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>

            {inspected.event ? (
              <div className="space-y-1.5 font-mono text-[11px]">
                <div className="flex justify-between text-[#61626A]">
                  <span>探针:</span>
                  <span className="text-[#007AFF] font-semibold">
                    {inspected.event.probe}
                    {inspected.event.kernel_latency_ns
                      ? ` (${(inspected.event.kernel_latency_ns / 1000).toFixed(1)}µs)`
                      : ''}
                  </span>
                </div>
                <div className="p-2 rounded-xl bg-[#F6F7FA] border border-black/[0.05] text-[#1A1A1E] break-all">
                  $ {inspected.event.cmdline}
                </div>
              </div>
            ) : (
              <div className="text-[#1C9457] text-[11.5px] flex items-center gap-1.5 font-medium">
                <ShieldCheck className="w-4 h-4" />
                宿主机 eBPF 探针已绑定该容器 cgroup 命名空间
              </div>
            )}

            <button
              type="button"
              onClick={onInspectInXray}
              className="w-full py-1.5 rounded-xl bg-[#007AFF] hover:bg-[#0066D6] text-white font-semibold text-[11.5px] flex items-center justify-center gap-1.5"
            >
              <Terminal className="w-3.5 h-3.5" />
              <span>打开底层检视台查看终端与补丁</span>
            </button>
          </div>
        )}
      </div>

      {/* Right: Clean Apple Live Event Feed Card */}
      <div className="lg:col-span-3 apple-card p-4 flex flex-col min-h-0">
        <div className="flex items-center justify-between pb-3 mb-2.5 border-b border-black/[0.06] shrink-0">
          <span className="flex items-center gap-1.5 text-[13.5px] font-bold text-[#1A1A1E]">
            <Zap className="w-4 h-4 text-[#007AFF]" />
            实时攻防动态
          </span>
          <span className="text-[10.5px] font-medium text-[#6F7078]">
            {isCompleted ? '本局归档' : 'eBPF 实时驱动'}
          </span>
        </div>

        <div className="flex-1 overflow-y-auto pr-0.5">
          {match.kill_feed.length > 0 ? (
            <KillFeedOverlay items={match.kill_feed} />
          ) : (
            <div className="h-full flex flex-col items-center justify-center text-center px-4 py-8 text-[#6F7078] space-y-1.5">
              <Zap className="w-5 h-5 text-[#007AFF]/50" />
              <div className="text-[12px] font-semibold text-[#1A1A1E]">
                等待真实内核攻防信号
              </div>
              <div className="text-[11px] leading-relaxed">
                容器内执行命令、夺旗或源码热修复后将由宿主机 eBPF 实时推送至此
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
