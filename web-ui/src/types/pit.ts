// Canonical Aexus Colosseum (The Pit) Phase 1 Types — aligned with pit-spec/SCHEMA.md

export type GameMode = 'awd' | 'grail' | 'speedrun' | 'last_stand';

export type SeatKind = 'harness' | 'human' | 'centaur';

export type OrganLayer =
  | 'port_gate'
  | 'route_vessel'
  | 'code_organ'
  | 'db_vault'
  | 'flag_heart';

export type VFXType =
  | 'SONAR_SWEEP'
  | 'ARMOR_PIERCING_BARRAGE'
  | 'PRECISION_EXPLOIT_BEAM'
  | 'RCE_PARASITE_BREACH'
  | 'REVERSE_SHELL_CHAIN'
  | 'GRAIL_HEART_STOLEN'
  | 'NANO_PATCH_WELD'
  | 'ROOT_SHOCKWAVE'
  | 'SSL_CLEARTEXT_INTERCEPT';

export type CameraLens = 'MACRO_ARENA' | 'XRAY_ORGAN' | 'LIVE_WEB_HIJACK';

export type MapCategory =
  | 'ai'
  | 'web'
  | 'cve'
  | 'network'
  | 'redteam'
  | 'cloud'
  | 'binary'
  | 'forensics'
  | 'misc';

export interface EbpfPerfStats {
  cpu_cores: number;
  ringbuf_capacity_bytes: number;
  syscalls_entered: number;
  filtered_in_kernel: number;
  ringbuf_submitted: number;
  ringbuf_drops: number;
  execve_submitted: number;
  connect_submitted: number;
  openat_submitted: number;
  security_submitted: number;
  kernel_filter_pct: number;
  syscalls_per_sec: number;
  events_per_sec: number;
}

export interface HealthResponse {
  status: string;
  version?: string;
  ebpf: {
    mode: 'kernel_ebpf' | 'active_bridge' | 'replay_sim' | 'offline' | string;
    btf_enabled: boolean;
    kernel_release?: string;
    ssl_libraries_hooked?: number;
    tracked_containers?: number;
    attached_probes: string[];
    events_captured: number;
    perf_stats?: EbpfPerfStats;
  };
  docker?: {
    available: boolean;
    version?: string;
    containers_running?: number;
  };
  active_matches?: number;
}

export interface ArmoryMap {
  id: string;
  name: string;
  subtitle?: string;
  category: MapCategory;
  difficulty: number; // 1 - 5
  summary: string;
  tags: string[];
  mitre?: string[];
  ports: number[];
  ram_mb?: number;
  supports_awd_patch: boolean;
  organs?: {
    layer: OrganLayer;
    service: string;
    vuln_hint?: string;
    source_file?: string;
  }[];
  source?: 'curated' | 'vulhub' | 'pit-featured';
}

export interface HarnessSpec {
  id: string;
  name: string;
  developer: string;
  stars: string;
  stars_num: number;
  language: string;
  tagline: string;
  accent_color: string;
  capabilities: {
    recon: number;
    exploit: number;
    patch: number;
    efficiency: number;
  };
  tags: string[];
  adapter_cmd: string;
}

export interface SeatConfigInput {
  id: string;
  name: string;
  kind: SeatKind;
  harness_id: string;
  model: string;
  team_color: string;
}

export interface SeatState {
  id: string;
  name: string;
  kind: SeatKind;
  harness_id: string;
  model: string;
  team_color: string;
  score: number;
  is_grail_king: boolean;
  first_bloods: number;
  flags_captured: number;
  patches_verified: number;
  tokens_used: number;
  token_budget: number;
  mana_remaining_pct: number;
  out_of_mana: boolean;
  burn_rate_tps: number;
  sla_healthy: boolean;
  sla_score: number;
  sla_latency_ms: number;
  sla_detail: string;
  ecg_samples: number[];
  thought: string;
  possessed: boolean;
  role?: 'attacker' | 'defender' | 'hybrid';
  ip?: string;
}

export interface OrganStatus {
  layer: OrganLayer;
  label_zh: string;
  label_en: string;
  service: string;
  state: 'intact' | 'probing' | 'compromised' | 'patched';
  compromised_by?: string;
  patched_by?: string;
  hit_location?: string;
  last_probe?: string;
}

export interface TargetFortress {
  id: string;
  name: string;
  owner_seat_id?: string | null;
  ip: string;
  ports: number[];
  grail_holder_seat_id?: string | null;
  sla_healthy: boolean;
  sla_score: number;
  organs: OrganStatus[];
  vulnerable_file: string;
  vulnerable_line: number;
  last_diff?: string;
  code_snippet: {
    line: number;
    code: string;
    patched_code?: string;
    is_vuln?: boolean;
    is_patched?: boolean;
  }[];
  is_patched: boolean;
  active_process_tree: string[];
}

export interface EbpfEvent {
  id: string;
  ts_ms: number;
  probe: string;
  vfx_type: VFXType;
  source_seat_id: string;
  target_id: string;
  organ_layer: OrganLayer;
  cgroup_id: number;
  pid: number;
  ppid: number;
  uid: number;
  comm: string;
  parent_comm: string;
  cmdline: string;
  src_ip: string;
  dst_ip: string;
  dst_port: number;
  cleartext_payload?: string;
  process_tree?: string[];
  hit_location?: string;
  kernel_ts_ns?: number;
  kernel_latency_ns?: number;
}

export interface PatchEvent {
  id: string;
  ts_ms: number;
  seat_id: string;
  seat_name: string;
  target_id: string;
  file_path: string;
  commit_sha: string;
  verified: boolean;
  diff: string;
}

export interface WebHijackEvent {
  id: string;
  ts_ms: number;
  target_id: string;
  attacker_seat_id: string;
  attacker_name: string;
  attacker_color: string;
  cursor_x: number;
  cursor_y: number;
  target_url: string;
  injected_input: string;
  dom_mutation: string;
  deface_banner?: string;
}

export interface KillFeedItem {
  id: string;
  ts_ms: number;
  probe_tag: string;
  actor_seat_id: string;
  actor_name: string;
  actor_color: string;
  victim_name: string;
  action_label: string;
  is_first_blood?: boolean;
  is_patch?: boolean;
  is_mana_dry?: boolean;
  is_grail?: boolean;
  points_delta?: number;
}

export interface CasterLine {
  id: string;
  ts_ms: number;
  mood: 'HYPE' | 'CRITICAL' | 'CLUTCH' | 'ROAST' | 'SYSTEM';
  text: string;
}

export interface CameraCue {
  lens: CameraLens;
  focus_target_id: string;
  focus_seat_id: string;
  reason: string;
  hold_ms: number;
  ts_ms: number;
}

export interface TerminalEntry {
  id: string;
  ts_ms: number;
  seat_id: string;
  kind: 'cmd' | 'stdout' | 'stderr' | 'hint' | 'system';
  text: string;
}

export interface MatchState {
  id: string;
  title: string;
  mode: GameMode;
  map_id: string;
  map_name: string;
  status: 'staging' | 'running' | 'paused' | 'finished' | 'completed';
  round: number;
  max_rounds: number;
  round_seconds: number;
  round_remaining_sec: number;
  elapsed_sec: number;
  token_budget: number;
  first_blood_seat_id?: string | null;
  first_blood_sec?: number | null;
  seats: SeatState[];
  targets: TargetFortress[];
  events: EbpfEvent[];
  patches: PatchEvent[];
  web_hijacks: WebHijackEvent[];
  kill_feed: KillFeedItem[];
  caster_lines: CasterLine[];
  camera_cue: CameraCue;
  terminals: Record<string, TerminalEntry[]>;
  driver_label: string;
}

export interface CreateMatchRequest {
  title: string;
  mode: GameMode;
  map_id: string;
  token_budget: number;
  round_seconds: number;
  max_rounds: number;
  auto_start: boolean;
  execution_driver: 'auto' | 'docker';
  upstream_llm: {
    base_url: string;
    api_key: string;
    default_model: string;
  };
  seats: SeatConfigInput[];
}

export interface LeaderboardEntry {
  rank: number;
  id: string;
  combatant_name: string;
  kind: SeatKind;
  harness_id: string;
  base_model: string;
  accent_color: string;
  matches_played: number;
  win_rate: number;
  total_score: number;
  first_bloods: number;
  patches_verified: number;
  avg_tokens_per_solve: number;
  efficiency_king?: boolean;
}

export interface SavedReplaySummary {
  id: string;
  title: string;
  mode: GameMode;
  map_id: string;
  map_name: string;
  winner_name: string;
  winner_color: string;
  winner_model: string;
  duration_sec: number;
  total_ebpf_events: number;
  first_blood_sec: number;
  avg_mana_left_pct: number;
  recorded_at: string;
  snapshot?: MatchState;
}
