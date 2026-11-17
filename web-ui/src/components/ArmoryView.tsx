import React, { useMemo, useState } from 'react';
import {
  Bug,
  Check,
  Cloud,
  Copy,
  Cpu,
  Globe,
  LayoutGrid,
  Network,
  Radar,
  Search,
  Shield,
  ShieldCheck,
  Sparkles,
  Star,
  Terminal,
} from 'lucide-react';
import {
  ARMORY_MAPS,
  LEGENDARY_HARNESSES,
  MAP_CATEGORIES,
} from '../data/armoryCatalog';
import { ArmoryMap, HarnessSpec, MapCategory } from '../types/pit';
import { AppleOpenPill, AppleSquircleIcon } from './PitEmblem';
import { ArmorySubSection } from './TopGlobalBar';

interface ArmoryViewProps {
  maps: ArmoryMap[];
  harnesses: HarnessSpec[];
  section: ArmorySubSection;
  onChangeSection: (sec: ArmorySubSection) => void;
  selectedCategory: MapCategory | 'all';
  onSelectCategory: (cat: MapCategory | 'all') => void;
  searchQuery: string;
  onSelectHarnessForLobby: (harnessId: string) => void;
  onLaunchWithMap: (mapId: string) => void;
  onQuickStartMapNow: (mapId: string) => void;
}

const TEN_LINE_CONTRACT = `# Aexus Colosseum — 10 行零侵入自研智能体接入契约
FROM python:3.12-slim
WORKDIR /fighter
COPY my_agent.py .
# 裁判在容器启动时自动注入以下 5 个环境变量：
#   OPENAI_BASE_URL=http://172.28.0.1:18880/llm-gateway/$PIT_SEAT_TOKEN/v1
#   OPENAI_API_KEY=$PIT_SEAT_TOKEN          (额度耗尽时返回 HTTP 402!)
#   PIT_TOKEN_BUDGET=1000000                (固定公平 Token 预算池)
#   PIT_TARGET_HOST=172.28.0.50:8080        (本场目标靶机地址)
#   PIT_FLAG_SUBMIT_URL=http://172.28.0.1:18880/api/v1/matches/$MATCH_ID/submit-flag
CMD ["python3", "my_agent.py"]`;

function categoryPalette(cat: MapCategory): [string, string] {
  switch (cat) {
    case 'web':
      return ['#1E90FF', '#0066D6'];
    case 'cve':
      return ['#EF4444', '#B91C1C'];
    case 'network':
      return ['#14B8A6', '#0F766E'];
    case 'redteam':
      return ['#F97316', '#C2410C'];
    case 'cloud':
      return ['#6366F1', '#4338CA'];
    case 'binary':
      return ['#8B5CF6', '#6D28D9'];
    case 'forensics':
      return ['#10B981', '#047857'];
    case 'ai':
      return ['#EC4899', '#BE185D'];
    default:
      return ['#F59E0B', '#B45309'];
  }
}

function categoryIcon(cat: MapCategory) {
  switch (cat) {
    case 'web':
      return <Globe className="w-7 h-7" />;
    case 'cve':
      return <Bug className="w-7 h-7" />;
    case 'network':
      return <Network className="w-7 h-7" />;
    case 'cloud':
      return <Cloud className="w-7 h-7" />;
    case 'ai':
      return <Sparkles className="w-7 h-7" />;
    case 'misc':
      return <Radar className="w-7 h-7" />;
    default:
      return <Shield className="w-7 h-7" />;
  }
}

export const ArmoryView: React.FC<ArmoryViewProps> = ({
  maps,
  harnesses,
  section,
  onChangeSection,
  selectedCategory,
  onSelectCategory,
  searchQuery,
  onSelectHarnessForLobby,
  onLaunchWithMap,
  onQuickStartMapNow,
}) => {
  const [awdOnly, setAwdOnly] = useState(false);
  const [copied, setCopied] = useState(false);

  const catalogMaps = maps.length ? maps : ARMORY_MAPS;
  const catalogHarnesses = harnesses.length ? harnesses : LEGENDARY_HARNESSES;

  const filteredMaps = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return catalogMaps.filter((m) => {
      if (selectedCategory !== 'all' && m.category !== selectedCategory) return false;
      if (awdOnly && !m.supports_awd_patch) return false;
      if (!q) return true;
      return (
        m.name.toLowerCase().includes(q) ||
        m.id.toLowerCase().includes(q) ||
        (m.subtitle ?? '').toLowerCase().includes(q) ||
        m.summary.toLowerCase().includes(q) ||
        m.tags.some((t) => t.toLowerCase().includes(q))
      );
    });
  }, [catalogMaps, selectedCategory, awdOnly, searchQuery]);

  const filteredHarnesses = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) return catalogHarnesses;
    return catalogHarnesses.filter(
      (h) =>
        h.name.toLowerCase().includes(q) ||
        h.tagline.toLowerCase().includes(q) ||
        h.tags.some((t) => t.toLowerCase().includes(q))
    );
  }, [catalogHarnesses, searchQuery]);

  const categoryCounts = useMemo(() => {
    const counts: Record<string, number> = { all: catalogMaps.length };
    catalogMaps.forEach((m) => {
      counts[m.category] = (counts[m.category] ?? 0) + 1;
    });
    return counts;
  }, [catalogMaps]);

  const copyContract = () => {
    navigator.clipboard?.writeText(TEN_LINE_CONTRACT);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1800);
  };

  return (
    <div className="flex-1 overflow-y-auto px-7 py-7">
      <div className="max-w-[1380px] mx-auto space-y-6 pb-10">
        {/* Page Header + Maps/Harnesses Switcher */}
        <div className="flex flex-col lg:flex-row lg:items-end justify-between gap-4">
          <div>
            <div className="text-[10.5px] font-bold tracking-[0.14em] text-[#6F7078] uppercase">
              ARMORY CATALOG · {catalogMaps.length} TARGETS
            </div>
            <h2 className="text-[32px] font-bold tracking-tight text-[#1A1A1E] mt-1 leading-tight">
              {section === 'harnesses' ? '传奇开源渗透智能体' : '地图与军火素材库'}
            </h2>
            <p className="text-[13.5px] text-[#61626A] mt-1">
              收录 {catalogMaps.length} 款真实 CTF/CVE 靶标与 {catalogHarnesses.length}{' '}
              大开源渗透 Harness 舰队，一键抽调投入斗兽场实网对决。
            </p>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <button
              type="button"
              onClick={() => onChangeSection('maps')}
              className={`h-9 px-4 rounded-full text-[12.5px] font-semibold flex items-center gap-1.5 transition-all ${
                section === 'maps'
                  ? 'bg-[#007AFF] text-white shadow-[0_4px_12px_rgba(0,122,255,0.26)]'
                  : 'bg-white hover:bg-[#F7F8FA] text-[#4A4B53] border border-black/[0.08]'
              }`}
            >
              <LayoutGrid className="w-3.5 h-3.5" />
              <span>靶标地图库 {catalogMaps.length}</span>
            </button>

            <button
              type="button"
              onClick={() => onChangeSection('harnesses')}
              className={`h-9 px-4 rounded-full text-[12.5px] font-semibold flex items-center gap-1.5 transition-all ${
                section === 'harnesses'
                  ? 'bg-[#007AFF] text-white shadow-[0_4px_12px_rgba(0,122,255,0.26)]'
                  : 'bg-white hover:bg-[#F7F8FA] text-[#4A4B53] border border-black/[0.08]'
              }`}
            >
              <Cpu className="w-3.5 h-3.5" />
              <span>传奇智能体 {catalogHarnesses.length}</span>
            </button>
          </div>
        </div>

        {section === 'maps' ? (
          <>
            {/* Wrapping Apple Category Filter Pills (1:1 Aexus Spear) */}
            <div className="flex flex-wrap items-center gap-2">
              {MAP_CATEGORIES.map((cat) => {
                const active = selectedCategory === cat.id;
                const cnt = categoryCounts[cat.id] ?? 0;
                return (
                  <button
                    key={cat.id}
                    type="button"
                    onClick={() => onSelectCategory(cat.id)}
                    className={`h-8 px-3.5 rounded-full text-[12px] font-semibold flex items-center gap-1.5 transition-all ${
                      active
                        ? 'bg-[#007AFF] text-white shadow-[0_3px_8px_rgba(0,122,255,0.24)]'
                        : 'bg-white/85 hover:bg-white text-[#4A4B53] border border-black/[0.07]'
                    }`}
                  >
                    <span>{cat.id === 'all' ? 'All' : cat.name}</span>
                    <span
                      className={`text-[10.5px] font-mono ${
                        active ? 'text-white/85' : 'text-[#6F7078]'
                      }`}
                    >
                      {cnt}
                    </span>
                  </button>
                );
              })}

              <button
                type="button"
                onClick={() => setAwdOnly((v) => !v)}
                className={`h-8 px-3.5 rounded-full text-[12px] font-semibold flex items-center gap-1.5 transition-all ${
                  awdOnly
                    ? 'bg-[#1C9457] text-white'
                    : 'bg-white/85 hover:bg-white text-[#4A4B53] border border-black/[0.07]'
                }`}
              >
                <ShieldCheck className="w-3.5 h-3.5" />
                <span>支持源码热补丁 (AWD)</span>
              </button>
            </div>

            {/* 4-Column Apple App Store Card Grid (1:1 Aexus Spear) */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              {filteredMaps.map((m) => {
                const catMeta =
                  MAP_CATEGORIES.find((c) => c.id === m.category) ?? MAP_CATEGORIES[0];
                const colors = categoryPalette(m.category);

                return (
                  <div
                    key={m.id}
                    role="button"
                    tabIndex={0}
                    onClick={() => onLaunchWithMap(m.id)}
                    className="apple-card-interactive p-5 flex flex-col justify-between min-h-[218px]"
                  >
                    <div>
                      <div className="flex items-start justify-between gap-3">
                        <AppleSquircleIcon colors={colors} size={60}>
                          {categoryIcon(m.category)}
                        </AppleSquircleIcon>

                        <div className="flex items-center gap-1.5">
                          <AppleOpenPill
                            label="选作靶标"
                            onClick={(e) => {
                              e.stopPropagation();
                              onLaunchWithMap(m.id);
                            }}
                            title="装载到对决编排台"
                          />
                        </div>
                      </div>

                      <h3 className="text-[16px] font-bold text-[#1A1A1E] mt-4 line-clamp-1">
                        {m.name}
                      </h3>
                      <p className="text-[12.5px] text-[#61626A] mt-1.5 line-clamp-2 leading-relaxed">
                        {m.summary}
                      </p>
                    </div>

                    <div className="mt-4 pt-2.5 flex items-center justify-between text-[10.5px] font-bold tracking-wide">
                      <span
                        className="uppercase truncate"
                        style={{ color: colors[0] }}
                      >
                        ● {catMeta.name}
                      </span>
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          onQuickStartMapNow(m.id);
                        }}
                        className="text-[#1C9457] hover:text-[#007AFF] font-mono font-bold transition-colors"
                        title="用此靶标立即开局"
                      >
                        ● 立即开战
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>

            {filteredMaps.length === 0 && (
              <div className="apple-card py-16 text-center space-y-2">
                <Search className="w-7 h-7 text-[#6F7078] mx-auto" />
                <div className="text-[15px] font-semibold text-[#1A1A1E]">没有找到匹配的靶标</div>
                <div className="text-[12.5px] text-[#61626A]">请尝试其他关键词或切换全部分类</div>
              </div>
            )}
          </>
        ) : (
          <div className="space-y-6">
            {/* 4-Column Legendary Harnesses App Store Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              {filteredHarnesses.map((h) => (
                <div
                  key={h.id}
                  role="button"
                  tabIndex={0}
                  onClick={() => onSelectHarnessForLobby(h.id)}
                  className="apple-card-interactive p-5 flex flex-col justify-between min-h-[246px]"
                >
                  <div>
                    <div className="flex items-start justify-between gap-3">
                      <AppleSquircleIcon
                        colors={[h.accent_color, '#007AFF']}
                        size={60}
                      >
                        <Cpu className="w-7 h-7" />
                      </AppleSquircleIcon>

                      <AppleOpenPill
                        label="派上场"
                        onClick={(e) => {
                          e.stopPropagation();
                          onSelectHarnessForLobby(h.id);
                        }}
                      />
                    </div>

                    <div className="flex items-center justify-between gap-2 mt-4">
                      <h3 className="text-[16.5px] font-bold text-[#1A1A1E] truncate">
                        {h.name}
                      </h3>
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-[#FFF7ED] text-[#D1800A] border border-[#F59E0B]/25 text-[11px] font-bold shrink-0">
                        <Star className="w-3 h-3 fill-current" />
                        {h.stars}
                      </span>
                    </div>

                    <div className="text-[11px] font-mono text-[#6F7078] mt-0.5">
                      {h.developer}
                    </div>
                    <p className="text-[12.5px] text-[#61626A] mt-2 line-clamp-2 leading-relaxed">
                      {h.tagline}
                    </p>
                  </div>

                  <div className="mt-4 pt-3 border-t border-black/[0.05] grid grid-cols-2 gap-x-3 gap-y-1.5 text-[10.5px]">
                    {(
                      [
                        ['侦察能力', h.capabilities.recon],
                        ['漏洞利用', h.capabilities.exploit],
                        ['源码热修', h.capabilities.patch],
                        ['Token 效率', h.capabilities.efficiency],
                      ] as [string, number][]
                    ).map(([label, val]) => (
                      <div key={label}>
                        <div className="flex justify-between text-[#61626A] mb-0.5">
                          <span>{label}</span>
                          <span className="font-mono font-bold text-[#1A1A1E]">{val}</span>
                        </div>
                        <div className="h-1 rounded-full bg-black/[0.06] overflow-hidden">
                          <div
                            className="h-full rounded-full bg-[#007AFF]"
                            style={{ width: `${val}%` }}
                          />
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>

            {/* Clean Xcode-Light 10-Line Zero-SDK Contract Card */}
            <div className="apple-card p-5 space-y-3">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-xl bg-[#007AFF]/10 text-[#007AFF] flex items-center justify-center">
                    <Terminal className="w-4 h-4" />
                  </div>
                  <div>
                    <div className="text-[14px] font-bold text-[#1A1A1E]">
                      10 行极简自研智能体接入协议（免 SDK · 标准环境变量注入）
                    </div>
                    <div className="text-[12px] text-[#61626A]">
                      任意语言编写的 Agent 只需读取标准 OpenAI 环境变量即可直接参战
                    </div>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={copyContract}
                  className="self-start sm:self-auto h-8 px-3.5 rounded-full bg-[#EBF3FF] hover:bg-[#DCEBFE] text-[#007AFF] text-xs font-semibold flex items-center gap-1.5 transition-colors"
                >
                  {copied ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
                  <span>{copied ? '已复制模板' : '复制 Dockerfile 模板'}</span>
                </button>
              </div>

              <pre className="p-4 rounded-2xl bg-[#F6F7FA] border border-black/[0.06] font-mono text-[12px] text-[#1A1A1E] overflow-x-auto leading-relaxed">
                {TEN_LINE_CONTRACT}
              </pre>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
