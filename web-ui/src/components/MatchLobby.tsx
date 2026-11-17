import React, { useEffect, useMemo, useState } from 'react';
import {
  Activity,
  ChevronDown,
  ChevronUp,
  Crown,
  Cpu,
  Flame,
  KeyRound,
  Lock,
  Play,
  Plus,
  Search,
  Shield,
  Swords,
  Trophy,
  X,
  Zap,
} from 'lucide-react';
import {
  ARMORY_MAPS,
  BASE_MODELS,
  FACTION_COLORS,
  GAME_MODE_SPECS,
  LEGENDARY_HARNESSES,
  QUICK_PRESETS,
  formatTokenCompact,
} from '../data/armoryCatalog';
import {
  ArmoryMap,
  CreateMatchRequest,
  GameMode,
  HarnessSpec,
  SeatConfigInput,
  SeatKind,
} from '../types/pit';
import { AppleOpenPill, AppleSquircleIcon } from './PitEmblem';

interface MatchLobbyProps {
  maps: ArmoryMap[];
  harnesses: HarnessSpec[];
  initialMapId?: string | null;
  initialHarnessId?: string | null;
  onLaunchMatch: (req: CreateMatchRequest) => void;
  onBrowseArmory: () => void;
  onOpenLeaderboard: () => void;
  onBackToLiveHud: () => void;
}

const MANA_STEPS = [
  { value: 25_000, label: '25K · DeepSeek 验证局' },
  { value: 50_000, label: '50K · 实网短局' },
  { value: 250_000, label: '250K · 闪电刺刀局' },
  { value: 500_000, label: '500K · 紧凑高压局' },
  { value: 1_000_000, label: '1.0M · 标准锦标赛' },
  { value: 2_000_000, label: '2.0M · 深度内网局' },
  { value: 5_000_000, label: '5.0M · 长线持久战' },
];

const MODE_VISUALS: Record<
  GameMode,
  { colors: [string, string]; badge: string; icon: React.ReactNode }
> = {
  awd: {
    colors: ['#EE4438', '#C9252D'],
    badge: '源码挂载 · 双向攻防',
    icon: <Shield className="w-6 h-6" />,
  },
  grail: {
    colors: ['#E89A1E', '#C4710C'],
    badge: '中央王座 · 独占计分',
    icon: <Crown className="w-6 h-6" />,
  },
  speedrun: {
    colors: ['#2684FF', '#005AE0'],
    badge: '隔离副本 · 省流决胜',
    icon: <Zap className="w-6 h-6" />,
  },
  last_stand: {
    colors: ['#28A766', '#157A46'],
    badge: '1 VS N · 波次生存',
    icon: <Swords className="w-6 h-6" />,
  },
};

export const MatchLobby: React.FC<MatchLobbyProps> = ({
  maps,
  harnesses,
  initialMapId,
  initialHarnessId,
  onLaunchMatch,
  onBrowseArmory,
  onOpenLeaderboard,
}) => {
  const defaultPreset = QUICK_PRESETS[0].config;
  const [activePresetId, setActivePresetId] = useState<string>(QUICK_PRESETS[0].id);
  const [title, setTitle] = useState(defaultPreset.title);
  const [mode, setMode] = useState<GameMode>(defaultPreset.mode);
  const [mapId, setMapId] = useState<string>(initialMapId || defaultPreset.map_id);
  const [tokenBudget, setTokenBudget] = useState<number>(defaultPreset.token_budget);
  const [roundSeconds, setRoundSeconds] = useState<number>(60);
  const [maxRounds, setMaxRounds] = useState<number>(10);
  const [seats, setSeats] = useState<SeatConfigInput[]>(defaultPreset.seats);

  const [mapSearch, setMapSearch] = useState('');
  const [llmDrawerOpen, setLlmDrawerOpen] = useState(false);
  const [upstreamUrl, setUpstreamUrl] = useState('');
  const [upstreamKey, setUpstreamKey] = useState('');
  const [driver, setDriver] = useState<'auto' | 'docker'>('auto');

  const catalogMaps = maps.length ? maps : ARMORY_MAPS;
  const catalogHarnesses = harnesses.length ? harnesses : LEGENDARY_HARNESSES;
  const selectedMap = catalogMaps.find((m) => m.id === mapId) ?? catalogMaps[0];

  useEffect(() => {
    if (initialMapId) setMapId(initialMapId);
  }, [initialMapId]);

  useEffect(() => {
    if (!initialHarnessId) return;
    const found = catalogHarnesses.find((h) => h.id === initialHarnessId);
    if (!found) return;
    setSeats((prev) => {
      if (prev.some((s) => s.harness_id === found.id)) return prev;
      if (prev.length < 6) {
        return [
          ...prev,
          {
            id: `seat-${prev.length + 1}`,
            name: found.name,
            kind: 'harness',
            harness_id: found.id,
            model: BASE_MODELS[0],
            team_color: found.accent_color,
          },
        ];
      }
      const next = [...prev];
      next[next.length - 1] = {
        ...next[next.length - 1],
        name: found.name,
        kind: 'harness',
        harness_id: found.id,
        team_color: found.accent_color,
      };
      return next;
    });
  }, [initialHarnessId, catalogHarnesses]);

  const filteredMaps = useMemo(() => {
    const q = mapSearch.trim().toLowerCase();
    if (!q) return catalogMaps.slice(0, 10);
    return catalogMaps
      .filter(
        (m) =>
          m.name.toLowerCase().includes(q) ||
          m.id.toLowerCase().includes(q) ||
          m.tags.some((t) => t.toLowerCase().includes(q))
      )
      .slice(0, 12);
  }, [catalogMaps, mapSearch]);

  const applyPreset = (presetId: string) => {
    const found = QUICK_PRESETS.find((p) => p.id === presetId);
    if (!found) return;
    setActivePresetId(found.id);
    setTitle(found.config.title);
    setMode(found.config.mode);
    setMapId(found.config.map_id);
    setTokenBudget(found.config.token_budget);
    setRoundSeconds(found.config.round_seconds);
    setMaxRounds(found.config.max_rounds);
    setSeats(found.config.seats);
  };

  const addSeat = () => {
    setSeats((prev) => {
      if (prev.length >= 6) return prev;
      const idx = prev.length;
      const h = catalogHarnesses[idx % catalogHarnesses.length];
      return [
        ...prev,
        {
          id: `seat-${idx + 1}`,
          name: h.name,
          kind: 'harness',
          harness_id: h.id,
          model: BASE_MODELS[idx % BASE_MODELS.length],
          team_color: FACTION_COLORS[idx % FACTION_COLORS.length],
        },
      ];
    });
  };

  const removeSeat = (index: number) => {
    setSeats((prev) => {
      if (prev.length <= 2) return prev;
      return prev.filter((_, i) => i !== index);
    });
  };

  const updateSeat = (index: number, patch: Partial<SeatConfigInput>) => {
    setSeats((prev) =>
      prev.map((s, i) => {
        if (i !== index) return s;
        const next = { ...s, ...patch };
        if (patch.harness_id && !patch.name) {
          const found = catalogHarnesses.find((h) => h.id === patch.harness_id);
          if (found && s.kind !== 'human') {
            next.name = found.name;
            next.team_color = found.accent_color;
          }
        }
        if (patch.kind === 'human' && s.kind !== 'human') {
          next.name = `人类白帽 #${index + 1}`;
        }
        return next;
      })
    );
  };

  const handleUnleash = () => {
    onLaunchMatch({
      title: title.trim() || '全球开源 AI 攻防实网对决',
      mode,
      map_id: selectedMap.id,
      token_budget: tokenBudget,
      round_seconds: roundSeconds,
      max_rounds: maxRounds,
      auto_start: true,
      execution_driver: driver,
      upstream_llm: {
        base_url: upstreamUrl.trim(),
        api_key: upstreamKey.trim(),
        default_model: seats[0]?.model ?? 'claude-sonnet-4-6',
      },
      seats: seats.map((s, i) => ({ ...s, id: `seat-${i + 1}` })),
    });
  };

  return (
    <div className="flex-1 overflow-y-auto px-7 py-7">
      <div className="max-w-[1340px] mx-auto space-y-7 pb-10">
        {/* Storefront Page Header */}
        <div className="flex flex-col lg:flex-row lg:items-end justify-between gap-4">
          <div>
            <div className="text-[10.5px] font-bold tracking-[0.14em] text-[#6F7078] uppercase">
              AEXUS COLOSSEUM · AI × 人类实网攻防竞技场
            </div>
            <h2 className="text-[32px] font-bold tracking-tight text-[#1A1A1E] mt-1 leading-tight">
              开始一场攻防对决
            </h2>
            <p className="text-[13.5px] text-[#61626A] mt-1.5 max-w-3xl">
              将顶尖开源渗透智能体（Strix、Shannon、PentAGI 等）与人类白帽投入真实漏洞靶机，在统一
              Token 额度下自动展开入侵与代码热修复。
            </p>
          </div>

          <div className="flex items-center gap-2.5 shrink-0">
            <button
              type="button"
              onClick={onOpenLeaderboard}
              className="h-9 px-4 rounded-full bg-white hover:bg-[#F7F8FA] border border-black/[0.08] shadow-[0_2px_6px_rgba(0,0,0,0.04)] text-[12.5px] font-semibold text-[#1A1A1E] flex items-center gap-1.5 transition-all"
            >
              <Trophy className="w-3.5 h-3.5 text-[#61626A]" />
              <span>查看天梯榜</span>
            </button>

            <button
              type="button"
              onClick={() => onLaunchMatch(QUICK_PRESETS[0].config)}
              className="h-9 px-4.5 rounded-full bg-[#007AFF] hover:bg-[#0066D6] shadow-[0_4px_12px_rgba(0,122,255,0.28)] text-[12.5px] font-semibold text-white flex items-center gap-1.5 transition-all px-4"
            >
              <Play className="w-3.5 h-3.5 fill-white" />
              <span>极速实网开局</span>
            </button>
          </div>
        </div>

        {/* Guided 3-Step Onboarding Strip (一眼看懂怎么用) */}
        <div className="apple-card p-4 grid grid-cols-1 md:grid-cols-3 gap-4 divide-y md:divide-y-0 md:divide-x divide-black/[0.06]">
          <div className="flex items-center gap-3.5 px-2">
            <div className="w-10 h-10 rounded-xl bg-[#007AFF]/10 text-[#007AFF] flex items-center justify-center shrink-0">
              <Swords className="w-4 h-4" />
            </div>
            <div className="min-w-0">
              <div className="text-[12px] font-bold text-[#1A1A1E]">
                <span className="text-[#007AFF] mr-1.5 font-mono text-[10.5px]">STEP 01</span>
                选定竞技规则
              </div>
              <div className="text-[11.5px] text-[#61626A] truncate mt-0.5">
                支持攻防混战、圣杯战争、竞速夺旗与人类防线
              </div>
            </div>
          </div>

          <div className="flex items-center gap-3.5 px-2 md:pl-5 pt-3 md:pt-0">
            <div className="w-10 h-10 rounded-xl bg-[#5856D6]/10 text-[#5856D6] flex items-center justify-center shrink-0">
              <Cpu className="w-4 h-4" />
            </div>
            <div className="min-w-0">
              <div className="text-[12px] font-bold text-[#1A1A1E]">
                <span className="text-[#5856D6] mr-1.5 font-mono text-[10.5px]">STEP 02</span>
                混编 AI 与真人席位
              </div>
              <div className="text-[11.5px] text-[#61626A] truncate mt-0.5">
                零改造投放 Strix / Shannon / Claude Code 或真人白帽
              </div>
            </div>
          </div>

          <div className="flex items-center gap-3.5 px-2 md:pl-5 pt-3 md:pt-0">
            <div className="w-10 h-10 rounded-xl bg-[#1C9457]/10 text-[#1C9457] flex items-center justify-center shrink-0">
              <Activity className="w-4 h-4" />
            </div>
            <div className="min-w-0">
              <div className="text-[12px] font-bold text-[#1A1A1E]">
                <span className="text-[#1C9457] mr-1.5 font-mono text-[10.5px]">STEP 03</span>
                宿主机 eBPF 实时透视
              </div>
              <div className="text-[11.5px] text-[#61626A] truncate mt-0.5">
                每条底层命令实时映射为攻防态势、进程链与源码补丁
              </div>
            </div>
          </div>
        </div>

        {/* STEP 1: Choose Game Mode */}
        <section className="space-y-3.5">
          <div className="flex items-center gap-3">
            <span className="w-6 h-6 rounded-full bg-[#007AFF]/10 border border-[#007AFF]/20 text-[#007AFF] text-[11px] font-bold flex items-center justify-center">
              1
            </span>
            <div>
              <h3 className="text-[17.5px] font-bold text-[#1A1A1E] leading-snug">选择对战模式</h3>
              <p className="text-[12.5px] text-[#61626A]">
                四种核心规则覆盖双向源码攻防、中央靶机争夺、百题竞速与人机防守战
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
            {GAME_MODE_SPECS.map((gm) => {
              const active = mode === gm.id;
              const vis = MODE_VISUALS[gm.id];
              return (
                <div
                  key={gm.id}
                  role="button"
                  tabIndex={0}
                  onClick={() => setMode(gm.id)}
                  className={`apple-card-interactive p-5 flex flex-col justify-between ${
                    active ? 'apple-card-selected ring-1 ring-[#007AFF]/45' : ''
                  }`}
                >
                  <div>
                    <div className="flex items-start justify-between gap-3">
                      <AppleSquircleIcon colors={vis.colors} size={56}>
                        {vis.icon}
                      </AppleSquircleIcon>
                      <AppleOpenPill
                        label={active ? '已选' : '选择'}
                        active={active}
                        onClick={(e) => {
                          e.stopPropagation();
                          setMode(gm.id);
                        }}
                      />
                    </div>

                    <div className="flex items-baseline gap-2 mt-4">
                      <h4 className="text-[16.5px] font-bold text-[#1A1A1E]">{gm.name_zh}</h4>
                      <span className="text-[11.5px] text-[#6F7078]">{gm.name_en}</span>
                    </div>

                    <p className="text-[12.5px] text-[#61626A] mt-1.5 leading-relaxed line-clamp-3">
                      {gm.description}
                    </p>
                  </div>

                  <div className="mt-4 pt-3 border-t border-black/[0.05] flex items-center justify-between text-[10.5px] font-bold tracking-wide">
                    <span style={{ color: vis.colors[0] }}>{vis.badge}</span>
                    {active && <span className="text-[#007AFF]">● ACTIVE</span>}
                  </div>
                </div>
              );
            })}
          </div>
        </section>

        {/* STEP 2: Configure Combatant Seats */}
        <section className="space-y-3.5">
          <div className="flex items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <span className="w-6 h-6 rounded-full bg-[#007AFF]/10 border border-[#007AFF]/20 text-[#007AFF] text-[11px] font-bold flex items-center justify-center">
                2
              </span>
              <div>
                <h3 className="text-[17.5px] font-bold text-[#1A1A1E] leading-snug">
                  配置参战席位（{seats.length} / 6 席）
                </h3>
                <p className="text-[12.5px] text-[#61626A]">
                  每个席位可选全自动开源渗透 Harness、真人白帽，或「人机合体」协同模式
                </p>
              </div>
            </div>

            {seats.length < 6 && (
              <button
                type="button"
                onClick={addSeat}
                className="px-3.5 py-1.5 rounded-full bg-[#007AFF]/10 hover:bg-[#007AFF]/15 text-[#007AFF] text-[12px] font-semibold flex items-center gap-1 transition-colors"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>添加参战席位</span>
              </button>
            )}
          </div>

          {/* Preset Filter Pills */}
          <div className="flex flex-wrap gap-2">
            {QUICK_PRESETS.map((preset) => {
              const selected = activePresetId === preset.id;
              return (
                <button
                  key={preset.id}
                  type="button"
                  onClick={() => applyPreset(preset.id)}
                  className={`h-8 px-3.5 rounded-full text-[12px] font-semibold transition-all flex items-center gap-1.5 ${
                    selected
                      ? 'bg-[#007AFF] text-white shadow-[0_3px_8px_rgba(0,122,255,0.25)]'
                      : 'bg-white/85 hover:bg-white text-[#4A4B53] border border-black/[0.07]'
                  }`}
                >
                  <Flame className={`w-3.5 h-3.5 ${selected ? 'text-white' : 'text-[#EA580C]'}`} />
                  <span>{preset.label}</span>
                </button>
              );
            })}
          </div>

          {/* 2-Column Clean White Seat Cards */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
            {seats.map((seat, idx) => (
              <div
                key={idx}
                className="apple-card px-4 py-3.5 flex flex-wrap sm:flex-nowrap items-center justify-between gap-3"
              >
                <div className="flex items-center gap-3 min-w-0 flex-1">
                  <button
                    type="button"
                    onClick={() =>
                      updateSeat(idx, {
                        team_color:
                          FACTION_COLORS[
                            (FACTION_COLORS.indexOf(seat.team_color) + 1) % FACTION_COLORS.length
                          ],
                      })
                    }
                    style={{
                      backgroundColor: `${seat.team_color}1A`,
                      color: seat.team_color,
                      borderColor: `${seat.team_color}38`,
                    }}
                    className="w-9 h-9 rounded-xl border text-[12px] font-bold font-mono flex items-center justify-center shrink-0"
                    title="点击切换队伍标识色"
                  >
                    S{idx + 1}
                  </button>

                  <div className="min-w-0 flex-1 space-y-1">
                    <div className="flex flex-wrap items-center gap-2">
                      {seat.kind !== 'human' ? (
                        <select
                          value={seat.harness_id}
                          onChange={(e) => updateSeat(idx, { harness_id: e.target.value })}
                          className="bg-transparent text-[13.5px] font-bold text-[#1A1A1E] focus:outline-none pr-1"
                        >
                          {catalogHarnesses.map((h) => (
                            <option key={h.id} value={h.id}>
                              {h.name} ({h.stars})
                            </option>
                          ))}
                        </select>
                      ) : (
                        <input
                          value={seat.name}
                          onChange={(e) => updateSeat(idx, { name: e.target.value })}
                          className="w-32 bg-[#F4F4F7] rounded-lg px-2 py-0.5 text-[13px] font-bold text-[#1A1A1E] focus:outline-none"
                        />
                      )}

                      <select
                        value={seat.kind}
                        onChange={(e) => updateSeat(idx, { kind: e.target.value as SeatKind })}
                        className="text-[11px] font-semibold px-2 py-0.5 rounded-full bg-[#007AFF]/10 text-[#007AFF] focus:outline-none"
                      >
                        <option value="harness">自主智能体</option>
                        <option value="centaur">半人马混编</option>
                        <option value="human">真人白帽</option>
                      </select>
                    </div>

                    <div className="flex items-center gap-2 text-[11.5px] text-[#61626A]">
                      {seat.kind !== 'human' ? (
                        <select
                          value={seat.model}
                          onChange={(e) => updateSeat(idx, { model: e.target.value })}
                          className="bg-transparent font-mono text-[11.5px] text-[#61626A] focus:outline-none"
                        >
                          {BASE_MODELS.map((m) => (
                            <option key={m} value={m}>
                              ✦ {m}
                            </option>
                          ))}
                        </select>
                      ) : (
                        <span className="font-mono text-[#D1800A]">Kali Linux 独立操作终端</span>
                      )}
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2.5 shrink-0">
                  <span className="hidden sm:inline-flex items-center gap-1 text-[11px] text-[#6F7078]">
                    <Lock className="w-3 h-3" />
                    唯一网关计量
                  </span>
                  {seats.length > 2 && (
                    <button
                      type="button"
                      onClick={() => removeSeat(idx)}
                      className="w-6 h-6 rounded-full bg-black/[0.06] hover:bg-[#DC2E33]/15 text-[#61626A] hover:text-[#DC2E33] flex items-center justify-center transition-colors"
                      title="移除该席位"
                    >
                      <X className="w-3.5 h-3.5" />
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* STEP 3: Target Map & Fair Token Budget + Launch CTA */}
        <section className="space-y-3.5">
          <div className="flex items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <span className="w-6 h-6 rounded-full bg-[#007AFF]/10 border border-[#007AFF]/20 text-[#007AFF] text-[11px] font-bold flex items-center justify-center">
                3
              </span>
              <div>
                <h3 className="text-[17.5px] font-bold text-[#1A1A1E] leading-snug">
                  选定漏洞靶标与公平 Token 预算
                </h3>
                <p className="text-[12.5px] text-[#61626A]">
                  所有席位锁定同一出口网关，预算耗尽返回 HTTP 402；同分时消耗 Token 更少者获胜
                </p>
              </div>
            </div>

            <button
              type="button"
              onClick={onBrowseArmory}
              className="text-[12.5px] font-semibold text-[#007AFF] hover:underline"
            >
              浏览全部 {catalogMaps.length} 款靶标 →
            </button>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-4">
            {/* Left 7 Cols: Target Map Selector + Title */}
            <div className="lg:col-span-7 apple-card p-5 space-y-4">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                <div>
                  <div className="text-[11px] font-semibold text-[#6F7078]">当前实战靶标地图</div>
                  <div className="text-[15.5px] font-bold text-[#1A1A1E] mt-0.5">
                    {selectedMap.name}
                  </div>
                </div>
                <div className="relative w-full sm:w-64">
                  <Search className="w-3.5 h-3.5 text-[#6F7078] absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
                  <input
                    value={mapSearch}
                    onChange={(e) => setMapSearch(e.target.value)}
                    placeholder="快速检索靶标或 CVE…"
                    className="w-full h-8 pl-8 pr-3 rounded-full bg-[#F4F4F7] border border-black/[0.06] text-xs text-[#1A1A1E] focus:bg-white focus:outline-none focus:border-[#007AFF]"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 max-h-40 overflow-y-auto pr-1">
                {filteredMaps.map((m) => {
                  const active = selectedMap.id === m.id;
                  return (
                    <button
                      key={m.id}
                      type="button"
                      onClick={() => setMapId(m.id)}
                      className={`text-left px-3 py-2 rounded-xl border text-[12px] flex items-center justify-between gap-2 transition-all ${
                        active
                          ? 'bg-[#007AFF]/10 border-[#007AFF]/45 text-[#007AFF] font-semibold'
                          : 'bg-[#F7F8FA] hover:bg-[#EFEFF4] border-black/[0.05] text-[#2C2D33]'
                      }`}
                    >
                      <span className="truncate">{m.name}</span>
                      <span className="text-[10px] font-mono uppercase px-1.5 py-0.5 rounded bg-white text-[#6F7078] shrink-0">
                        {m.category}
                      </span>
                    </button>
                  );
                })}
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2 border-t border-black/[0.06]">
                <div className="sm:col-span-2">
                  <label className="block text-[11px] font-medium text-[#6F7078] mb-1">
                    对决房间标题
                  </label>
                  <input
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    className="w-full h-9 px-3 rounded-xl bg-[#F4F4F7] border border-black/[0.06] text-[13px] font-semibold text-[#1A1A1E] focus:bg-white focus:outline-none focus:border-[#007AFF]"
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="block text-[11px] font-medium text-[#6F7078] mb-1">
                      单轮时长
                    </label>
                    <select
                      value={roundSeconds}
                      onChange={(e) => setRoundSeconds(Number(e.target.value))}
                      className="w-full h-9 px-2 rounded-xl bg-[#F4F4F7] border border-black/[0.06] text-xs font-semibold text-[#1A1A1E]"
                    >
                      <option value={35}>35 秒</option>
                      <option value={45}>45 秒</option>
                      <option value={60}>60 秒</option>
                      <option value={120}>120 秒</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-[11px] font-medium text-[#6F7078] mb-1">
                      总轮次
                    </label>
                    <select
                      value={maxRounds}
                      onChange={(e) => setMaxRounds(Number(e.target.value))}
                      className="w-full h-9 px-2 rounded-xl bg-[#F4F4F7] border border-black/[0.06] text-xs font-semibold text-[#1A1A1E]"
                    >
                      <option value={3}>3 轮</option>
                      <option value={5}>5 轮</option>
                      <option value={10}>10 轮</option>
                      <option value={15}>15 轮</option>
                    </select>
                  </div>
                </div>
              </div>
            </div>

            {/* Right 5 Cols: Fixed Token Budget + Launch CTA */}
            <div className="lg:col-span-5 apple-card p-5 flex flex-col justify-between space-y-4">
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-[13.5px] font-bold text-[#1A1A1E]">
                    单席固定 Token 预算池
                  </span>
                  <span className="font-mono font-bold text-[15px] text-[#007AFF]">
                    {formatTokenCompact(tokenBudget)} Tokens
                  </span>
                </div>

                <input
                  type="range"
                  min={25_000}
                  max={5_000_000}
                  step={25_000}
                  value={tokenBudget}
                  onChange={(e) => setTokenBudget(Number(e.target.value))}
                  className="w-full accent-[#007AFF]"
                />

                <div className="flex flex-wrap gap-1.5">
                  {MANA_STEPS.map((st) => (
                    <button
                      key={st.value}
                      type="button"
                      onClick={() => setTokenBudget(st.value)}
                      className={`px-2.5 py-1 rounded-full text-[11px] font-semibold transition-colors ${
                        tokenBudget === st.value
                          ? 'bg-[#007AFF] text-white'
                          : 'bg-[#F4F4F7] text-[#61626A] hover:bg-[#E8E9EF]'
                      }`}
                    >
                      {st.label}
                    </button>
                  ))}
                </div>

                {/* Optional Upstream API Key Accordion */}
                <div className="pt-2 border-t border-black/[0.06]">
                  <button
                    type="button"
                    onClick={() => setLlmDrawerOpen((v) => !v)}
                    className="w-full flex items-center justify-between text-[11.5px] font-medium text-[#61626A] hover:text-[#1A1A1E]"
                  >
                    <span className="flex items-center gap-1.5">
                      <KeyRound className="w-3.5 h-3.5 text-[#007AFF]" />
                      可选：自定义上游大模型网关与执行驱动 ({driver})
                    </span>
                    {llmDrawerOpen ? (
                      <ChevronUp className="w-4 h-4" />
                    ) : (
                      <ChevronDown className="w-4 h-4" />
                    )}
                  </button>

                  {llmDrawerOpen && (
                    <div className="mt-2.5 space-y-2 text-xs">
                      <input
                        value={upstreamUrl}
                        onChange={(e) => setUpstreamUrl(e.target.value)}
                        placeholder="Upstream Base URL（留空使用服务端默认上游配置）"
                        className="w-full bg-[#F4F4F7] border border-black/[0.07] rounded-xl px-3 py-1.5 font-mono text-[#1A1A1E] focus:bg-white focus:outline-none"
                      />
                      <input
                        type="password"
                        value={upstreamKey}
                        onChange={(e) => setUpstreamKey(e.target.value)}
                        placeholder="Upstream API Key（选填）"
                        className="w-full bg-[#F4F4F7] border border-black/[0.07] rounded-xl px-3 py-1.5 font-mono text-[#1A1A1E] focus:bg-white focus:outline-none"
                      />
                      <div className="flex gap-1.5">
                        {(['auto', 'docker'] as const).map((d) => (
                          <button
                            key={d}
                            type="button"
                            onClick={() => setDriver(d)}
                            className={`flex-1 py-1 rounded-lg text-[11px] font-semibold uppercase ${
                              driver === d
                                ? 'bg-[#007AFF] text-white'
                                : 'bg-[#F4F4F7] text-[#61626A]'
                            }`}
                          >
                            {d}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              </div>

              <button
                type="button"
                onClick={handleUnleash}
                className="w-full h-12 rounded-2xl bg-[#007AFF] hover:bg-[#0066D6] active:scale-[0.99] shadow-[0_8px_20px_rgba(0,122,255,0.28)] text-white font-bold text-[15px] flex items-center justify-center gap-2 transition-all"
              >
                <Play className="w-4 h-4 fill-white" />
                <span>立即开始攻防对决</span>
              </button>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
};
