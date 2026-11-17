import { LEGENDARY_HARNESSES } from '../data/armoryCatalog';
import { soundEngine } from '../audio/soundEngine';
import {
  ArmoryMap,
  CasterLine,
  CreateMatchRequest,
  EbpfEvent,
  HarnessSpec,
  HealthResponse,
  KillFeedItem,
  LeaderboardEntry,
  MapCategory,
  MatchState,
  OrganStatus,
  PatchEvent,
  SavedReplaySummary,
  WebHijackEvent,
} from '../types/pit';

const STORAGE_KEY = 'pit_api_base_url';

export function getSavedApiBaseUrl(): string {
  if (typeof window === 'undefined') return '';
  return window.localStorage.getItem(STORAGE_KEY) ?? '';
}

export function setSavedApiBaseUrl(url: string): void {
  if (typeof window === 'undefined') return;
  const trimmed = url.trim().replace(/\/+$/, '');
  window.localStorage.setItem(STORAGE_KEY, trimmed);
}

function resolveApiUrl(path: string, baseOverride?: string): string {
  const base = (baseOverride ?? getSavedApiBaseUrl()).replace(/\/+$/, '');
  if (!base) return path;
  return `${base}${path}`;
}

export function resolveWsUrl(matchId: string, baseOverride?: string): string {
  const base = (baseOverride ?? getSavedApiBaseUrl()).replace(/\/+$/, '');
  if (base) {
    const wsBase = base.replace(/^http:/i, 'ws:').replace(/^https:/i, 'wss:');
    return `${wsBase}/api/v1/ws?match_id=${encodeURIComponent(matchId)}`;
  }
  const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  return `${proto}//${window.location.host}/api/v1/ws?match_id=${encodeURIComponent(matchId)}`;
}

async function fetchJsonWithTimeout<T>(
  url: string,
  init?: RequestInit,
  timeoutMs = 2600
): Promise<T> {
  const ctrl = new AbortController();
  const timer = window.setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      ...init,
      signal: ctrl.signal,
      headers: {
        'Content-Type': 'application/json',
        ...(init?.headers ?? {}),
      },
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    return (await res.json()) as T;
  } finally {
    window.clearTimeout(timer);
  }
}

export async function probePitHealth(baseOverride?: string): Promise<{
  health: HealthResponse;
  resolvedBase: string;
} | null> {
  const candidates =
    baseOverride !== undefined
      ? [baseOverride]
      : getSavedApiBaseUrl()
        ? [getSavedApiBaseUrl(), '']
        : ['', 'http://127.0.0.1:18880'];

  for (const base of candidates) {
    try {
      const data = await fetchJsonWithTimeout<Record<string, unknown>>(
        resolveApiUrl('/api/v1/health', base),
        undefined,
        1600
      );
      if (data && typeof data === 'object') {
        const ebpfRaw =
          (data.ebpf as Record<string, unknown> | undefined) ??
          (data.ebpf_sensor as Record<string, unknown> | undefined) ??
          {};
        const perfRaw = ebpfRaw.perf_stats as Record<string, unknown> | undefined;
        const health: HealthResponse = {
          status: String(data.status ?? 'ok'),
          version: String(data.version ?? '1.0.0'),
          ebpf: {
            mode: String(ebpfRaw.mode ?? 'offline'),
            btf_enabled: Boolean(ebpfRaw.btf_enabled ?? false),
            kernel_release: ebpfRaw.kernel_release ? String(ebpfRaw.kernel_release) : undefined,
            ssl_libraries_hooked: ebpfRaw.ssl_libraries_hooked
              ? Number(ebpfRaw.ssl_libraries_hooked)
              : 0,
            tracked_containers: ebpfRaw.tracked_containers
              ? Number(ebpfRaw.tracked_containers)
              : 0,
            attached_probes: Array.isArray(ebpfRaw.attached_probes)
              ? (ebpfRaw.attached_probes as string[])
              : [],
            events_captured: Number(ebpfRaw.events_captured ?? 0),
            perf_stats: perfRaw
              ? {
                  cpu_cores: Number(perfRaw.cpu_cores ?? 0),
                  ringbuf_capacity_bytes: Number(perfRaw.ringbuf_capacity_bytes ?? 4194304),
                  syscalls_entered: Number(perfRaw.syscalls_entered ?? 0),
                  filtered_in_kernel: Number(perfRaw.filtered_in_kernel ?? 0),
                  ringbuf_submitted: Number(perfRaw.ringbuf_submitted ?? 0),
                  ringbuf_drops: Number(perfRaw.ringbuf_drops ?? 0),
                  execve_submitted: Number(perfRaw.execve_submitted ?? 0),
                  connect_submitted: Number(perfRaw.connect_submitted ?? 0),
                  openat_submitted: Number(perfRaw.openat_submitted ?? 0),
                  security_submitted: Number(perfRaw.security_submitted ?? 0),
                  kernel_filter_pct: Number(perfRaw.kernel_filter_pct ?? 0),
                  syscalls_per_sec: Number(perfRaw.syscalls_per_sec ?? 0),
                  events_per_sec: Number(perfRaw.events_per_sec ?? 0),
                }
              : undefined,
          },
          docker: data.docker as HealthResponse['docker'],
          active_matches: Number(data.active_matches ?? data.active_match_count ?? 0),
        };
        if (base && !getSavedApiBaseUrl()) {
          setSavedApiBaseUrl(base);
        }
        return { health, resolvedBase: base };
      }
    } catch {
      // try next candidate
    }
  }
  return null;
}

export async function fetchArmoryFromApi(): Promise<{
  maps?: ArmoryMap[];
  harnesses?: HarnessSpec[];
} | null> {
  try {
    const raw = await fetchJsonWithTimeout<Record<string, unknown>>(resolveApiUrl('/api/v1/armory'));
    const rawMaps = Array.isArray(raw.maps) ? (raw.maps as Array<Record<string, unknown>>) : [];
    const rawHarnesses = Array.isArray(raw.harnesses)
      ? (raw.harnesses as Array<Record<string, unknown>>)
      : [];

    const maps: ArmoryMap[] = rawMaps.map((m) => ({
      id: String(m.id ?? 'map'),
      name: String(m.name ?? m.id ?? 'Target Map'),
      subtitle: m.subtitle ? String(m.subtitle) : undefined,
      category: (String(m.category ?? 'web') as MapCategory),
      difficulty: Number(m.difficulty ?? 3),
      summary: String(m.summary ?? ''),
      tags: Array.isArray(m.tags) ? (m.tags as string[]) : [],
      mitre: Array.isArray(m.mitre) ? (m.mitre as string[]) : [],
      ports: Array.isArray(m.ports) && m.ports.length ? (m.ports as number[]) : [8080],
      ram_mb: Number(m.ram_mb ?? 2048),
      supports_awd_patch: Boolean(m.supports_awd_patch ?? true),
    }));

    const harnesses: HarnessSpec[] = rawHarnesses.map((h) => {
      const id = String(h.id ?? 'custom');
      const preset = LEGENDARY_HARNESSES.find((p) => p.id === id);
      const rawCaps = h.capabilities;
      const capsObj =
        rawCaps && typeof rawCaps === 'object' && !Array.isArray(rawCaps)
          ? (rawCaps as HarnessSpec['capabilities'])
          : preset?.capabilities ?? { recon: 90, exploit: 92, patch: 85, efficiency: 88 };
      const capTags = Array.isArray(rawCaps)
        ? (rawCaps as string[])
        : Array.isArray(h.tags)
          ? (h.tags as string[])
          : preset?.tags ?? [];

      const starsNum = typeof h.stars === 'number' ? h.stars : preset?.stars_num ?? 20000;
      const starsStr =
        typeof h.stars_display === 'string' && h.stars_display
          ? h.stars_display
          : typeof h.stars === 'string'
            ? h.stars
            : preset?.stars ?? `${(starsNum / 1000).toFixed(1)}k ★`;

      return {
        id,
        name: String(h.name ?? preset?.name ?? id),
        developer: String(h.developer ?? preset?.developer ?? 'Open Source'),
        stars: starsStr,
        stars_num: starsNum,
        language: String(h.language ?? preset?.language ?? 'Multi-Agent'),
        tagline: String(h.tagline ?? h.summary ?? preset?.tagline ?? ''),
        accent_color: String(h.accent_color ?? preset?.accent_color ?? '#FF3B30'),
        capabilities: capsObj,
        tags: capTags.slice(0, 4),
        adapter_cmd: String(h.adapter_cmd ?? preset?.adapter_cmd ?? ''),
      };
    });

    return {
      maps: maps.length ? maps : undefined,
      harnesses: harnesses.length ? harnesses : undefined,
    };
  } catch {
    return null;
  }
}

export async function fetchLeaderboardFromApi(): Promise<LeaderboardEntry[] | null> {
  try {
    const res = await fetchJsonWithTimeout<
      Array<Record<string, unknown>> | { entries?: Array<Record<string, unknown>>; leaderboard?: Array<Record<string, unknown>> }
    >(resolveApiUrl('/api/v1/leaderboard'));
    const rawList = Array.isArray(res) ? res : res?.leaderboard ?? res?.entries ?? [];
    if (!rawList.length) return [];

    return rawList.map((r, idx) => {
      const avgTok = Number(r.avg_tokens_per_solve ?? 0);
      return {
        rank: Number(r.rank ?? idx + 1),
        id: String(r.id ?? `lb-${idx + 1}`),
        combatant_name: String(
          r.combatant_name ??
            (r.default_model ? `${r.name} × ${r.default_model}` : r.name ?? '')
        ),
        kind: (r.kind as LeaderboardEntry['kind']) ?? 'harness',
        harness_id: String(r.harness_id ?? ''),
        base_model: String(r.base_model ?? r.default_model ?? ''),
        accent_color: String(r.accent_color ?? '#007AFF'),
        matches_played: Number(r.matches_played ?? 0),
        win_rate: Number(r.win_rate ?? 0),
        total_score: Number(r.total_score ?? 0),
        first_bloods: Number(r.first_bloods ?? r.first_blood_count ?? 0),
        patches_verified: Number(r.patches_verified ?? 0),
        avg_tokens_per_solve: avgTok,
        efficiency_king: Boolean(r.efficiency_king ?? (avgTok > 0 && idx === 0)),
      };
    });
  } catch {
    return null;
  }
}

export async function fetchMatchHistoryFromApi(): Promise<SavedReplaySummary[] | null> {
  try {
    const listRaw = await fetchJsonWithTimeout<
      Array<Record<string, unknown>> | { matches?: Array<Record<string, unknown>> }
    >(resolveApiUrl('/api/v1/matches'));
    const arr = Array.isArray(listRaw) ? listRaw : listRaw?.matches ?? [];
    return arr.map((m) => {
      const lb = Array.isArray(m.leaderboard) ? (m.leaderboard as Array<Record<string, unknown>>) : [];
      const top = lb[0];
      const manaVals = lb
        .map((r) => (r.mana_remaining_pct !== undefined ? Number(r.mana_remaining_pct) : null))
        .filter((v): v is number => v !== null);
      const avgMana = manaVals.length
        ? manaVals.reduce((acc, v) => acc + v, 0) / manaVals.length
        : 0;
      const createdAt = String(m.ended_at || m.created_at || '');
      return {
        id: String(m.id ?? ''),
        title: String(m.title ?? m.id ?? ''),
        mode: (m.mode as SavedReplaySummary['mode']) ?? 'grail',
        map_id: String(m.map_id ?? ''),
        map_name: String(m.map_name ?? m.map_id ?? ''),
        winner_name: String(top?.name ?? m.winner_seat_id ?? (m.status === 'running' ? '进行中' : '—')),
        winner_color: String(top?.team_color ?? '#007AFF'),
        winner_model: String(top?.model ?? ''),
        duration_sec: Number(m.elapsed_sec ?? 0),
        total_ebpf_events: Number(m.events_count ?? 0),
        first_blood_sec: 0,
        avg_mana_left_pct: Number(avgMana.toFixed(1)),
        recorded_at: createdAt ? createdAt.replace('T', ' ').replace('Z', ' UTC').slice(0, 19) : '',
      };
    });
  } catch {
    return null;
  }
}

export async function fetchMatchByIdFromApi(matchId: string): Promise<MatchState | null> {
  try {
    const detail = await fetchJsonWithTimeout<Record<string, unknown>>(
      resolveApiUrl(`/api/v1/matches/${encodeURIComponent(matchId)}`)
    );
    return normalizeServerMatchState((detail.match as Record<string, unknown>) ?? detail);
  } catch {
    return null;
  }
}

export async function createMatchOnApi(req: CreateMatchRequest): Promise<MatchState | null> {
  try {
    const raw = await fetchJsonWithTimeout<Record<string, unknown>>(
      resolveApiUrl('/api/v1/matches'),
      {
        method: 'POST',
        body: JSON.stringify(req),
      },
      20000
    );
    const stateObj = (raw.match as Record<string, unknown>) ?? raw;
    return normalizeServerMatchState(stateObj, req);
  } catch {
    return null;
  }
}

export async function fetchActiveMatchFromApi(): Promise<MatchState | null> {
  try {
    const listRaw = await fetchJsonWithTimeout<
      Array<Record<string, unknown>> | { matches?: Array<Record<string, unknown>> }
    >(resolveApiUrl('/api/v1/matches'));
    const arr = Array.isArray(listRaw) ? listRaw : listRaw?.matches ?? [];
    if (!arr.length) return null;
    const active = arr.find((m) => m.status === 'running') ?? arr[0];
    const matchId = String(active.id ?? active.match_id ?? '');
    if (!matchId) return null;
    const detail = await fetchJsonWithTimeout<Record<string, unknown>>(
      resolveApiUrl(`/api/v1/matches/${encodeURIComponent(matchId)}`)
    );
    return normalizeServerMatchState((detail.match as Record<string, unknown>) ?? detail);
  } catch {
    return null;
  }
}

export async function sendMatchControlApi(
  matchId: string,
  body: Record<string, unknown>
): Promise<boolean> {
  try {
    await fetchJsonWithTimeout(
      resolveApiUrl(`/api/v1/matches/${encodeURIComponent(matchId)}/control`),
      {
        method: 'POST',
        body: JSON.stringify(body),
      }
    );
    return true;
  } catch {
    return false;
  }
}

export async function sendSeatInterveneApi(
  matchId: string,
  seatId: string,
  body: Record<string, unknown>
): Promise<boolean> {
  try {
    await fetchJsonWithTimeout(
      resolveApiUrl(
        `/api/v1/matches/${encodeURIComponent(matchId)}/seats/${encodeURIComponent(seatId)}/intervene`
      ),
      {
        method: 'POST',
        body: JSON.stringify(body),
      }
    );
    return true;
  } catch {
    return false;
  }
}

export function getReplayHtmlApiUrl(matchId: string): string {
  return resolveApiUrl(`/api/v1/matches/${encodeURIComponent(matchId)}/replay.html`);
}

function mapToneToMood(tone?: unknown): CasterLine['mood'] {
  const t = String(tone ?? 'HYPE').toUpperCase();
  if (t === 'SAVAGE' || t === 'ROAST') return 'ROAST';
  if (t === 'TACTICAL' || t === 'CLUTCH') return 'CLUTCH';
  if (t === 'CRITICAL') return 'CRITICAL';
  if (t === 'SYSTEM') return 'SYSTEM';
  return 'HYPE';
}

function normalizeKillFeedItem(k: Record<string, unknown>, tsFallback: number): KillFeedItem {
  const cat = String(k.category ?? '');
  return {
    id: String(k.id ?? `kf-${tsFallback}-${Math.random().toString(36).slice(2, 6)}`),
    ts_ms: Number(k.ts_ms ?? tsFallback),
    probe_tag: String(k.probe_tag ?? (k.weapon ? `[${k.weapon}]` : `[${cat || 'eBPF'}]`)),
    actor_seat_id: String(k.actor_seat_id ?? ''),
    actor_name: String(k.actor_name ?? 'Gladiator'),
    actor_color: String(k.actor_color ?? '#FF3B30'),
    victim_name: String(k.victim_name ?? ''),
    action_label: String(k.action_label ?? k.headline ?? k.text ?? 'Breach'),
    is_first_blood: Boolean(k.is_first_blood ?? cat === 'FIRST_BLOOD'),
    is_patch: Boolean(k.is_patch ?? cat === 'PATCH'),
    is_mana_dry: Boolean(k.is_mana_dry ?? cat === 'OUT_OF_MANA'),
    is_grail: Boolean(k.is_grail ?? cat === 'GRAIL'),
    points_delta: k.points_delta ? Number(k.points_delta) : undefined,
  };
}

function normalizeEbpfPayload(payload: Record<string, unknown>, ts: number): EbpfEvent {
  return {
    id: String(payload.id ?? `ebpf-${ts}-${Math.random().toString(36).slice(2, 6)}`),
    ts_ms: ts,
    probe: String(payload.probe ?? 'sched_process_exec'),
    vfx_type: (payload.vfx_type as EbpfEvent['vfx_type']) ?? 'PRECISION_EXPLOIT_BEAM',
    source_seat_id: String(payload.source_seat_id ?? ''),
    target_id: String(payload.target_id ?? ''),
    organ_layer: (payload.organ_layer as EbpfEvent['organ_layer']) ?? 'code_organ',
    cgroup_id: Number(payload.cgroup_id ?? 0),
    pid: Number(payload.pid ?? 0),
    ppid: Number(payload.ppid ?? 0),
    uid: Number(payload.uid ?? 0),
    comm: String(payload.comm ?? ''),
    parent_comm: String(payload.parent_comm ?? ''),
    cmdline: String(payload.cmdline ?? ''),
    src_ip: String(payload.src_ip ?? ''),
    dst_ip: String(payload.dst_ip ?? ''),
    dst_port: Number(payload.dst_port ?? 0),
    cleartext_payload: payload.cleartext_payload ? String(payload.cleartext_payload) : undefined,
    process_tree: Array.isArray(payload.process_tree) ? (payload.process_tree as string[]) : undefined,
    hit_location: payload.hit_location ? String(payload.hit_location) : undefined,
    kernel_ts_ns: payload.kernel_ts_ns ? Number(payload.kernel_ts_ns) : undefined,
    kernel_latency_ns: payload.kernel_latency_ns ? Number(payload.kernel_latency_ns) : undefined,
  };
}

// Normalizes pitd MatchState (Go structs in pitd/internal/model/types.go) cleanly into UI MatchState
export function normalizeServerMatchState(
  raw: Record<string, unknown>,
  fallbackReq?: CreateMatchRequest
): MatchState {
  const budget = Number(raw.token_budget ?? fallbackReq?.token_budget ?? 1_000_000);
  const kingSeatId = raw.king_seat_id ? String(raw.king_seat_id) : null;
  const rawSeats = Array.isArray(raw.seats) ? (raw.seats as Array<Record<string, unknown>>) : [];

  const seats: MatchState['seats'] = rawSeats.map((s, idx) => {
    const id = String(s.id ?? `seat-${idx + 1}`);
    const used = Number(s.tokens_used ?? 0);
    const sBudget = Number(s.token_budget ?? budget);
    const pct =
      s.mana_remaining_pct !== undefined
        ? Number(s.mana_remaining_pct)
        : Math.max(0, ((sBudget - used) / Math.max(1, sBudget)) * 100);
    const outOfMana = Boolean(
      s.out_of_mana ?? s.mana_exhausted ?? (s.status === 'out_of_mana' || pct <= 0)
    );

    return {
      id,
      name: String(s.name ?? `Gladiator ${idx + 1}`),
      kind: (s.kind as MatchState['seats'][0]['kind']) ?? 'harness',
      harness_id: String(s.harness_id ?? 'strix'),
      model: String(s.model ?? 'claude-sonnet-4-6'),
      team_color: String(s.team_color ?? '#FF3B30'),
      score: Number(s.score ?? 0),
      is_grail_king: Boolean(s.is_grail_king ?? (kingSeatId && kingSeatId === id)),
      first_bloods: Number(s.first_bloods ?? s.first_blood_count ?? 0),
      flags_captured: Number(s.flags_captured ?? 0),
      patches_verified: Number(s.patches_verified ?? 0),
      tokens_used: used,
      token_budget: sBudget,
      mana_remaining_pct: Number(pct.toFixed(1)),
      out_of_mana: outOfMana,
      burn_rate_tps: Number(s.burn_rate_tps ?? 0),
      sla_healthy: s.sla_healthy !== undefined ? Boolean(s.sla_healthy) : s.status !== 'flatlined',
      sla_score: Number(s.sla_score ?? 100),
      sla_latency_ms: Number(s.sla_latency_ms ?? 0),
      sla_detail: String(s.sla_detail ?? ''),
      ecg_samples: Array.isArray(s.ecg_samples)
        ? (s.ecg_samples as number[])
        : [],
      thought: String(
        s.thought ?? s.last_thought ?? s.current_action ?? ''
      ),
      possessed: Boolean(s.possessed ?? s.status === 'possessed'),
      ip: String(s.ip ?? s.container_ip ?? ''),
    };
  });

  const rawTargets = Array.isArray(raw.targets)
    ? (raw.targets as Array<Record<string, unknown>>)
    : [];

  const extractedPatches: PatchEvent[] = [];
  const extractedWebHijacks: WebHijackEvent[] = [];

  const targets: MatchState['targets'] = rawTargets.length
    ? rawTargets.map((t, idx) => {
        const rawOrgans = Array.isArray(t.organs) ? (t.organs as Array<Record<string, unknown>>) : [];
        const organs: OrganStatus[] =
          rawOrgans.length > 0
            ? rawOrgans.map((o, oIdx) => {
                const st = String(o.state ?? o.status ?? 'intact');
                const mappedState: OrganStatus['state'] =
                  st === 'breached' || st === 'compromised'
                    ? 'compromised'
                    : st === 'probed' || st === 'probing'
                      ? 'probing'
                      : st === 'patched'
                        ? 'patched'
                        : 'intact';
                return {
                  layer: (o.layer as OrganStatus['layer']) ?? 'code_organ',
                  label_zh: String(o.label_zh ?? `${oIdx + 1}. 靶机器官`),
                  label_en: String(o.label_en ?? o.name ?? 'ORGAN'),
                  service: String(o.service ?? o.component ?? 'Linux Service'),
                  state: mappedState,
                  compromised_by: o.compromised_by
                    ? String(o.compromised_by)
                    : o.breached_by_seat_id
                      ? seats.find((s) => s.id === String(o.breached_by_seat_id))?.name ??
                        String(o.breached_by_seat_id)
                      : undefined,
                  patched_by: o.patched_by
                    ? String(o.patched_by)
                    : o.patched_by_seat_id
                      ? seats.find((s) => s.id === String(o.patched_by_seat_id))?.name ??
                        String(o.patched_by_seat_id)
                      : undefined,
                  hit_location: o.hit_location ? String(o.hit_location) : undefined,
                };
              })
            : [];

        const organTree = rawOrgans.find((o) => Array.isArray(o.process_tree) && o.process_tree.length)
          ?.process_tree as string[] | undefined;

        if (t.last_diff) {
          const diffStr = String(t.last_diff);
          const patchMatch = /# PATCHED_BY:([A-Za-z0-9_-]+)/.exec(diffStr);
          const patchSeatId = patchMatch?.[1] ?? String(t.owner_seat_id ?? kingSeatId ?? seats[0]?.id ?? 'seat-1');
          const matchedSeat = seats.find((s) => s.id === patchSeatId);
          extractedPatches.push({
            id: `patch-target-${idx}`,
            ts_ms: Date.now(),
            seat_id: patchSeatId,
            seat_name: matchedSeat?.name ?? patchSeatId,
            target_id: String(t.id ?? `target-${idx + 1}`),
            file_path: 'app/server.py',
            commit_sha: 'live-fix',
            verified: true,
            diff: diffStr,
          });
        }

        const wsState = t.web_state as Record<string, unknown> | undefined;
        if (wsState && (wsState.last_injected_input || wsState.deface_banner)) {
          extractedWebHijacks.push({
            id: `wh-target-${idx}`,
            ts_ms: Date.now(),
            target_id: String(t.id ?? `target-${idx + 1}`),
            attacker_seat_id: String(wsState.hijacked_by_seat_id ?? ''),
            attacker_name: String(wsState.hijacked_by_name ?? ''),
            attacker_color: String(wsState.hijacked_by_color ?? '#FF3B30'),
            cursor_x: Number(wsState.cursor_x ?? 0.5),
            cursor_y: Number(wsState.cursor_y ?? 0.5),
            target_url: String(wsState.target_url ?? ''),
            injected_input: String(wsState.last_injected_input ?? ''),
            dom_mutation: String(wsState.dom_mutation ?? ''),
            deface_banner: wsState.deface_banner ? String(wsState.deface_banner) : undefined,
          });
        }

        const portNum = Number(t.container_port ?? t.host_port ?? 8080);
        const rawExcerpt = Array.isArray(t.code_excerpt)
          ? (t.code_excerpt as Array<Record<string, unknown>>)
          : [];
        const codeSnippet = rawExcerpt.map((row) => {
          const tag = String(row.tag ?? 'normal');
          return {
            line: Number(row.line ?? 0),
            code: String(row.code ?? ''),
            is_vuln: tag === 'vulnerable',
            is_patched: tag === 'patched',
          };
        });
        const firstFocusLine =
          codeSnippet.find((r) => r.is_vuln || r.is_patched)?.line ?? codeSnippet[0]?.line ?? 0;

        return {
          id: String(t.id ?? `target-${idx + 1}`),
          name: String(t.name ?? ''),
          owner_seat_id: t.owner_seat_id ? String(t.owner_seat_id) : null,
          ip: String(t.ip ?? t.container_ip ?? t.address ?? ''),
          ports: Array.isArray(t.ports) ? (t.ports as number[]) : [portNum],
          grail_holder_seat_id: t.grail_holder_seat_id
            ? String(t.grail_holder_seat_id)
            : t.king_seat_id
              ? String(t.king_seat_id)
              : kingSeatId,
          sla_healthy: Boolean(
            t.sla_healthy ?? (t.healthy !== undefined ? t.healthy && !t.flatlined : true)
          ),
          sla_score: Number(t.sla_score ?? 100),
          organs,
          vulnerable_file: String(t.code_file ?? t.vulnerable_file ?? ''),
          vulnerable_line: Number(t.vulnerable_line ?? firstFocusLine),
          last_diff: t.last_diff ? String(t.last_diff) : undefined,
          code_snippet: codeSnippet,
          is_patched: Boolean(t.is_patched ?? Number(t.patch_count ?? 0) > 0),
          active_process_tree: Array.isArray(t.active_process_tree)
            ? (t.active_process_tree as string[])
            : organTree ?? [],
        };
      })
    : [];

  // Unpack `events` whether raw EBPFEvent[] or pitd EventEnvelope[]
  const rawEvents = Array.isArray(raw.events) ? (raw.events as Array<Record<string, unknown>>) : [];
  const ebpfEvents: EbpfEvent[] = [];
  const terminals: MatchState['terminals'] = {};

  rawEvents.forEach((entry) => {
    if (entry.kind && entry.payload && typeof entry.payload === 'object') {
      const k = String(entry.kind);
      const p = entry.payload as Record<string, unknown>;
      const ts = Number(entry.ts_ms ?? Date.now());
      if (k === 'EBPF_EVENT') {
        ebpfEvents.unshift(normalizeEbpfPayload(p, ts));
      } else if (k === 'PATCH_APPLIED') {
        extractedPatches.unshift({
          id: `patch-${ts}-${Math.random().toString(36).slice(2, 5)}`,
          ts_ms: ts,
          seat_id: String(p.seat_id ?? ''),
          seat_name: String(p.seat_name ?? 'Defender'),
          target_id: String(p.target_id ?? ''),
          file_path: String(p.file_path ?? 'app.py'),
          commit_sha: String(p.commit_sha ?? 'hotfix'),
          verified: Boolean(p.verified ?? true),
          diff: String(p.diff ?? ''),
        });
      } else if (k === 'WEB_HIJACK') {
        extractedWebHijacks.unshift({
          id: `wh-${ts}`,
          ts_ms: ts,
          target_id: String(p.target_id ?? ''),
          attacker_seat_id: String(p.attacker_seat_id ?? ''),
          attacker_name: String(p.attacker_name ?? ''),
          attacker_color: String(p.attacker_color ?? '#FF3B30'),
          cursor_x: Number(p.cursor_x ?? 0.5),
          cursor_y: Number(p.cursor_y ?? 0.5),
          target_url: String(p.target_url ?? ''),
          injected_input: String(p.injected_input ?? ''),
          dom_mutation: String(p.dom_mutation ?? ''),
          deface_banner: p.deface_banner ? String(p.deface_banner) : undefined,
        });
      } else if (k === 'TERMINAL_OUTPUT') {
        const sid = String(p.seat_id ?? 'seat-1');
        const prevList = terminals[sid] ?? [];
        const txt = p.command ? `$ ${p.command}\n${p.output ?? ''}` : String(p.output ?? p.data ?? '');
        terminals[sid] = [
          ...prevList.slice(-50),
          {
            id: `tm-${ts}-${Math.random().toString(36).slice(2, 5)}`,
            ts_ms: ts,
            seat_id: sid,
            kind: p.stream === 'stderr' ? 'stderr' : 'stdout',
            text: txt,
          },
        ];
      }
    } else if (entry.vfx_type) {
      ebpfEvents.push(normalizeEbpfPayload(entry, Number(entry.ts_ms ?? Date.now())));
    }
  });

  const rawKf = Array.isArray(raw.kill_feed) ? (raw.kill_feed as Array<Record<string, unknown>>) : [];
  const killFeed = rawKf
    .slice()
    .reverse()
    .map((k) => normalizeKillFeedItem(k, Date.now()));

  const rawCaster = Array.isArray(raw.caster_lines)
    ? (raw.caster_lines as Array<Record<string, unknown>>)
    : [];
  const casterLines: CasterLine[] = rawCaster
    .slice()
    .reverse()
    .map((c, idx) => ({
      id: String(c.id ?? `cl-${idx}`),
      ts_ms: Number(c.ts_ms ?? Date.now()),
      mood: mapToneToMood(c.mood ?? c.tone),
      text: String(c.text ?? ''),
    }));

  return {
    id: String(raw.id ?? raw.match_id ?? 'match-live'),
    title: String(raw.title ?? fallbackReq?.title ?? 'THE PIT LIVE CLASH'),
    mode: (raw.mode as MatchState['mode']) ?? fallbackReq?.mode ?? 'grail',
    map_id: String(raw.map_id ?? fallbackReq?.map_id ?? 'llm-redteam'),
    map_name: String(raw.map_name ?? raw.map_id ?? 'Aegis AI Vault'),
    status: (raw.status as MatchState['status']) ?? 'running',
    round: Number(raw.round ?? 1),
    max_rounds: Number(raw.max_rounds ?? 10),
    round_seconds: Number(raw.round_seconds ?? 60),
    round_remaining_sec: Number(raw.round_remaining_sec ?? 60),
    elapsed_sec: Number(raw.elapsed_sec ?? 0),
    token_budget: budget,
    first_blood_seat_id: raw.first_blood_seat_id ? String(raw.first_blood_seat_id) : null,
    first_blood_sec: raw.first_blood_sec ? Number(raw.first_blood_sec) : null,
    seats,
    targets,
    events: ebpfEvents.slice(0, 80),
    patches: extractedPatches.slice(0, 15),
    web_hijacks: extractedWebHijacks.slice(0, 12),
    kill_feed: killFeed.slice(0, 8),
    caster_lines: casterLines.slice(0, 20),
    camera_cue: (raw.camera_cue as MatchState['camera_cue']) ?? {
      lens: 'MACRO_ARENA',
      focus_target_id: targets[0]?.id ?? 'target-grail',
      focus_seat_id: seats[0]?.id ?? 'seat-1',
      reason: 'pitd 实时内核遥测流已接通',
      hold_ms: 4000,
      ts_ms: Date.now(),
    },
    terminals,
    driver_label: 'pitd LIVE · KERNEL eBPF STREAM',
  };
}

export function applyWsEnvelope(
  prev: MatchState,
  msg: Record<string, unknown>
): { next: MatchState; ebpfEvent?: EbpfEvent } {
  const kind = String(msg.kind ?? '');
  const payload = (msg.payload as Record<string, unknown>) ?? {};
  const ts = Number(msg.ts_ms ?? Date.now());

  if (kind === 'MATCH_STATE') {
    return { next: normalizeServerMatchState(payload) };
  }

  const next: MatchState = {
    ...prev,
    seats: prev.seats.map((s) => ({ ...s })),
    targets: prev.targets.map((t) => ({ ...t, organs: t.organs.map((o) => ({ ...o })) })),
  };

  if (kind === 'EBPF_EVENT') {
    const evt = normalizeEbpfPayload(payload, ts);
    next.events = [evt, ...next.events.slice(0, 79)];
    const t = next.targets.find((tg) => tg.id === evt.target_id) ?? next.targets[0];
    if (t) {
      if (evt.process_tree?.length) t.active_process_tree = evt.process_tree;
      const org = t.organs.find((o) => o.layer === evt.organ_layer);
      if (org) {
        org.state = evt.vfx_type === 'NANO_PATCH_WELD' ? 'patched' : 'compromised';
      }
    }
    soundEngine.playVfx(evt.vfx_type);
    return { next, ebpfEvent: evt };
  }

  if (kind === 'THOUGHT_BUBBLE') {
    const seat = next.seats.find((s) => s.id === String(payload.seat_id ?? ''));
    if (seat) seat.thought = String(payload.thought ?? payload.text ?? seat.thought);
  } else if (kind === 'TOKEN_BURN') {
    const seat = next.seats.find((s) => s.id === String(payload.seat_id ?? ''));
    if (seat) {
      seat.tokens_used = Number(payload.tokens_used ?? seat.tokens_used);
      seat.mana_remaining_pct = Number(
        Number(payload.mana_remaining_pct ?? seat.mana_remaining_pct).toFixed(1)
      );
      seat.burn_rate_tps = Number(payload.delta_tokens ?? payload.burn_rate_tps ?? seat.burn_rate_tps);
    }
  } else if (kind === 'MANA_DEPLETED') {
    const seat = next.seats.find((s) => s.id === String(payload.seat_id ?? ''));
    if (seat) {
      seat.out_of_mana = true;
      seat.mana_remaining_pct = 0;
      seat.thought = '💀 HTTP 402 OUT OF MANA — Token 蓝条耗尽当场哑火！';
    }
  } else if (kind === 'FLAG_CAPTURED') {
    const seat = next.seats.find((s) => s.id === String(payload.seat_id ?? ''));
    if (seat) {
      seat.score += Number(payload.points_earned ?? 300);
      seat.flags_captured += 1;
      if (payload.first_blood) {
        seat.first_bloods += 1;
        next.first_blood_seat_id = seat.id;
        soundEngine.playFirstBloodSubBass();
      }
    }
  } else if (kind === 'GRAIL_CLAIMED') {
    const kingId = String(payload.king_seat_id ?? '');
    next.seats.forEach((s) => {
      s.is_grail_king = s.id === kingId;
      if (s.id === kingId) s.score += Number(payload.points_delta ?? 0);
    });
    if (next.targets[0]) next.targets[0].grail_holder_seat_id = kingId;
  } else if (kind === 'SLA_HEARTBEAT') {
    const owner = next.seats.find((s) => s.id === String(payload.owner_seat_id ?? ''));
    const healthy = Boolean(payload.healthy ?? !payload.flatlined);
    if (owner) {
      owner.sla_healthy = healthy;
      owner.sla_score = Number(payload.sla_score ?? 100);
      owner.sla_latency_ms = Number(payload.latency_ms ?? 35);
      owner.sla_detail = String(payload.detail ?? '');
      if (Array.isArray(payload.ecg_samples)) {
        owner.ecg_samples = payload.ecg_samples as number[];
      }
      if (!healthy) soundEngine.playFlatlineAlarm();
    }
  } else if (kind === 'PATCH_APPLIED') {
    const seat = next.seats.find((s) => s.id === String(payload.seat_id ?? ''));
    if (seat) {
      seat.patches_verified += 1;
      seat.score += Number(payload.points_delta ?? 0);
      seat.sla_healthy = true;
    }
    const target = next.targets.find((t) => t.id === String(payload.target_id ?? '')) ?? next.targets[0];
    if (target) {
      target.is_patched = true;
      target.sla_healthy = true;
    }
    next.patches = [
      {
        id: `p-${ts}`,
        ts_ms: ts,
        seat_id: String(payload.seat_id ?? ''),
        seat_name: String(payload.seat_name ?? seat?.name ?? 'Defender'),
        target_id: String(payload.target_id ?? ''),
        file_path: String(payload.file_path ?? 'app.py'),
        commit_sha: String(payload.commit_sha ?? 'hotfix'),
        verified: Boolean(payload.verified ?? true),
        diff: String(payload.diff ?? ''),
      },
      ...next.patches.slice(0, 14),
    ];
    soundEngine.playWeldSpark();
  } else if (kind === 'WEB_HIJACK') {
    next.web_hijacks = [
      {
        id: `wh-${ts}`,
        ts_ms: ts,
        target_id: String(payload.target_id ?? ''),
        attacker_seat_id: String(payload.attacker_seat_id ?? ''),
        attacker_name: String(payload.attacker_name ?? ''),
        attacker_color: String(payload.attacker_color ?? '#FF3B30'),
        cursor_x: Number(payload.cursor_x ?? 0.5),
        cursor_y: Number(payload.cursor_y ?? 0.5),
        target_url: String(payload.target_url ?? ''),
        injected_input: String(payload.injected_input ?? ''),
        dom_mutation: String(payload.dom_mutation ?? ''),
        deface_banner: payload.deface_banner ? String(payload.deface_banner) : undefined,
      },
      ...next.web_hijacks.slice(0, 11),
    ];
  } else if (kind === 'KILL_FEED') {
    next.kill_feed = [normalizeKillFeedItem(payload, ts), ...next.kill_feed.slice(0, 7)];
  } else if (kind === 'CASTER_LINE') {
    next.caster_lines = [
      {
        id: `cl-${ts}`,
        ts_ms: ts,
        mood: mapToneToMood(payload.mood ?? payload.tone),
        text: String(payload.text ?? ''),
      },
      ...next.caster_lines.slice(0, 19),
    ];
  } else if (kind === 'CAMERA_CUE') {
    next.camera_cue = {
      lens: (payload.lens as MatchState['camera_cue']['lens']) ?? 'MACRO_ARENA',
      focus_target_id: String(payload.focus_target_id ?? next.targets[0]?.id ?? ''),
      focus_seat_id: String(payload.focus_seat_id ?? next.seats[0]?.id ?? ''),
      reason: String(payload.reason ?? ''),
      hold_ms: Number(payload.hold_ms ?? 4500),
      ts_ms: ts,
    };
  } else if (kind === 'TERMINAL_OUTPUT') {
    const sid = String(payload.seat_id ?? next.seats[0]?.id ?? 'seat-1');
    const list = next.terminals[sid] ?? [];
    const txt = payload.command
      ? `$ ${payload.command}\n${payload.output ?? ''}`
      : String(payload.output ?? payload.data ?? payload.text ?? '');
    next.terminals = {
      ...next.terminals,
      [sid]: [
        ...list.slice(-55),
        {
          id: `tm-${ts}-${Math.random().toString(36).slice(2, 5)}`,
          ts_ms: ts,
          seat_id: sid,
          kind: payload.stream === 'stderr' ? 'stderr' : 'stdout',
          text: txt,
        },
      ],
    };
  }

  return { next };
}
