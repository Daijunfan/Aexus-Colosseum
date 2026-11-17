import React, { useEffect, useState } from 'react';
import { AlertTriangle, Crown, Lock, MousePointer2, ShieldCheck } from 'lucide-react';
import { MatchState } from '../types/pit';

interface WebHijackViewProps {
  match: MatchState;
}

export const WebHijackView: React.FC<WebHijackViewProps> = ({ match }) => {
  const [animTick, setAnimTick] = useState(0);
  const isRunning = match.status === 'running';

  useEffect(() => {
    if (!isRunning) return;
    const id = window.setInterval(() => setAnimTick((t) => t + 1), 90);
    return () => window.clearInterval(id);
  }, [isRunning]);

  const latestHijack = match.web_hijacks[0];
  const deface = match.web_hijacks.find((h) => h.deface_banner);
  const target = match.targets[0];

  const rawPayload =
    latestHijack?.injected_input ||
    match.events[0]?.cleartext_payload ||
    match.events[0]?.cmdline ||
    '';
  const typedChars = !rawPayload
    ? 0
    : !isRunning
      ? rawPayload.length
      : Math.min(rawPayload.length, (animTick * 3) % (rawPayload.length + 26));
  const visiblePayload = rawPayload ? rawPayload.slice(0, typedChars) : '';

  const targetUrlDisplay =
    latestHijack?.target_url ||
    (target?.ip ? `http://${target.ip}:${target.ports[0] ?? 8080}` : '等待容器网络就绪');

  // Deduplicate actual reported hijack cursors per attacker seat
  const realCursors = match.web_hijacks.filter(
    (wh, idx, arr) => arr.findIndex((x) => x.attacker_seat_id === wh.attacker_seat_id) === idx
  );

  return (
    <div className="w-full h-full grid grid-cols-1 lg:grid-cols-12 gap-3.5 min-h-0 select-none">
      {/* Left 8 Cols: Safari-Framed Live Target Web Surface */}
      <div className="lg:col-span-8 apple-card overflow-hidden flex flex-col relative min-h-0">
        {/* Clean Safari Light Window Chrome */}
        <div className="h-11 px-4 bg-[#F5F6FA] border-b border-black/[0.06] flex items-center justify-between gap-3 shrink-0">
          <div className="flex items-center gap-2">
            <span className="w-3 h-3 rounded-full bg-[#FF5F57]" />
            <span className="w-3 h-3 rounded-full bg-[#FEBC2E]" />
            <span className="w-3 h-3 rounded-full bg-[#28C840]" />
          </div>

          <div className="flex-1 max-w-xl h-7 px-3 rounded-lg bg-white border border-black/[0.07] flex items-center justify-between gap-2 text-[11.5px] font-mono">
            <span className="flex items-center gap-1.5 text-[#1A1A1E] truncate">
              <Lock className="w-3 h-3 text-[#D1800A] shrink-0" />
              <span className="truncate">{targetUrlDisplay}</span>
            </span>
            <span className="text-[10.5px] font-sans font-semibold text-[#007AFF] shrink-0">
              {latestHijack ? 'Web Telemetry 实时捕获' : '等待 HTTP 注入样本'}
            </span>
          </div>

          <div className="w-12" />
        </div>

        {/* Real Target Business Service Status & Payload View */}
        <div className="relative flex-1 p-6 overflow-y-auto space-y-5 bg-white">
          {deface?.deface_banner && (
            <div className="px-4 py-2.5 rounded-xl bg-[#FEF2F2] border border-[#DC2E33]/25 flex items-center gap-2 text-[#DC2E33] text-[12.5px] font-bold">
              <Crown className="w-4 h-4 shrink-0" />
              <span>{deface.deface_banner}</span>
            </div>
          )}

          <div>
            <h3 className="text-[21px] font-bold text-[#1A1A1E]">
              {target?.name || match.map_name}
            </h3>
            <p className="text-[12.5px] text-[#61626A] mt-0.5">
              靶机真实业务入口遥测 · 仅展示宿主机内核 uprobe 与引擎捕获到的真实请求载荷
            </p>
          </div>

          <div className="space-y-1.5">
            <label className="block text-[11.5px] font-semibold text-[#61626A]">
              最近捕获的请求 / 注入载荷 (Captured Request / Payload)
            </label>
            <div className="p-3.5 rounded-xl bg-[#FFF8F8] border border-[#DC2E33]/25 font-mono text-[12.5px] text-[#B91C1C] min-h-[60px] flex items-center">
              {visiblePayload ? (
                <div>
                  <span className="break-all">{visiblePayload}</span>
                  {isRunning && (
                    <span className="inline-block w-1.5 h-4 bg-[#DC2E33] ml-0.5 align-middle animate-pulse" />
                  )}
                </div>
              ) : (
                <span className="text-[#8E8F97] font-sans text-[12px]">
                  尚未捕获到面向目标 Web 服务的请求载荷，启动容器攻击链后将在此实时显示。
                </span>
              )}
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="block text-[11.5px] font-semibold text-[#61626A]">
              靶机业务健康与响应遥测 (Server Health &amp; DOM Telemetry)
            </label>
            {target?.is_patched && target?.sla_healthy ? (
              <div className="p-3.5 rounded-xl bg-[#ECFDF5] border border-[#1C9457]/30 font-mono text-[12px] text-[#15803D] flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-[#1C9457] shrink-0" />
                <span className="break-all">
                  🛡️ 已通过源码热补丁加固 · SLA 语义巡检 {target.sla_score.toFixed(0)}% 正常 (HTTP 200 OK)
                </span>
              </div>
            ) : target && !target.sla_healthy ? (
              <div className="p-3.5 rounded-xl border font-mono text-[12px] flex items-center gap-2 bg-[#FEF2F2] border-[#DC2E33]/35 text-[#B91C1C]">
                <AlertTriangle className="w-4 h-4 shrink-0 text-[#DC2E33]" />
                <span className="break-all">
                  🚨 SLA HEARTBEAT FLATLINE — 靶机业务接口健康巡检异常 (Score {target.sla_score.toFixed(0)}%)
                </span>
              </div>
            ) : latestHijack?.dom_mutation ? (
              <div className="p-3.5 rounded-xl border font-mono text-[12px] flex items-center gap-2 bg-[#FFFBEB] border-[#D1800A]/30 text-[#92400E]">
                <AlertTriangle className="w-4 h-4 shrink-0 text-[#D1800A]" />
                <span className="break-all">{latestHijack.dom_mutation}</span>
              </div>
            ) : (
              <div className="p-3.5 rounded-xl border font-mono text-[12px] flex items-center gap-2 bg-[#F7F8FA] border-black/[0.06] text-[#61626A]">
                <ShieldCheck className="w-4 h-4 shrink-0 text-[#007AFF]" />
                <span>HTTP 200 OK · 靶机端口正常服务中，等待实网请求事件</span>
              </div>
            )}
          </div>

          {/* Real Attacker Telemetry Cursors Positioned Strictly by Backend Coordinates */}
          {realCursors.slice(0, 4).map((wh) => {
            const xPct = Math.max(8, Math.min(88, wh.cursor_x * 100));
            const yPct = Math.max(16, Math.min(88, wh.cursor_y * 100));
            return (
              <div
                key={wh.id}
                className="pointer-events-none absolute z-20 transition-all duration-300 ease-out"
                style={{ left: `${xPct}%`, top: `${yPct}%` }}
              >
                <div className="flex items-center gap-1">
                  <MousePointer2
                    className="w-4 h-4 -rotate-12"
                    style={{ color: wh.attacker_color, fill: wh.attacker_color }}
                  />
                  <span
                    className="px-2 py-0.5 rounded-full text-[10.5px] font-bold text-white shadow-sm"
                    style={{ backgroundColor: wh.attacker_color }}
                  >
                    {wh.attacker_name}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Right 4 Cols: Web Interaction & Injection Audit Log */}
      <div className="lg:col-span-4 apple-card p-5 flex flex-col min-h-0">
        <div className="flex items-center gap-2 pb-3 mb-3 border-b border-black/[0.06] shrink-0">
          <MousePointer2 className="w-4 h-4 text-[#007AFF]" />
          <span className="text-[14px] font-bold text-[#1A1A1E]">网页交互与注入记录</span>
        </div>

        <div className="flex-1 overflow-y-auto space-y-2.5 pr-0.5">
          {match.web_hijacks.length > 0 ? (
            match.web_hijacks.map((wh) => (
              <div
                key={wh.id}
                className="p-3 rounded-xl bg-[#F7F8FA] border border-black/[0.05] space-y-1.5"
              >
                <div className="flex items-center justify-between text-xs">
                  <span className="flex items-center gap-1.5 font-bold text-[#1A1A1E]">
                    <span
                      className="w-2 h-2 rounded-full"
                      style={{ backgroundColor: wh.attacker_color }}
                    />
                    {wh.attacker_name}
                  </span>
                  <span className="font-mono text-[10.5px] text-[#6F7078]">
                    ({wh.cursor_x.toFixed(2)}, {wh.cursor_y.toFixed(2)})
                  </span>
                </div>
                <div className="font-mono text-[11px] text-[#007AFF] break-all">
                  {wh.injected_input}
                </div>
                {wh.dom_mutation && (
                  <div className="text-[11px] text-[#61626A] break-all">{wh.dom_mutation}</div>
                )}
              </div>
            ))
          ) : (
            <div className="h-full flex flex-col items-center justify-center text-center px-4 py-10 text-[#6F7078] space-y-1.5">
              <MousePointer2 className="w-5 h-5 text-[#007AFF]/50" />
              <div className="text-[12px] font-semibold text-[#1A1A1E]">暂无网页劫持记录</div>
              <div className="text-[11px] leading-relaxed">
                当战队触发 Web UI 或 SQL/Prompt/RCE 载荷命中服务端点时将实时归档
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
