import React, { useState } from 'react';
import { Code2, Cpu, Database, DoorOpen, Heart, Share2, Sparkles } from 'lucide-react';
import { WEAPON_META, classifyEventArchetype } from '../engine/vfxEngine';
import { MatchState, OrganLayer } from '../types/pit';

interface OrganAnatomyViewProps {
  match: MatchState;
}

function organIcon(layer: OrganLayer) {
  switch (layer) {
    case 'port_gate':
      return <DoorOpen className="w-4 h-4" />;
    case 'route_vessel':
      return <Share2 className="w-4 h-4" />;
    case 'code_organ':
      return <Code2 className="w-4 h-4" />;
    case 'db_vault':
      return <Database className="w-4 h-4" />;
    default:
      return <Heart className="w-4 h-4" />;
  }
}

export const OrganAnatomyView: React.FC<OrganAnatomyViewProps> = ({ match }) => {
  const [selectedTargetIdx, setSelectedTargetIdx] = useState(0);
  const [selectedOrgan, setSelectedOrgan] = useState<OrganLayer | null>(null);

  const target = match.targets[selectedTargetIdx] ?? match.targets[0];
  if (!target) return null;

  return (
    <div className="w-full h-full grid grid-cols-1 lg:grid-cols-12 gap-3.5 min-h-0 overflow-y-auto">
      {/* Left 7 Cols: 5-Layer Target Breakdown */}
      <div className="lg:col-span-7 apple-card p-5 flex flex-col justify-between">
        <div>
          <div className="flex flex-wrap items-center justify-between gap-2 mb-4">
            <div>
              <h3 className="text-[16px] font-bold text-[#1A1A1E]">靶机内部五层受创与修补状态</h3>
              <p className="text-[12px] text-[#61626A] mt-0.5">
                目标实例：{target.name}（{target.ip}）
              </p>
            </div>

            <div className="flex items-center gap-2">
              {match.targets.length > 1 &&
                match.targets.map((t, i) => (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => setSelectedTargetIdx(i)}
                    className={`px-2.5 py-1 rounded-full text-[11px] font-semibold ${
                      i === selectedTargetIdx
                        ? 'bg-[#007AFF] text-white'
                        : 'bg-[#F4F4F7] text-[#61626A]'
                    }`}
                  >
                    {t.name}
                  </button>
                ))}

              <span
                className={`px-2.5 py-1 rounded-full text-[11px] font-bold ${
                  target.sla_healthy
                    ? 'bg-[#1C9457]/12 text-[#1C9457]'
                    : 'bg-[#DC2E33]/12 text-[#DC2E33]'
                }`}
              >
                SLA 业务{target.sla_healthy ? `正常 ${target.sla_score}%` : '受损'}
              </span>
            </div>
          </div>

          <div className="relative space-y-2.5 pl-4">
            {/* Vertical 5-Layer Penetration Conduit */}
            <div className="absolute left-1.5 top-5 bottom-5 w-0.5 rounded-full bg-gradient-to-b from-[#0284C7]/45 via-[#9333EA]/45 to-[#DC2E33]/55" />
            {target.organs.map((organ, idx) => {
              const isCompromised = organ.state === 'compromised';
              const isPatched = organ.state === 'patched';
              const isProbing = organ.state === 'probing';
              const isSelected = selectedOrgan === organ.layer;
              const recentHit = match.events.find(
                (ev) => ev.organ_layer === organ.layer && Date.now() - ev.ts_ms < 6000
              );
              const hitWeapon = recentHit ? WEAPON_META[classifyEventArchetype(recentHit)] : null;

              const statusColor = isCompromised
                ? '#DC2E33'
                : isPatched
                  ? '#007AFF'
                  : isProbing
                    ? '#D1800A'
                    : '#1C9457';

              const statusLabel = isCompromised
                ? `已被突破${organ.compromised_by ? ` (${organ.compromised_by})` : ''}`
                : isPatched
                  ? `热补丁已加固`
                  : isProbing
                    ? '高频探测中'
                    : '防线稳固';

              const barPct = isCompromised ? 36 : isPatched ? 88 : isProbing ? 62 : 95;

              return (
                <div
                  key={organ.layer}
                  role="button"
                  tabIndex={0}
                  onClick={() => setSelectedOrgan(organ.layer)}
                  className={`relative rounded-2xl p-3.5 border transition-all flex items-center gap-3.5 ${
                    isSelected ? 'ring-1 ring-[#007AFF]/40 bg-white' : 'bg-[#F8F9FC] hover:bg-white'
                  } ${hitWeapon ? 'shadow-[0_6px_18px_rgba(0,122,255,0.12)]' : ''}`}
                  style={{
                    borderColor: isCompromised
                      ? 'rgba(220,46,51,0.32)'
                      : isPatched
                        ? 'rgba(0,122,255,0.28)'
                        : 'rgba(0,0,0,0.06)',
                  }}
                >
                  {/* Conduit Node Dot */}
                  <span
                    className={`absolute -left-[13px] top-1/2 -translate-y-1/2 w-2.5 h-2.5 rounded-full ring-2 ring-white ${
                      hitWeapon ? 'animate-ping' : ''
                    }`}
                    style={{ backgroundColor: hitWeapon?.color ?? statusColor }}
                  />
                  <span
                    className="absolute -left-[13px] top-1/2 -translate-y-1/2 w-2.5 h-2.5 rounded-full ring-2 ring-white"
                    style={{ backgroundColor: hitWeapon?.color ?? statusColor }}
                  />

                  <div
                    className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: `${statusColor}18`,
                      color: statusColor,
                    }}
                  >
                    {organIcon(organ.layer)}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-2 min-w-0">
                        <span className="text-[13.5px] font-bold text-[#1A1A1E]">
                          0{idx + 1} · {organ.label_zh}
                        </span>
                        <span className="text-[11px] text-[#6F7078] truncate">
                          {organ.label_en}
                        </span>
                      </div>

                      <div className="flex items-center gap-1.5 shrink-0">
                        {hitWeapon && (
                          <span
                            className="px-2 py-0.5 rounded-full text-[10px] font-bold flex items-center gap-1"
                            style={{
                              backgroundColor: `${hitWeapon.color}16`,
                              color: hitWeapon.color,
                            }}
                          >
                            <Sparkles className="w-2.5 h-2.5" />
                            {hitWeapon.tag} · {hitWeapon.zhLabel}
                          </span>
                        )}
                        <span
                          className="px-2.5 py-0.5 rounded-full text-[10.5px] font-bold"
                          style={{
                            backgroundColor: `${statusColor}16`,
                            color: statusColor,
                          }}
                        >
                          {statusLabel}
                        </span>
                      </div>
                    </div>

                    <div className="text-[11.5px] text-[#61626A] truncate mt-0.5">
                      {organ.service}
                      {organ.hit_location ? ` · 定位 ${organ.hit_location}` : ''}
                    </div>

                    <div className="mt-2 h-1 rounded-full bg-black/[0.06] overflow-hidden">
                      <div
                        className="h-full rounded-full transition-all duration-300"
                        style={{ width: `${barPct}%`, backgroundColor: statusColor }}
                      />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Right 5 Cols: Real Linux execve Process Tree + Xcode-Light Code Diff */}
      <div className="lg:col-span-5 flex flex-col gap-3.5">
        <div className="apple-card p-5 flex-1 flex flex-col">
          <div className="flex items-center justify-between mb-3">
            <span className="flex items-center gap-2 text-[14px] font-bold text-[#1A1A1E]">
              <Cpu className="w-4 h-4 text-[#007AFF]" />
              Linux execve 实时进程派生链
            </span>
            <span className="text-[11px] font-mono text-[#6F7078]">内核态捕获</span>
          </div>

          <div className="flex-1 space-y-1.5 font-mono text-[11.5px]">
            {target.active_process_tree.length > 0 ? (
              target.active_process_tree.map((proc, idx) => {
                const isEvil =
                  proc.includes('/bin/sh') ||
                  proc.includes('bash') ||
                  proc.includes('suid') ||
                  proc.includes('uid=0') ||
                  proc.includes('⚠️');
                return (
                  <div
                    key={`${idx}-${proc}`}
                    style={{ marginLeft: `${idx * 14}px` }}
                    className={`px-3 py-1.5 rounded-xl truncate ${
                      isEvil
                        ? 'bg-[#DC2E33]/10 text-[#DC2E33] font-semibold border border-[#DC2E33]/25'
                        : 'bg-[#F6F7FA] text-[#1A1A1E]'
                    }`}
                  >
                    {idx === 0 ? '• ' : '└─ '}
                    {proc}
                  </div>
                );
              })
            ) : (
              <div className="h-full flex items-center justify-center text-center px-3 py-6 text-[#6F7078] font-sans text-[12px]">
                尚未在靶机容器内捕获到子进程派生链，当触发 RCE 或命令执行时将实时展示
              </div>
            )}
          </div>
        </div>

        <div className="apple-card p-5 flex-1 flex flex-col">
          <div className="flex items-center justify-between mb-3">
            <span className="flex items-center gap-2 text-[14px] font-bold text-[#1A1A1E]">
              <Code2 className="w-4 h-4 text-[#007AFF]" />
              {target.last_diff ? '实时源码热补丁 (Git Unified Diff)' : '容器真实业务源码定位'}
            </span>
            {target.vulnerable_file && (
              <span className="text-[11.5px] font-mono font-semibold text-[#007AFF]">
                {target.vulnerable_file}
                {target.vulnerable_line > 0 ? `:${target.vulnerable_line}` : ''}
              </span>
            )}
          </div>

          <div className="flex-1 rounded-2xl bg-[#F6F7FA] border border-black/[0.05] p-3 font-mono text-[11.5px] space-y-1 overflow-x-auto overflow-y-auto max-h-64">
            {target.last_diff ? (
              target.last_diff.split('\n').map((line, idx) => {
                const isDel = line.startsWith('-') && !line.startsWith('---');
                const isAdd = line.startsWith('+') && !line.startsWith('+++');
                return (
                  <div
                    key={idx}
                    className={`px-2.5 py-0.5 rounded whitespace-pre-wrap break-all ${
                      isDel
                        ? 'bg-[#DC2E33]/12 text-[#B91C1C] font-semibold'
                        : isAdd
                          ? 'bg-[#1C9457]/12 text-[#15803D] font-semibold'
                          : 'text-[#2C2D33]'
                    }`}
                  >
                    {line}
                  </div>
                );
              })
            ) : target.code_snippet.length > 0 ? (
              target.code_snippet.map((row) => (
                <div
                  key={row.line}
                  className={`px-2.5 py-0.5 rounded-lg flex items-start gap-3 ${
                    row.is_vuln
                      ? 'bg-[#DC2E33]/12 text-[#B91C1C] font-semibold'
                      : row.is_patched
                        ? 'bg-[#1C9457]/12 text-[#15803D] font-semibold'
                        : 'text-[#2C2D33]'
                  }`}
                >
                  <span className="w-8 shrink-0 text-[#6F7078] select-none tabular-nums">
                    {row.line}
                  </span>
                  <pre className="whitespace-pre-wrap break-all">{row.code}</pre>
                </div>
              ))
            ) : (
              <div className="h-full flex items-center justify-center text-center px-3 py-6 text-[#6F7078] font-sans text-[12px]">
                等待从靶机容器读取源码片段或热补丁变更…
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
