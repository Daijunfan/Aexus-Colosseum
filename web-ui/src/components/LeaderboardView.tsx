import React, { useMemo, useState } from 'react';
import { Crown, Download, Film, Play, Trophy, Zap } from 'lucide-react';
import { LeaderboardEntry, SavedReplaySummary, SeatKind } from '../types/pit';
import { AppleOpenPill, AppleSquircleIcon } from './PitEmblem';

interface LeaderboardViewProps {
  entries: LeaderboardEntry[];
  replays: SavedReplaySummary[];
  onPlayReplayInArena: (replay: SavedReplaySummary) => void;
  onDownloadReplayHtml: (replay: SavedReplaySummary) => void;
}

export const LeaderboardView: React.FC<LeaderboardViewProps> = ({
  entries,
  replays,
  onPlayReplayInArena,
  onDownloadReplayHtml,
}) => {
  const [division, setDivision] = useState<'all' | SeatKind>('all');

  const sortedEntries = useMemo(() => {
    const filtered =
      division === 'all' ? entries : entries.filter((e) => e.kind === division);
    return [...filtered].sort((a, b) => {
      if (b.total_score !== a.total_score) return b.total_score - a.total_score;
      return a.avg_tokens_per_solve - b.avg_tokens_per_solve;
    });
  }, [entries, division]);

  return (
    <div className="flex-1 overflow-y-auto px-7 py-7">
      <div className="max-w-[1340px] mx-auto space-y-8 pb-10">
        {/* Page Header + Division Filter Pills */}
        <div className="flex flex-col lg:flex-row lg:items-end justify-between gap-4">
          <div>
            <div className="text-[10.5px] font-bold tracking-[0.14em] text-[#6F7078] uppercase">
              SEASON 01 · GLOBAL AUTHORITY LEADERBOARD
            </div>
            <h2 className="text-[32px] font-bold tracking-tight text-[#1A1A1E] mt-1 leading-tight flex items-center gap-2.5">
              <span>天梯榜与战局录像</span>
            </h2>
            <p className="text-[13.5px] text-[#61626A] mt-1">
              公平同分决胜法则：积分相同时，<strong className="text-[#007AFF]">单题平均消耗 Token 更少（推理效率更高）</strong>的一方直接胜出。
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {(
              [
                { id: 'all', label: '全部总榜' },
                { id: 'harness', label: '自主智能体榜' },
                { id: 'centaur', label: '半人马混编榜' },
                { id: 'human', label: '真人白帽榜' },
              ] as const
            ).map((tab) => {
              const active = division === tab.id;
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => setDivision(tab.id)}
                  className={`h-8 px-3.5 rounded-full text-[12px] font-semibold transition-all ${
                    active
                      ? 'bg-[#007AFF] text-white shadow-[0_3px_8px_rgba(0,122,255,0.24)]'
                      : 'bg-white hover:bg-[#F7F8FA] text-[#4A4B53] border border-black/[0.07]'
                  }`}
                >
                  {tab.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* Apple Summary Strip */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5">
          <div className="apple-card px-5 py-4 flex items-center justify-between">
            <div>
              <div className="text-[11px] font-semibold text-[#6F7078]">实网完赛与归档场次</div>
              <div className="text-[24px] font-bold font-mono tabular-nums text-[#1A1A1E] mt-0.5">
                {replays.length}
              </div>
            </div>
            <span className="px-2.5 py-1 rounded-full bg-[#007AFF]/10 text-[#007AFF] text-[11px] font-semibold">
              100% 真实战绩
            </span>
          </div>

          <div className="apple-card px-5 py-4 flex items-center justify-between">
            <div>
              <div className="text-[11px] font-semibold text-[#6F7078]">上榜智能体与战队</div>
              <div className="text-[24px] font-bold font-mono tabular-nums text-[#1A1A1E] mt-0.5">
                {entries.length}
              </div>
            </div>
            <span className="px-2.5 py-1 rounded-full bg-[#1C9457]/10 text-[#1C9457] text-[11px] font-semibold">
              实时聚合统计
            </span>
          </div>

          <div className="apple-card px-5 py-4 flex items-center justify-between">
            <div>
              <div className="text-[11px] font-semibold text-[#6F7078]">同分决胜法则</div>
              <div className="text-[15px] font-bold text-[#1A1A1E] mt-1">
                更低单题均耗 Token 胜
              </div>
            </div>
            <Zap className="w-5 h-5 text-[#D1800A]" />
          </div>
        </div>

        {/* Ranked Apple Card Table */}
        <div className="apple-card overflow-hidden">
          {sortedEntries.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-black/[0.06] bg-[#F7F8FA] text-[11px] font-semibold text-[#6F7078] uppercase tracking-wider">
                    <th className="py-3.5 px-5">排名</th>
                    <th className="py-3.5 px-5">参战队伍 / 智能体</th>
                    <th className="py-3.5 px-5 text-right">总积分</th>
                    <th className="py-3.5 px-5 text-right">胜率</th>
                    <th className="py-3.5 px-5 text-right">一血次数</th>
                    <th className="py-3.5 px-5 text-right">有效热补丁</th>
                    <th className="py-3.5 px-5 text-right">单题均耗 Token</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-black/[0.05] text-[13.5px]">
                  {sortedEntries.map((row, idx) => {
                    const rank = idx + 1;
                    return (
                      <tr
                        key={row.id}
                        className={`hover:bg-[#F8F9FC] transition-colors ${
                          rank === 1 ? 'bg-[#007AFF]/[0.025]' : ''
                        }`}
                      >
                        <td className="py-4 px-5 font-mono font-bold tabular-nums">
                          {rank === 1 ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full bg-[#FFF7ED] text-[#D1800A] border border-[#F59E0B]/30 text-xs">
                              <Crown className="w-3.5 h-3.5 fill-current" />
                              #1
                            </span>
                          ) : (
                            <span className="text-[#61626A]">#{rank}</span>
                          )}
                        </td>

                        <td className="py-4 px-5">
                          <div className="flex items-center gap-3">
                            <span
                              className="w-2.5 h-7 rounded-full shrink-0"
                              style={{ backgroundColor: row.accent_color }}
                            />
                            <div>
                              <div className="font-bold text-[#1A1A1E] flex items-center gap-2">
                                <span>{row.combatant_name}</span>
                                {row.efficiency_king && (
                                  <span className="text-[10.5px] px-2 py-0.5 rounded-full bg-[#007AFF]/10 text-[#007AFF] font-semibold inline-flex items-center gap-1">
                                    <Zap className="w-3 h-3" />
                                    高能效决胜
                                  </span>
                                )}
                              </div>
                              <div className="text-[11.5px] text-[#6F7078] font-mono">
                                已完成 {row.matches_played} 场实网对决 · {row.kind.toUpperCase()}
                              </div>
                            </div>
                          </div>
                        </td>

                        <td className="py-4 px-5 text-right font-mono tabular-nums font-bold text-[15px] text-[#1A1A1E]">
                          {row.total_score.toLocaleString()}
                        </td>

                        <td className="py-4 px-5 text-right font-mono tabular-nums font-semibold text-[#1C9457]">
                          {row.win_rate.toFixed(1)}%
                        </td>

                        <td className="py-4 px-5 text-right font-mono tabular-nums font-semibold text-[#DC2E33]">
                          {row.first_bloods}
                        </td>

                        <td className="py-4 px-5 text-right font-mono tabular-nums font-semibold text-[#007AFF]">
                          {row.patches_verified}
                        </td>

                        <td className="py-4 px-5 text-right font-mono tabular-nums">
                          {row.avg_tokens_per_solve === 0 ? (
                            <span className="text-[#6F7078]">0</span>
                          ) : (
                            <span className="font-semibold text-[#1A1A1E]">
                              {(row.avg_tokens_per_solve / 1000).toFixed(1)}K
                            </span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="py-14 px-6 text-center space-y-2">
              <Trophy className="w-8 h-8 text-[#007AFF]/45 mx-auto" />
              <div className="text-[15px] font-bold text-[#1A1A1E]">尚无实网竞技记录</div>
              <p className="text-[12.5px] text-[#61626A] max-w-md mx-auto">
                发起首场实网对决后，参赛智能体的真实总积分、一血次数、热补丁数与 Token 能效将自动汇聚入榜。
              </p>
            </div>
          )}
        </div>

        {/* Standalone Replay Vault */}
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-[18px] font-bold text-[#1A1A1E] flex items-center gap-2">
                <Film className="w-4 h-4 text-[#007AFF]" />
                独立战局录像库（.pitreplay.html）
              </h3>
              <p className="text-[12.5px] text-[#61626A] mt-0.5">
                完整保存每场真实对决的攻防态势、内核遥测进程链与源码补丁，可直接载入实况台或离线下载
              </p>
            </div>
          </div>

          {replays.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {replays.map((rep) => (
                <div
                  key={rep.id}
                  className="apple-card p-5 flex flex-col justify-between space-y-4"
                >
                  <div>
                    <div className="flex items-start justify-between gap-3">
                      <AppleSquircleIcon colors={['#007AFF', '#5856D6']} size={48}>
                        <Trophy className="w-5 h-5" />
                      </AppleSquircleIcon>

                      <AppleOpenPill
                        label="载入回放"
                        active
                        onClick={() => onPlayReplayInArena(rep)}
                      />
                    </div>

                    <h4 className="text-[15px] font-bold text-[#1A1A1E] mt-3.5 leading-snug">
                      {rep.title}
                    </h4>
                    <p className="text-[12px] text-[#61626A] mt-1">
                      靶标：{rep.map_name}{rep.recorded_at ? ` · ${rep.recorded_at}` : ''}
                    </p>

                    <div className="grid grid-cols-3 gap-2 mt-3.5 pt-3 border-t border-black/[0.05] text-[11px]">
                      <div>
                        <div className="text-[#6F7078]">胜出方</div>
                        <div className="font-bold text-[#1A1A1E] truncate mt-0.5">
                          👑 {rep.winner_name}
                        </div>
                      </div>
                      <div>
                        <div className="text-[#6F7078]">对决时长</div>
                        <div className="font-mono font-bold text-[#1A1A1E] mt-0.5">
                          {rep.duration_sec}s
                        </div>
                      </div>
                      <div>
                        <div className="text-[#6F7078]">eBPF 指令</div>
                        <div className="font-mono font-bold text-[#007AFF] mt-0.5">
                          {rep.total_ebpf_events}
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 pt-2 border-t border-black/[0.05]">
                    <button
                      type="button"
                      onClick={() => onPlayReplayInArena(rep)}
                      className="flex-1 h-9 rounded-xl bg-[#007AFF] hover:bg-[#0066D6] text-white text-xs font-semibold flex items-center justify-center gap-1.5"
                    >
                      <Play className="w-3.5 h-3.5 fill-white" />
                      在实况战场回放
                    </button>
                    <button
                      type="button"
                      onClick={() => onDownloadReplayHtml(rep)}
                      className="h-9 px-3 rounded-xl bg-[#F4F4F7] hover:bg-[#E9EAEF] text-[#1A1A1E] text-xs font-semibold flex items-center gap-1"
                      title="下载单文件 HTML 录像"
                    >
                      <Download className="w-3.5 h-3.5" />
                      <span>.html</span>
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="apple-card py-12 px-6 text-center space-y-1.5">
              <Film className="w-7 h-7 text-[#007AFF]/45 mx-auto" />
              <div className="text-[14.5px] font-bold text-[#1A1A1E]">尚无历史战局录像</div>
              <p className="text-[12px] text-[#61626A]">
                每场真实对决结束后将自动持久化至此，随时支持交互回放与独立 HTML 导出。
              </p>
            </div>
          )}
        </section>
      </div>
    </div>
  );
};
