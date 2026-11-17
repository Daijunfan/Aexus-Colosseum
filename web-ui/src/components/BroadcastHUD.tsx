import React, { useEffect, useState } from 'react';
import {
  Activity,
  ChevronDown,
  Clock,
  Globe,
  Layers,
  Pause,
  Play,
  Plus,
  Radio,
  ShieldCheck,
  SkipForward,
  SlidersHorizontal,
  Square,
  Terminal,
  Video,
  Zap,
} from 'lucide-react';
import { CameraLens, HealthResponse, MatchState } from '../types/pit';
import { GladiatorStrip } from './GladiatorStrip';
import { ColosseumCanvas } from './ColosseumCanvas';
import { OrganAnatomyView } from './OrganAnatomyView';
import { WebHijackView } from './WebHijackView';
import { BottomCasterBar } from './BottomCasterBar';
import { GAME_MODE_SPECS } from '../data/armoryCatalog';

interface BroadcastHUDProps {
  match: MatchState | null;
  health: HealthResponse | null;
  backendConnected: boolean;
  ebpfEventsCount: number;
  focusedSeatId: string;
  xrayOpen: boolean;
  onSelectSeat: (seatId: string) => void;
  onOpenXrayForSeat: (seatId: string) => void;
  onToggleXray: () => void;
  onOpenLobby: () => void;
  onTogglePause: () => void;
  onStopMatch: () => void;
  onNextRound: () => void;
  onTriggerChaos: (chaosType: 'drop_waf' | 'leak_hint' | 'surge_traffic') => void;
  onOpenPoster: () => void;
  onExportReplay: () => void;
}

export const BroadcastHUD: React.FC<BroadcastHUDProps> = ({
  match,
  health,
  backendConnected,
  ebpfEventsCount,
  focusedSeatId,
  xrayOpen,
  onSelectSeat,
  onOpenXrayForSeat,
  onToggleXray,
  onOpenLobby,
  onTogglePause,
  onStopMatch,
  onNextRound,
  onTriggerChaos,
  onOpenPoster,
  onExportReplay,
}) => {
  const [autoDirector, setAutoDirector] = useState(true);
  const [manualLens, setManualLens] = useState<CameraLens>('MACRO_ARENA');
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    if (autoDirector && match?.camera_cue?.lens) {
      setManualLens(match.camera_cue.lens);
    }
  }, [autoDirector, match?.camera_cue?.ts_ms, match?.camera_cue?.lens]);

  if (!match) {
    const probesCount = health?.ebpf?.attached_probes?.length ?? 0;
    return (
      <div className="flex-1 flex items-center justify-center p-8 overflow-y-auto">
        <div className="apple-card max-w-xl w-full p-8 text-center space-y-5">
          <div className="w-12 h-12 rounded-2xl bg-[#007AFF]/10 text-[#007AFF] flex items-center justify-center mx-auto">
            <Activity className="w-6 h-6" />
          </div>

          <div className="space-y-1.5">
            <div className="text-[10.5px] font-bold tracking-[0.14em] text-[#6F7078] uppercase">
              AEXUS COLOSSEUM · REAL KERNEL TELEMETRY STAGE
            </div>
            <h3 className="text-[24px] font-bold text-[#1A1A1E] tracking-tight">
              实况战场已就绪 · 尚无进行中的对决
            </h3>
            <p className="text-[13px] text-[#61626A] leading-relaxed">
              所有对决均运行在真实 Docker 容器与宿主机 Linux eBPF 内核探针下。请先在大厅创建并启动一场对决，本页将实时流式渲染攻击光束、连招特写与源码热补丁。
            </p>
          </div>

          <div className="grid grid-cols-3 gap-2.5 text-left">
            <div className="rounded-xl bg-[#F7F8FA] border border-black/[0.05] p-3">
              <div className="text-[10.5px] text-[#6F7078]">后端节点</div>
              <div
                className={`text-[12.5px] font-bold mt-0.5 flex items-center gap-1.5 ${
                  backendConnected ? 'text-[#1C9457]' : 'text-[#DC2E33]'
                }`}
              >
                <span
                  className={`w-2 h-2 rounded-full ${
                    backendConnected ? 'bg-[#1C9457]' : 'bg-[#DC2E33]'
                  }`}
                />
                {backendConnected ? 'pitd 在线' : '未连接'}
              </div>
            </div>

            <div className="rounded-xl bg-[#F7F8FA] border border-black/[0.05] p-3">
              <div className="text-[10.5px] text-[#6F7078]">Linux eBPF 探针</div>
              <div className="text-[12.5px] font-bold font-mono text-[#1A1A1E] mt-0.5">
                {backendConnected ? `${probesCount} 探针 (${health?.ebpf?.mode ?? 'ready'})` : '0 探针'}
              </div>
            </div>

            <div className="rounded-xl bg-[#F7F8FA] border border-black/[0.05] p-3">
              <div className="text-[10.5px] text-[#6F7078]">Docker 沙箱</div>
              <div className="text-[12.5px] font-bold text-[#1A1A1E] mt-0.5 flex items-center gap-1">
                <ShieldCheck className="w-3.5 h-3.5 text-[#007AFF]" />
                {health?.docker?.available ? `v${health.docker.version || 'ready'}` : '待就绪'}
              </div>
            </div>
          </div>

          <button
            type="button"
            onClick={onOpenLobby}
            className="h-10 px-5 rounded-full bg-[#007AFF] hover:bg-[#0066D6] shadow-[0_6px_16px_rgba(0,122,255,0.28)] text-white text-[13px] font-semibold inline-flex items-center gap-1.5 transition-all"
          >
            <Plus className="w-4 h-4" />
            <span>前往创建实网对决</span>
          </button>
        </div>
      </div>
    );
  }

  const activeLens: CameraLens = autoDirector ? match.camera_cue.lens : manualLens;
  const modeSpec = GAME_MODE_SPECS.find((m) => m.id === match.mode) ?? GAME_MODE_SPECS[0];

  const mins = Math.floor(match.round_remaining_sec / 60);
  const secs = Math.floor(match.round_remaining_sec % 60);
  const isPaused = match.status === 'paused';
  const isCompleted = match.status === 'completed' || match.status === 'finished';

  return (
    <div className="flex-1 flex flex-col min-h-0 px-5 pt-3.5 pb-3.5 gap-3 overflow-hidden">
      {/* 1. Clean Apple Stage Control Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 shrink-0 select-none">
        <div className="flex items-center gap-2.5 text-[12.5px]">
          <span className="px-3 py-1 rounded-full bg-[#007AFF] text-white text-[11.5px] font-bold">
            {modeSpec.name_zh}
          </span>

          <span className="font-semibold text-[#1A1A1E] tabular-nums">
            第 {match.round}/{match.max_rounds} 轮
          </span>

          <span className="text-[#8E8F97]">•</span>

          {isCompleted ? (
            <span className="px-2.5 py-0.5 rounded-full bg-[#1C9457]/12 text-[#1C9457] font-semibold text-[11.5px] tabular-nums">
              已完赛结算 · 用时 {match.elapsed_sec}s
            </span>
          ) : isPaused ? (
            <span className="px-2.5 py-0.5 rounded-full bg-[#D1800A]/12 text-[#D1800A] font-semibold text-[11.5px]">
              已暂停 · {String(mins).padStart(2, '0')}:{String(secs).padStart(2, '0')}
            </span>
          ) : (
            <span className="flex items-center gap-1 font-mono text-[#61626A] tabular-nums">
              <Clock className="w-3.5 h-3.5" />
              {String(mins).padStart(2, '0')}:{String(secs).padStart(2, '0')}
            </span>
          )}

          <span className="text-[#8E8F97] hidden md:inline">•</span>

          <span className="hidden md:inline text-[12px] font-medium text-[#1C9457]">
            eBPF {ebpfEventsCount.toLocaleString()} 条指令
          </span>
        </div>

        {/* Right: Self-Explanatory Apple Segmented Lens Switcher + Auto-Director + Inspector */}
        <div className="flex items-center gap-2">
          <div className="flex items-center p-1 rounded-[11px] bg-black/[0.055]">
            {(
              [
                { id: 'MACRO_ARENA' as CameraLens, label: '全局攻防态势', icon: Radio },
                { id: 'XRAY_ORGAN' as CameraLens, label: '靶机五层透视', icon: Layers },
                { id: 'LIVE_WEB_HIJACK' as CameraLens, label: '目标网页实况', icon: Globe },
              ] as const
            ).map((tab) => {
              const Icon = tab.icon;
              const selected = activeLens === tab.id;
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => {
                    setAutoDirector(false);
                    setManualLens(tab.id);
                  }}
                  className={`h-7 px-3 rounded-[8px] text-[12px] flex items-center gap-1.5 transition-all whitespace-nowrap ${
                    selected
                      ? 'bg-white text-[#1A1A1E] font-semibold shadow-[0_1px_4px_rgba(0,0,0,0.08)]'
                      : 'text-[#61626A] hover:text-[#1A1A1E] font-medium'
                  }`}
                >
                  <Icon className="w-3.5 h-3.5" />
                  <span>{tab.label}</span>
                </button>
              );
            })}
          </div>

          <button
            type="button"
            onClick={() => setAutoDirector((v) => !v)}
            title={match.camera_cue?.reason || '根据关键破防与补丁事件自动切换视角'}
            className={`h-8 px-3 rounded-full border text-[12px] font-medium flex items-center gap-1.5 transition-all ${
              autoDirector
                ? 'bg-[#007AFF]/10 border-[#007AFF]/25 text-[#007AFF] font-semibold'
                : 'bg-white border-black/[0.08] text-[#61626A]'
            }`}
          >
            <Video className="w-3.5 h-3.5" />
            <span>自动导播</span>
          </button>

          <button
            type="button"
            onClick={onToggleXray}
            title="快捷键 Space：展开或收起底层终端、eBPF 与源码补丁检视台"
            className={`h-8 px-3.5 rounded-full border text-[12px] font-semibold flex items-center gap-1.5 transition-all ${
              xrayOpen
                ? 'bg-[#007AFF] border-[#007AFF] text-white shadow-[0_3px_10px_rgba(0,122,255,0.28)]'
                : 'bg-white hover:bg-[#F7F8FA] border-black/[0.08] text-[#1A1A1E]'
            }`}
          >
            <Terminal className="w-3.5 h-3.5" />
            <span>{xrayOpen ? '收起检视台' : '底层检视台'}</span>
          </button>

          {/* Match Control Popover Menu */}
          <div className="relative">
            <button
              type="button"
              onClick={() => setMenuOpen((v) => !v)}
              className="h-8 px-3 rounded-full bg-white hover:bg-[#F7F8FA] border border-black/[0.08] text-[12px] font-semibold text-[#1A1A1E] flex items-center gap-1"
            >
              <SlidersHorizontal className="w-3.5 h-3.5 text-[#61626A]" />
              <span>场控</span>
              <ChevronDown className="w-3 h-3 text-[#6F7078]" />
            </button>

            {menuOpen && (
              <div className="absolute right-0 mt-1.5 w-52 rounded-2xl bg-white border border-black/[0.08] shadow-[0_14px_34px_rgba(0,0,0,0.12)] py-1.5 z-50 text-[12.5px]">
                {!isCompleted ? (
                  <>
                    <button
                      type="button"
                      onClick={() => {
                        onTogglePause();
                        setMenuOpen(false);
                      }}
                      className="w-full px-3.5 py-2 text-left hover:bg-[#F4F4F7] flex items-center gap-2 text-[#1A1A1E]"
                    >
                      {isPaused ? (
                        <Play className="w-3.5 h-3.5 text-[#1C9457]" />
                      ) : (
                        <Pause className="w-3.5 h-3.5 text-[#D1800A]" />
                      )}
                      <span>{isPaused ? '继续比赛' : '暂停比赛'}</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        onNextRound();
                        setMenuOpen(false);
                      }}
                      className="w-full px-3.5 py-2 text-left hover:bg-[#F4F4F7] flex items-center gap-2 text-[#1A1A1E]"
                    >
                      <SkipForward className="w-3.5 h-3.5 text-[#007AFF]" />
                      <span>推进下一轮</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        onStopMatch();
                        setMenuOpen(false);
                      }}
                      className="w-full px-3.5 py-2 text-left hover:bg-[#FEF2F2] flex items-center gap-2 text-[#DC2E33] font-semibold"
                    >
                      <Square className="w-3.5 h-3.5" />
                      <span>结束本局对决</span>
                    </button>
                    <div className="my-1 border-t border-black/[0.06]" />
                    <button
                      type="button"
                      onClick={() => {
                        onTriggerChaos('drop_waf');
                        setMenuOpen(false);
                      }}
                      className="w-full px-3.5 py-2 text-left hover:bg-[#F4F4F7] flex items-center gap-2 text-[#DC2E33]"
                    >
                      <Zap className="w-3.5 h-3.5" />
                      <span>随机事件：熔断 WAF 护盾</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        onTriggerChaos('leak_hint');
                        setMenuOpen(false);
                      }}
                      className="w-full px-3.5 py-2 text-left hover:bg-[#F4F4F7] flex items-center gap-2 text-[#D1800A]"
                    >
                      <Zap className="w-3.5 h-3.5" />
                      <span>随机事件：广播漏洞坐标</span>
                    </button>
                  </>
                ) : (
                  <button
                    type="button"
                    onClick={() => {
                      onOpenLobby();
                      setMenuOpen(false);
                    }}
                    className="w-full px-3.5 py-2 text-left hover:bg-[#F4F4F7] flex items-center gap-2 text-[#007AFF] font-semibold"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>前往大厅创建新对决</span>
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* 2. Top Ranked Contestant Scorecards (SLA ECG + Token Quota) */}
      <GladiatorStrip
        seats={match.seats}
        focusedSeatId={focusedSeatId}
        firstBloodSeatId={match.first_blood_seat_id}
        onSelectSeat={onSelectSeat}
        onOpenPossessTerminal={onOpenXrayForSeat}
      />

      {/* 3. Main Stage Viewport */}
      <div className="flex-1 min-h-0 relative">
        {activeLens === 'MACRO_ARENA' && (
          <ColosseumCanvas
            match={match}
            health={health}
            focusedSeatId={focusedSeatId}
            onSelectSeat={onSelectSeat}
            onInspectInXray={onToggleXray}
            onOpenPoster={onOpenPoster}
            onOpenLobby={onOpenLobby}
          />
        )}
        {activeLens === 'XRAY_ORGAN' && <OrganAnatomyView match={match} />}
        {activeLens === 'LIVE_WEB_HIJACK' && <WebHijackView match={match} />}
      </div>

      {/* 4. Bottom AI Caster & Export Action Bar */}
      <BottomCasterBar
        match={match}
        focusedSeatName={match.seats.find((s) => s.id === focusedSeatId)?.name ?? 'Strix'}
        onOpenInspector={() => onOpenXrayForSeat(focusedSeatId)}
        onOpenLobby={onOpenLobby}
        onOpenPoster={onOpenPoster}
        onExportReplay={onExportReplay}
      />
    </div>
  );
};
