import React, { useState } from 'react';
import {
  CheckCircle2,
  Minus,
  PanelLeft,
  Play,
  Plus,
  RefreshCw,
  Search,
  Server,
  Settings,
  Volume2,
  VolumeX,
} from 'lucide-react';
import { HealthResponse } from '../types/pit';

export type PrimaryTab = 'arena' | 'armory' | 'leaderboard';
export type ArenaSubStage = 'hud' | 'lobby';
export type ArmorySubSection = 'maps' | 'harnesses';

interface TopGlobalBarProps {
  pageTitle: string;
  activeTab: PrimaryTab;
  arenaSubStage: ArenaSubStage;
  sidebarCollapsed: boolean;
  onToggleSidebar: () => void;
  onSelectTab: (tab: PrimaryTab) => void;
  onSelectArenaSubStage: (stage: ArenaSubStage) => void;
  armoryQuery: string;
  onChangeArmoryQuery: (q: string) => void;
  uiScale: number;
  onZoomIn: () => void;
  onZoomOut: () => void;
  onZoomReset: () => void;
  backendConnected: boolean;
  apiBaseUrl: string;
  onSaveApiBaseUrl: (url: string) => void;
  onReprobeBackend: () => void;
  health: HealthResponse | null;
  sfxEnabled: boolean;
  onToggleSfx: () => void;
}

export const TopGlobalBar: React.FC<TopGlobalBarProps> = ({
  pageTitle,
  activeTab,
  arenaSubStage,
  sidebarCollapsed,
  onToggleSidebar,
  onSelectTab,
  onSelectArenaSubStage,
  armoryQuery,
  onChangeArmoryQuery,
  uiScale,
  onZoomIn,
  onZoomOut,
  onZoomReset,
  backendConnected,
  apiBaseUrl,
  onSaveApiBaseUrl,
  onReprobeBackend,
  health,
  sfxEnabled,
  onToggleSfx,
}) => {
  const [configOpen, setConfigOpen] = useState(false);
  const [draftUrl, setDraftUrl] = useState(apiBaseUrl || 'http://127.0.0.1:18880');

  const probes = health?.ebpf?.attached_probes ?? [];
  const perf = health?.ebpf?.perf_stats;

  const zoomPct = Math.round(uiScale * 100);

  return (
    <header className="relative z-40 h-[56px] px-6 apple-frosted-topbar border-b border-black/[0.06] flex items-center justify-between gap-4 select-none shrink-0">
      {/* Left: Sidebar Toggle + Current Page Title + Truthful Engine Pill */}
      <div className="flex items-center gap-3 min-w-0">
        <button
          type="button"
          onClick={onToggleSidebar}
          className="w-8 h-8 rounded-full bg-white/80 hover:bg-white border border-black/[0.08] flex items-center justify-center text-[#4A4B53] hover:text-[#1A1A1E] transition-colors shrink-0"
          title={sidebarCollapsed ? '展开左侧导航栏' : '收起左侧导航栏（宽屏视野）'}
        >
          <PanelLeft className="w-4 h-4" />
        </button>

        <h1 className="text-[15px] font-semibold text-[#1A1A1E] truncate">{pageTitle}</h1>

        <div className="hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-black/[0.042] text-[11px] font-medium text-[#61626A] shrink-0">
          <span
            className={`w-1.5 h-1.5 rounded-full ${
              backendConnected ? 'bg-[#1C9457]' : 'bg-[#D1800A]'
            }`}
          />
          <span>
            {backendConnected
              ? health?.ebpf?.mode === 'kernel_ebpf'
                ? `Linux eBPF 真机在线${perf ? ` · 内核直滤 ${perf.kernel_filter_pct.toFixed(1)}%` : ''}`
                : 'pitd 后端已连接'
              : '未连接 pitd 后端'}
          </span>
        </div>
      </div>

      {/* Right: Contextual Search / Quick Action + UI Zoom (`⌘- / ⌘0 / ⌘+`) + SFX + Settings */}
      <div className="flex items-center gap-2.5 shrink-0">
        {activeTab === 'armory' ? (
          <div className="relative w-56 md:w-64">
            <Search className="w-3.5 h-3.5 text-[#6F7078] absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
            <input
              value={armoryQuery}
              onChange={(e) => onChangeArmoryQuery(e.target.value)}
              placeholder="搜索靶标、CVE 编号或智能体…"
              className="w-full h-8 pl-8 pr-3 rounded-full bg-black/[0.045] hover:bg-black/[0.06] focus:bg-white border border-transparent focus:border-[#007AFF]/45 text-[12.5px] text-[#1A1A1E] placeholder-[#6F7078] focus:outline-none transition-all"
            />
          </div>
        ) : activeTab === 'arena' && arenaSubStage === 'lobby' ? (
          <button
            type="button"
            onClick={() => onSelectArenaSubStage('hud')}
            className="h-8 px-3.5 rounded-full bg-[#007AFF]/10 hover:bg-[#007AFF]/15 border border-[#007AFF]/20 text-[12px] font-semibold text-[#007AFF] flex items-center gap-1.5 transition-colors"
          >
            <Play className="w-3 h-3 fill-current" />
            <span>查看实况战场</span>
          </button>
        ) : (
          <button
            type="button"
            onClick={() => {
              onSelectTab('arena');
              onSelectArenaSubStage('lobby');
            }}
            className="h-8 px-3.5 rounded-full bg-white hover:bg-[#F8F9FB] border border-black/[0.08] shadow-[0_1px_3px_rgba(0,0,0,0.04)] text-[12px] font-semibold text-[#1A1A1E] flex items-center gap-1 transition-colors"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>新建对决</span>
          </button>
        )}

        {/* UI Scale Capsule (`⌘-` / `⌘0` / `⌘+`) */}
        <div
          className="flex items-center h-8 px-1 rounded-full bg-white/85 border border-black/[0.075] shadow-[0_1px_2px_rgba(0,0,0,0.03)]"
          title="支持键盘 Command/Ctrl + '+' / '-' 调整界面大小，Command + 0 恢复 100%"
        >
          <button
            type="button"
            onClick={onZoomOut}
            className="w-6 h-6 rounded-full hover:bg-black/[0.05] flex items-center justify-center text-[#61626A]"
            title="缩小界面 (⌘-)"
          >
            <Minus className="w-3 h-3" />
          </button>
          <button
            type="button"
            onClick={onZoomReset}
            className={`px-1.5 h-6 rounded text-[11px] font-mono font-semibold tabular-nums ${
              zoomPct === 100 ? 'text-[#61626A]' : 'text-[#007AFF]'
            }`}
            title="恢复默认大小 100% (⌘0)"
          >
            {zoomPct}%
          </button>
          <button
            type="button"
            onClick={onZoomIn}
            className="w-6 h-6 rounded-full hover:bg-black/[0.05] flex items-center justify-center text-[#61626A]"
            title="放大界面 (⌘+)"
          >
            <Plus className="w-3 h-3" />
          </button>
        </div>

        {/* Sound Toggle */}
        <button
          type="button"
          onClick={onToggleSfx}
          className={`w-8 h-8 rounded-full border flex items-center justify-center transition-colors ${
            sfxEnabled
              ? 'bg-[#007AFF]/10 border-[#007AFF]/25 text-[#007AFF]'
              : 'bg-white/85 hover:bg-white border-black/[0.08] text-[#61626A]'
          }`}
          title="切换战场实时音效"
        >
          {sfxEnabled ? <Volume2 className="w-3.5 h-3.5" /> : <VolumeX className="w-3.5 h-3.5" />}
        </button>

        {/* Connection & eBPF Probe Settings Popover */}
        <div className="relative">
          <button
            type="button"
            onClick={() => setConfigOpen((v) => !v)}
            className="w-8 h-8 rounded-full bg-white/85 hover:bg-white border border-black/[0.08] flex items-center justify-center text-[#61626A] hover:text-[#1A1A1E] transition-colors"
            title="设置 pitd 服务端连接与查看 Linux eBPF 探针"
          >
            <Settings className="w-4 h-4" />
          </button>

          {configOpen && (
            <div className="absolute right-0 mt-2 w-96 rounded-2xl bg-white border border-black/[0.09] shadow-[0_18px_42px_rgba(0,0,0,0.14)] p-4 z-50 text-left">
              <div className="flex items-center justify-between pb-2.5 mb-3 border-b border-black/[0.06]">
                <div className="flex items-center gap-2">
                  <Server className="w-4 h-4 text-[#007AFF]" />
                  <span className="font-semibold text-[13px] text-[#1A1A1E]">
                    服务端控制面与内核探针
                  </span>
                </div>
                <span
                  className={`text-[10.5px] font-semibold px-2.5 py-0.5 rounded-full ${
                    backendConnected
                      ? 'bg-[#1C9457]/10 text-[#1C9457]'
                      : 'bg-[#D1800A]/12 text-[#D1800A]'
                  }`}
                >
                  {backendConnected ? 'pitd 真机已连' : '后端未连接'}
                </span>
              </div>

              {perf && (
                <div className="mb-3 p-2.5 rounded-xl bg-[#F4F8FF] border border-[#007AFF]/18 text-[11px] space-y-1">
                  <div className="flex items-center justify-between font-semibold text-[#1A1A1E]">
                    <span>⚡ Ring-0 Per-CPU 零锁遥测 ({perf.cpu_cores} 核)</span>
                    <span className="font-mono text-[#007AFF]">
                      过滤率 {perf.kernel_filter_pct.toFixed(2)}%
                    </span>
                  </div>
                  <div className="flex items-center justify-between font-mono text-[10.5px] text-[#61626A]">
                    <span>内核扫描 {perf.syscalls_entered.toLocaleString()} 次</span>
                    <span>
                      {(perf.ringbuf_capacity_bytes / (1024 * 1024)).toFixed(0)}MB RingBuf · 丢包{' '}
                      {perf.ringbuf_drops}
                    </span>
                  </div>
                </div>
              )}

              <label className="block text-[11.5px] text-[#61626A] font-medium mb-1.5">
                pitd 接口地址（留空自动探测同源或 127.0.0.1:18880）
              </label>
              <div className="flex gap-2 mb-3.5">
                <input
                  value={draftUrl}
                  onChange={(e) => setDraftUrl(e.target.value)}
                  placeholder="http://127.0.0.1:18880"
                  className="flex-1 bg-[#F4F4F7] border border-black/[0.08] rounded-xl px-3 py-1.5 text-xs font-mono text-[#1A1A1E] focus:bg-white focus:outline-none focus:border-[#007AFF]"
                />
                <button
                  type="button"
                  onClick={() => {
                    onSaveApiBaseUrl(draftUrl);
                    onReprobeBackend();
                    setConfigOpen(false);
                  }}
                  className="px-3.5 py-1.5 rounded-xl bg-[#007AFF] hover:bg-[#0066D6] text-white font-semibold text-xs flex items-center gap-1"
                >
                  <RefreshCw className="w-3 h-3" />
                  重连
                </button>
              </div>

              <div className="text-[11.5px] font-medium text-[#61626A] mb-1.5">
                已挂载 Linux 内核 eBPF 探针（{probes.length} 个）：
              </div>
              {probes.length > 0 ? (
                <div className="space-y-1 max-h-40 overflow-y-auto pr-1">
                  {probes.map((p) => (
                    <div
                      key={p}
                      className="flex items-center justify-between px-2.5 py-1.5 rounded-xl bg-[#F6F7FA] border border-black/[0.05] font-mono text-[11px]"
                    >
                      <span className="text-[#1A1A1E]">{p}</span>
                      <CheckCircle2 className="w-3.5 h-3.5 text-[#1C9457] shrink-0" />
                    </div>
                  ))}
                </div>
              ) : (
                <div className="p-3 rounded-xl bg-[#F6F7FA] border border-black/[0.05] text-[11.5px] text-[#6F7078] text-center">
                  尚未探测到挂载中的内核 eBPF 探针
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </header>
  );
};
