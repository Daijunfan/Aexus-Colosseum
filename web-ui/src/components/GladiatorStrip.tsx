import React, { useMemo } from 'react';
import { AlertCircle, Crown } from 'lucide-react';
import { formatTokenCompact } from '../data/armoryCatalog';
import { SeatState } from '../types/pit';
import { EcgCanvas } from './EcgCanvas';

interface GladiatorStripProps {
  seats: SeatState[];
  focusedSeatId: string;
  firstBloodSeatId?: string | null;
  onSelectSeat: (seatId: string) => void;
  onOpenPossessTerminal: (seatId: string) => void;
}

export const GladiatorStrip: React.FC<GladiatorStripProps> = ({
  seats,
  focusedSeatId,
  onSelectSeat,
}) => {
  // Canonical Rank Sort: Score DESC -> Fewer Tokens Used ASC
  const rankedSeats = useMemo(() => {
    return [...seats].sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      return a.tokens_used - b.tokens_used;
    });
  }, [seats]);

  return (
    <section
      className="grid gap-2.5 shrink-0"
      style={{
        gridTemplateColumns: `repeat(${Math.max(2, Math.min(rankedSeats.length, 5))}, minmax(0, 1fr))`,
      }}
    >
      {rankedSeats.slice(0, 5).map((seat, idx) => {
        const rank = idx + 1;
        const isFocused = seat.id === focusedSeatId;
        const hasAlert = !seat.sla_healthy || seat.out_of_mana;

        return (
          <div
            key={seat.id}
            role="button"
            tabIndex={0}
            onClick={() => onSelectSeat(seat.id)}
            className={`rounded-2xl bg-white p-3 transition-all select-none border ${
              hasAlert
                ? 'border-[#DC2E33]/45 shadow-[0_4px_14px_rgba(220,46,51,0.08)]'
                : isFocused
                  ? 'border-[#007AFF]/65 ring-1 ring-[#007AFF]/25 shadow-[0_6px_16px_rgba(0,122,255,0.10)]'
                  : 'border-black/[0.065] shadow-[0_4px_12px_rgba(0,0,0,0.038)] hover:border-black/[0.13]'
            }`}
          >
            {/* Row 1: Rank Pill + Name + Score */}
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-1.5 min-w-0">
                <span
                  className={`px-1.5 py-0.5 rounded-full text-[10.5px] font-bold font-mono shrink-0 ${
                    rank === 1
                      ? 'bg-[#007AFF] text-white'
                      : 'bg-black/[0.06] text-[#61626A]'
                  }`}
                >
                  #{rank}
                </span>
                <span className="font-bold text-[13px] text-[#1A1A1E] truncate">
                  {seat.name}
                </span>
                <span className="hidden xl:inline font-mono text-[9.5px] px-1.5 py-0.5 rounded-md bg-black/[0.045] text-[#61626A] truncate max-w-[96px]">
                  {seat.model}
                </span>
                {seat.is_grail_king && (
                  <Crown className="w-3.5 h-3.5 text-[#D1800A] fill-[#D1800A] shrink-0" />
                )}
              </div>

              <span className="font-mono tabular-nums font-bold text-[15px] text-[#1A1A1E] shrink-0">
                {seat.score.toLocaleString()}
              </span>
            </div>

            {/* Row 2: Live SLA ECG Line + Real Capture & Patch Micro-Pills */}
            <div className="mt-1.5 flex items-center gap-2">
              <div className="flex-1 min-w-0">
                <EcgCanvas healthy={seat.sla_healthy} phaseOffset={idx} height={18} />
              </div>
              <div className="flex items-center gap-1 shrink-0 font-mono text-[10px]">
                <span className="px-1.5 py-0.5 rounded-full bg-[#FFF7ED] text-[#D97706] font-semibold tabular-nums">
                  🚩 {seat.flags_captured}
                </span>
                <span className="px-1.5 py-0.5 rounded-full bg-[#007AFF]/10 text-[#007AFF] font-semibold tabular-nums">
                  🛡️ {seat.patches_verified}
                </span>
                <span
                  className={`font-bold pl-0.5 ${
                    seat.sla_healthy ? 'text-[#1C9457]' : 'text-[#DC2E33]'
                  }`}
                >
                  {seat.sla_healthy ? `SLA ${seat.sla_score.toFixed(0)}%` : 'FLATLINE'}
                </span>
              </div>
            </div>

            {/* Row 3: Fixed Token Quota Bar or HTTP 402 Pill */}
            <div className="mt-1.5">
              {seat.out_of_mana ? (
                <div className="h-5 px-2 rounded-full bg-[#DC2E33] text-white text-[10px] font-bold flex items-center justify-center">
                  HTTP 402 · Token 额度耗尽停机
                </div>
              ) : (
                <>
                  <div className="h-1.5 w-full rounded-full bg-black/[0.06] overflow-hidden">
                    <div
                      className={`h-full rounded-full transition-all duration-300 ${
                        seat.mana_remaining_pct < 25 ? 'bg-[#D97706]' : 'bg-[#007AFF]'
                      }`}
                      style={{ width: `${Math.max(4, seat.mana_remaining_pct)}%` }}
                    />
                  </div>
                  <div className="flex items-center justify-between text-[10px] font-mono mt-1">
                    <span
                      className={`font-semibold ${
                        seat.mana_remaining_pct < 25 ? 'text-[#D97706]' : 'text-[#007AFF]'
                      }`}
                    >
                      剩余 {seat.mana_remaining_pct.toFixed(0)}%
                    </span>
                    <span className="text-[#6F7078] tabular-nums">
                      {formatTokenCompact(seat.tokens_used)} /{' '}
                      {formatTokenCompact(seat.token_budget)}
                    </span>
                  </div>
                </>
              )}
            </div>

            {/* Row 4: Live Thought Line */}
            <div className="mt-1.5 pt-1.5 border-t border-black/[0.05] flex items-center gap-1 text-[11px] text-[#61626A]">
              {hasAlert && <AlertCircle className="w-3 h-3 text-[#DC2E33] shrink-0" />}
              <span className="truncate" title={seat.thought || '等待首轮推理指令…'}>
                {seat.thought || '等待首轮推理指令…'}
              </span>
            </div>
          </div>
        );
      })}
    </section>
  );
};
