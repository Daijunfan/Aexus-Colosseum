import React, { useMemo, useState } from 'react';
import {
  ChevronDown,
  Cpu,
  FileDiff,
  Lightbulb,
  Send,
  Terminal,
  Wrench,
} from 'lucide-react';
import { EbpfEvent, MatchState } from '../types/pit';

interface XRayVisorOverlayProps {
  open: boolean;
  sidebarCollapsed?: boolean;
  match: MatchState;
  focusedSeatId: string;
  onSelectSeat: (seatId: string) => void;
  onClose: () => void;
  onTogglePossess: (seatId: string, enabled: boolean) => void;
  onSendTerminalCommand: (seatId: string, cmd: string) => void;
  onDropHint: (seatId: string, hint: string) => void;
  onTriggerChaos: (chaosType: 'drop_waf' | 'leak_hint' | 'surge_traffic') => void;
}

export const XRayVisorOverlay: React.FC<XRayVisorOverlayProps> = ({
  open,
  sidebarCollapsed = false,
  match,
  focusedSeatId,
  onSelectSeat,
  onClose,
  onTogglePossess,
  onSendTerminalCommand,
  onDropHint,
}) => {
  const [cmdInput, setCmdInput] = useState('');
  const [hintInput, setHintInput] = useState('');
  const [probeFilter, setProbeFilter] = useState<string>('ALL');

  const seat = match.seats.find((s) => s.id === focusedSeatId) ?? match.seats[0];
  const termEntries = (seat ? match.terminals[seat.id] : []) ?? [];

  const filteredEvents: EbpfEvent[] = useMemo(() => {
    if (probeFilter === 'ALL') return match.events;
    if (probeFilter === 'SSL') {
      return match.events.filter((e) => e.probe.includes('SSL') || Boolean(e.cleartext_payload));
    }
    return match.events.filter((e) => e.probe.includes(probeFilter));
  }, [match.events, probeFilter]);

  if (!open || !seat) return null;

  const activePatch = match.patches[0];

  return (
    <div
      className={`fixed right-5 bottom-16 h-[340px] z-40 rounded-[22px] bg-white/98 backdrop-blur-2xl border border-black/[0.09] shadow-[0_-10px_40px_rgba(0,0,0,0.12)] flex flex-col overflow-hidden transition-all ${
        sidebarCollapsed ? 'left-5' : 'left-[308px]'
      }`}
    >
      {/* Clean Xcode-Light Inspector Toolbar */}
      <div className="h-11 px-4 bg-[#F5F6FA] border-b border-black/[0.06] flex items-center justify-between gap-3 shrink-0 select-none">
        <div className="flex items-center gap-3 min-w-0">
          <span className="flex items-center gap-1.5 text-[13px] font-bold text-[#1A1A1E] shrink-0">
            <Wrench className="w-3.5 h-3.5 text-[#007AFF]" />
            底层检视与人工接管台
          </span>

          {/* Seat Switcher Pills */}
          <div className="flex items-center gap-1.5 overflow-x-auto">
            {match.seats.map((s) => {
              const selected = s.id === seat.id;
              return (
                <button
                  key={s.id}
                  type="button"
                  onClick={() => onSelectSeat(s.id)}
                  className={`px-2.5 py-1 rounded-full text-[11.5px] flex items-center gap-1.5 shrink-0 transition-colors ${
                    selected
                      ? 'bg-[#007AFF]/12 text-[#007AFF] font-semibold'
                      : 'text-[#61626A] hover:bg-black/[0.04]'
                  }`}
                >
                  <span
                    className="w-1.5 h-1.5 rounded-full"
                    style={{ backgroundColor: s.team_color }}
                  />
                  <span>{s.name}</span>
                </button>
              );
            })}
          </div>
        </div>

        <button
          type="button"
          onClick={onClose}
          className="px-3 py-1 rounded-full bg-black/[0.05] hover:bg-black/[0.09] text-[11.5px] font-semibold text-[#61626A] flex items-center gap-1 shrink-0"
        >
          <span>收起 (Space)</span>
          <ChevronDown className="w-3.5 h-3.5" />
        </button>
      </div>

      {/* 3 Crisp Technical Columns */}
      <div className="flex-1 grid grid-cols-1 lg:grid-cols-12 divide-y lg:divide-y-0 lg:divide-x divide-black/[0.06] min-h-0">
        {/* Column 1: Container PTY Terminal & Human Takeover */}
        <div className="lg:col-span-4 p-3.5 flex flex-col gap-2 min-h-0">
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-[12px] font-bold text-[#1A1A1E]">
              <Terminal className="w-3.5 h-3.5 text-[#007AFF]" />
              容器终端 · 人工接管 ({seat.name})
            </span>

            <button
              type="button"
              onClick={() => onTogglePossess(seat.id, !seat.possessed)}
              className={`px-2.5 py-0.5 rounded-full text-[10.5px] font-bold transition-colors ${
                seat.possessed
                  ? 'bg-[#007AFF] text-white'
                  : 'bg-[#EBF3FF] text-[#007AFF] hover:bg-[#DCEBFE]'
              }`}
            >
              {seat.possessed ? '接管中 · 点击交还 AI' : '人工接管终端'}
            </button>
          </div>

          <div className="flex-1 p-2.5 rounded-xl bg-[#F6F7FA] border border-black/[0.05] font-mono text-[11px] overflow-y-auto space-y-1">
            {termEntries.map((entry) => (
              <div
                key={entry.id}
                className={`whitespace-pre-wrap break-all ${
                  entry.kind === 'cmd'
                    ? 'text-[#007AFF] font-semibold'
                    : entry.kind === 'stderr'
                      ? 'text-[#DC2E33]'
                      : entry.kind === 'hint'
                        ? 'text-[#D1800A] font-medium'
                        : 'text-[#1A1A1E]'
                }`}
              >
                {entry.text}
              </div>
            ))}
          </div>

          <div className="flex gap-1.5">
            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (!cmdInput.trim()) return;
                onSendTerminalCommand(seat.id, cmdInput);
                setCmdInput('');
              }}
              className="flex-1 flex items-center gap-1.5 px-2.5 py-1 rounded-xl bg-[#F4F4F7] border border-black/[0.06]"
            >
              <span className="font-mono text-[11px] font-bold text-[#007AFF]">$</span>
              <input
                value={cmdInput}
                onChange={(e) => setCmdInput(e.target.value)}
                placeholder="输入容器命令，如 cat /flag"
                className="flex-1 bg-transparent font-mono text-[11.5px] text-[#1A1A1E] focus:outline-none"
              />
              <button
                type="submit"
                className="px-2.5 py-0.5 rounded-full bg-[#007AFF] text-white text-[10.5px] font-bold"
              >
                执行
              </button>
            </form>

            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (!hintInput.trim()) return;
                onDropHint(seat.id, hintInput);
                setHintInput('');
              }}
              className="w-40 flex items-center gap-1 px-2 py-1 rounded-xl bg-[#FFFBEB] border border-[#F59E0B]/25"
            >
              <Lightbulb className="w-3 h-3 text-[#D1800A] shrink-0" />
              <input
                value={hintInput}
                onChange={(e) => setHintInput(e.target.value)}
                placeholder="发送战术提示…"
                className="w-full bg-transparent text-[11px] text-[#1A1A1E] focus:outline-none"
              />
              <button type="submit" className="text-[#D1800A]" title="发送提示">
                <Send className="w-3 h-3" />
              </button>
            </form>
          </div>
        </div>

        {/* Column 2: eBPF Syscall & OpenSSL Cleartext */}
        <div className="lg:col-span-4 p-3.5 flex flex-col gap-2 min-h-0">
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-[12px] font-bold text-[#1A1A1E]">
              <Cpu className="w-3.5 h-3.5 text-[#007AFF]" />
              eBPF 系统调用与 TLS 明文包
            </span>
            <div className="flex items-center gap-1 font-mono text-[10px]">
              {['ALL', 'exec', 'tcp', 'SSL'].map((f) => (
                <button
                  key={f}
                  type="button"
                  onClick={() => setProbeFilter(f)}
                  className={`px-2 py-0.5 rounded-full font-semibold ${
                    probeFilter === f
                      ? 'bg-[#007AFF] text-white'
                      : 'bg-[#F4F4F7] text-[#61626A]'
                  }`}
                >
                  {f}
                </button>
              ))}
            </div>
          </div>

          <div className="flex-1 overflow-y-auto space-y-1.5 pr-0.5">
            {filteredEvents.slice(0, 10).map((ev) => (
              <div
                key={ev.id}
                className="p-2.5 rounded-xl bg-[#F6F7FA] border border-black/[0.05] font-mono text-[10.5px] space-y-1"
              >
                <div className="flex items-center justify-between">
                  <span className="font-bold text-[#007AFF]">{ev.probe}</span>
                  <span className="text-[#6F7078]">
                    PID {ev.pid} · uid={ev.uid}
                    {ev.kernel_latency_ns
                      ? ` · ${(ev.kernel_latency_ns / 1000).toFixed(1)}µs`
                      : ''}
                  </span>
                </div>
                <div className="text-[#1A1A1E] truncate">{ev.cmdline}</div>
                {ev.cleartext_payload && (
                  <div className="p-1.5 rounded-lg bg-[#5856D6]/[0.07] text-[#5856D6] truncate">
                    {ev.cleartext_payload}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Column 3: Live Red/Green Git Diff */}
        <div className="lg:col-span-4 p-3.5 flex flex-col gap-2 min-h-0">
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-[12px] font-bold text-[#1A1A1E]">
              <FileDiff className="w-3.5 h-3.5 text-[#1C9457]" />
              Git Diff 实时源码热补丁
            </span>
            {activePatch?.file_path ? (
              <span className="font-mono text-[11px] font-semibold text-[#007AFF]">
                {activePatch.file_path}
              </span>
            ) : (
              <span className="font-mono text-[11px] text-[#8E8F97]">暂无补丁</span>
            )}
          </div>

          <div className="flex-1 p-2.5 rounded-xl bg-[#F6F7FA] border border-black/[0.05] font-mono text-[11px] overflow-y-auto space-y-0.5">
            {activePatch ? (
              activePatch.diff.split('\n').map((line, i) => {
                const isDel = line.startsWith('-') && !line.startsWith('---');
                const isAdd = line.startsWith('+') && !line.startsWith('+++');
                return (
                  <div
                    key={i}
                    className={`px-2 py-0.5 rounded whitespace-pre-wrap break-all ${
                      isDel
                        ? 'bg-[#DC2E33]/12 text-[#B91C1C] font-semibold'
                        : isAdd
                          ? 'bg-[#1C9457]/12 text-[#15803D] font-semibold'
                          : 'text-[#61626A]'
                    }`}
                  >
                    {line}
                  </div>
                );
              })
            ) : (
              <div className="text-[#6F7078] py-8 text-center">
                等待智能体提交首个 Git 源码热补丁…
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
