import React from 'react';
import { Camera, Share, Sliders, Terminal, Volume2 } from 'lucide-react';
import { MatchState } from '../types/pit';

interface BottomCasterBarProps {
  match: MatchState;
  focusedSeatName: string;
  onOpenInspector: () => void;
  onOpenLobby: () => void;
  onOpenPoster: () => void;
  onExportReplay: () => void;
}

export const BottomCasterBar: React.FC<BottomCasterBarProps> = ({
  match,
  focusedSeatName,
  onOpenInspector,
  onOpenLobby,
  onOpenPoster,
  onExportReplay,
}) => {
  const latest = match.caster_lines[0] ?? {
    id: 'default',
    ts_ms: Date.now(),
    mood: 'HYPE' as const,
    text: '欢迎来到 Aexus Colosseum —— 全席位宿主机 eBPF 实网攻防正在实时推进！',
  };

  return (
    <footer className="apple-card px-4 py-2.5 flex items-center justify-between gap-4 select-none shrink-0">
      {/* Left: Live AI Caster Voice Line */}
      <div className="flex items-center gap-2.5 min-w-0 flex-1">
        <span className="px-2.5 py-1 rounded-full bg-[#007AFF]/10 text-[#007AFF] text-[11px] font-bold flex items-center gap-1 shrink-0">
          <Volume2 className="w-3.5 h-3.5" />
          AI 实时解说
        </span>

        <p className="text-[12.5px] font-medium text-[#1A1A1E] truncate" title={latest.text}>
          {latest.text}
        </p>
      </div>

      {/* Right: Self-Explanatory Human Intervention & Share Actions */}
      <div className="flex items-center gap-2 shrink-0">
        <button
          type="button"
          onClick={onOpenInspector}
          className="h-8 px-3 rounded-full bg-[#F4F4F7] hover:bg-[#EAEBEF] text-[12px] font-semibold text-[#1A1A1E] flex items-center gap-1.5 transition-colors"
        >
          <Terminal className="w-3.5 h-3.5 text-[#61626A]" />
          <span className="hidden md:inline">接管终端 ({focusedSeatName})</span>
        </button>

        <button
          type="button"
          onClick={onOpenLobby}
          className="h-8 px-3 rounded-full bg-[#F4F4F7] hover:bg-[#EAEBEF] text-[12px] font-semibold text-[#1A1A1E] flex items-center gap-1.5 transition-colors"
        >
          <Sliders className="w-3.5 h-3.5 text-[#61626A]" />
          <span className="hidden lg:inline">重配席位</span>
        </button>

        <button
          type="button"
          onClick={onOpenPoster}
          className="h-8 px-3 rounded-full bg-[#FFF7ED] hover:bg-[#FFEDD5] border border-[#F59E0B]/25 text-[12px] font-semibold text-[#D1800A] flex items-center gap-1.5 transition-colors"
        >
          <Camera className="w-3.5 h-3.5" />
          <span className="hidden sm:inline">生成战报图</span>
        </button>

        <button
          type="button"
          onClick={onExportReplay}
          className="h-8 px-3.5 rounded-full bg-[#007AFF] hover:bg-[#0066D6] shadow-[0_3px_10px_rgba(0,122,255,0.24)] text-[12px] font-semibold text-white flex items-center gap-1.5 transition-all"
        >
          <Share className="w-3.5 h-3.5" />
          <span>导出独立录像 (.html)</span>
        </button>
      </div>
    </footer>
  );
};
