import React, { useEffect, useRef } from 'react';
import { Download, Sparkles, X } from 'lucide-react';
import { formatTokenCompact } from '../data/armoryCatalog';
import { MatchState } from '../types/pit';

interface PosterModalProps {
  open: boolean;
  match: MatchState;
  ebpfEventsCount?: number;
  onClose: () => void;
}

export const PosterModal: React.FC<PosterModalProps> = ({
  open,
  match,
  ebpfEventsCount,
  onClose,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    if (!open) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const W = 1600;
    const H = 900;
    canvas.width = W;
    canvas.height = H;

    // 1. Clean Apple Keynote Daylight Backdrop
    const bg = ctx.createLinearGradient(0, 0, W, H);
    bg.addColorStop(0, '#FFFFFF');
    bg.addColorStop(0.55, '#F5F6FA');
    bg.addColorStop(1, '#EEF2F8');
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, W, H);

    // Subtle concentric watermark on right
    const rCx = W * 0.8;
    const rCy = H * 0.52;
    [330, 250, 170, 90].forEach((r, i) => {
      ctx.beginPath();
      ctx.arc(rCx, rCy, r, 0, Math.PI * 2);
      ctx.strokeStyle = i === 0 ? 'rgba(0, 122, 255, 0.14)' : 'rgba(0, 0, 0, 0.045)';
      ctx.lineWidth = 2;
      ctx.stroke();
    });

    // 2. Top Brand Header
    ctx.fillStyle = '#007AFF';
    ctx.font = '700 17px -apple-system, "SF Pro Display", sans-serif';
    ctx.fillText('AEXUS COLOSSEUM  ·  OFFICIAL MATCH REPORT', 72, 84);

    ctx.fillStyle = '#1A1A1E';
    ctx.font = '800 44px -apple-system, "PingFang SC", sans-serif';
    ctx.fillText(match.title, 72, 144);

    ctx.fillStyle = '#61626A';
    ctx.font = '500 20px -apple-system, "PingFang SC", sans-serif';
    ctx.fillText(
      `模式：${match.mode.toUpperCase()}   ·   靶标：${match.map_name}   ·   单席预算：${formatTokenCompact(
        match.token_budget
      )} Tokens`,
      72,
      184
    );

    const ranked = [...match.seats].sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      return a.tokens_used - b.tokens_used;
    });
    const winner = ranked[0];

    // 3. Champion Card
    if (winner) {
      ctx.fillStyle = '#FFFFFF';
      ctx.strokeStyle = 'rgba(0, 122, 255, 0.35)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.roundRect(72, 218, 920, 130, 24);
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = '#007AFF';
      ctx.font = '700 15px -apple-system, sans-serif';
      ctx.fillText('👑 当前领先 / 冠军席位', 102, 254);

      ctx.fillStyle = '#1A1A1E';
      ctx.font = '800 36px -apple-system, "PingFang SC", sans-serif';
      ctx.fillText(`${winner.name}  ×  ${winner.model}`, 102, 300);

      ctx.fillStyle = '#61626A';
      ctx.font = '600 17px "SF Mono", "JetBrains Mono", monospace';
      ctx.fillText(
        `得分 ${winner.score.toLocaleString()}   ·   剩余额度 ${winner.mana_remaining_pct.toFixed(
          1
        )}%   ·   夺旗 ${winner.flags_captured}   ·   补丁 ${winner.patches_verified}`,
        102,
        332
      );
    }

    // 4. Standings Rows
    let rowY = 378;
    ranked.slice(0, 6).forEach((s, idx) => {
      ctx.fillStyle = '#FFFFFF';
      ctx.strokeStyle = 'rgba(0, 0, 0, 0.07)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.roundRect(72, rowY, 920, 64, 18);
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = idx === 0 ? '#007AFF' : '#61626A';
      ctx.font = '700 21px "SF Mono", monospace';
      ctx.fillText(`#${idx + 1}`, 100, rowY + 40);

      ctx.fillStyle = '#1A1A1E';
      ctx.font = '700 21px -apple-system, "PingFang SC", sans-serif';
      ctx.fillText(s.name, 162, rowY + 40);

      ctx.fillStyle = '#61626A';
      ctx.font = '500 16px "SF Mono", monospace';
      ctx.fillText(s.model, 390, rowY + 40);

      ctx.fillStyle = s.out_of_mana ? '#DC2E33' : '#007AFF';
      ctx.font = '600 16px "SF Mono", monospace';
      ctx.fillText(
        s.out_of_mana ? 'HTTP 402 耗尽' : `剩余 ${s.mana_remaining_pct.toFixed(0)}%`,
        650,
        rowY + 40
      );

      ctx.fillStyle = '#1A1A1E';
      ctx.font = '800 23px "SF Mono", monospace';
      ctx.textAlign = 'right';
      ctx.fillText(`${s.score.toLocaleString()} 分`, 964, rowY + 40);
      ctx.textAlign = 'left';

      rowY += 74;
    });

    // 5. Right Side Kernel Telemetry Card
    ctx.fillStyle = '#FFFFFF';
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.08)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.roundRect(1028, 218, 500, 600, 24);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = '#007AFF';
    ctx.font = '700 18px -apple-system, "PingFang SC", sans-serif';
    ctx.fillText('Linux eBPF 宿主机内核遥测摘要', 1060, 262);

    const totalTokensUsed = match.seats.reduce((sum, s) => sum + (s.tokens_used || 0), 0);
    const totalFlags = match.seats.reduce((sum, s) => sum + (s.flags_captured || 0), 0);
    const totalPatches = Math.max(
      match.patches.length,
      match.seats.reduce((sum, s) => sum + (s.patches_verified || 0), 0)
    );
    const liveEbpfCount = Math.max(ebpfEventsCount ?? 0, match.events.length);
    const stats = [
      ['对决耗时 / 累计夺旗', `${Math.round(match.elapsed_sec)}s  ·  ${totalFlags} 次夺旗`],
      ['捕获底层指令数', `${liveEbpfCount.toLocaleString()} 条`],
      ['通过巡检热补丁', `${totalPatches} 次提交`],
      ['本场总消耗算力', `${formatTokenCompact(totalTokensUsed)} Tokens`],
      [
        '首杀 / 同分决胜规则',
        match.first_blood_sec ? `一血 ${match.first_blood_sec.toFixed(1)}s` : '同分消耗更少 Token 胜',
      ],
    ];
    stats.forEach(([k, v], i) => {
      const sy = 314 + i * 92;
      ctx.fillStyle = '#6F7078';
      ctx.font = '600 14px -apple-system, "PingFang SC", sans-serif';
      ctx.fillText(k, 1060, sy);
      ctx.fillStyle = '#1A1A1E';
      ctx.font = '800 24px -apple-system, "PingFang SC", sans-serif';
      ctx.fillText(v, 1060, sy + 32);
    });

    ctx.fillStyle = '#6F7078';
    ctx.font = '500 15px -apple-system, sans-serif';
    ctx.fillText(
      'Aexus Colosseum  ·  Zero-Intrusion Linux eBPF + Forced LLM Token Metering Gateway',
      72,
      858
    );
  }, [open, match]);

  if (!open) return null;

  const handleDownload = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const url = canvas.toDataURL('image/png');
    const a = document.createElement('a');
    a.href = url;
    a.download = `aexus-colosseum-report-${match.id}.png`;
    a.click();
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/35 backdrop-blur-md flex items-center justify-center p-4">
      <div className="max-w-5xl w-full rounded-[24px] bg-white border border-black/[0.08] shadow-[0_24px_60px_rgba(0,0,0,0.18)] overflow-hidden flex flex-col">
        <div className="px-6 py-4 border-b border-black/[0.06] flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Sparkles className="w-4 h-4 text-[#007AFF]" />
            <span className="font-bold text-[14.5px] text-[#1A1A1E]">
              高清战报卡片生成器（1600 × 900 PNG）
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handleDownload}
              className="h-8 px-4 rounded-full bg-[#007AFF] hover:bg-[#0066D6] text-xs font-semibold text-white flex items-center gap-1.5"
            >
              <Download className="w-3.5 h-3.5" />
              下载高清 PNG
            </button>
            <button
              type="button"
              onClick={onClose}
              className="w-8 h-8 rounded-full bg-[#F4F4F7] hover:bg-[#E8E9EF] text-[#61626A] flex items-center justify-center"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        <div className="p-5 bg-[#F4F4F7] flex items-center justify-center">
          <canvas
            ref={canvasRef}
            className="w-full max-h-[72vh] object-contain rounded-2xl border border-black/[0.08] shadow-md bg-white"
          />
        </div>
      </div>
    </div>
  );
};
