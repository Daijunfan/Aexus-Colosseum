import React, { useState } from 'react';
import {
  Activity,
  ChevronDown,
  ChevronRight,
  Cpu,
  Globe,
  LayoutGrid,
  PlusSquare,
  Shield,
  Trophy,
  Zap,
} from 'lucide-react';
import { MAP_CATEGORIES } from '../data/armoryCatalog';
import { ArmoryMap, MapCategory } from '../types/pit';
import { AppleSquircleIcon, PitEmblem } from './PitEmblem';
import { ArenaSubStage, ArmorySubSection, PrimaryTab } from './TopGlobalBar';

interface WebSidebarProps {
  activeTab: PrimaryTab;
  arenaSubStage: ArenaSubStage;
  armorySection: ArmorySubSection;
  selectedCategory: MapCategory | 'all';
  maps: ArmoryMap[];
  harnessesCount: number;
  replaysCount: number;
  seatsCount: number;
  matchStatus?: string | null;
  backendConnected: boolean;
  ebpfEventsCount: number;
  onSelectCreateMatch: () => void;
  onSelectLiveHud: () => void;
  onSelectLeaderboard: () => void;
  onSelectArmoryMaps: (cat?: MapCategory | 'all') => void;
  onSelectArmoryHarnesses: () => void;
  onQuickSelectMap: (mapId: string) => void;
}

export const WebSidebar: React.FC<WebSidebarProps> = ({
  activeTab,
  arenaSubStage,
  armorySection,
  selectedCategory,
  maps,
  harnessesCount,
  replaysCount,
  seatsCount,
  matchStatus,
  backendConnected,
  ebpfEventsCount,
  onSelectCreateMatch,
  onSelectLiveHud,
  onSelectLeaderboard,
  onSelectArmoryMaps,
  onSelectArmoryHarnesses,
  onQuickSelectMap,
}) => {
  const [expandedCat, setExpandedCat] = useState<string>('web');

  const categories = MAP_CATEGORIES.filter((c) => c.id !== 'all');

  const navItemClass = (selected: boolean) =>
    `w-full flex items-center justify-between px-3 py-2 rounded-[10px] text-[13px] transition-all ${
      selected
        ? 'bg-white text-[#1A1A1E] font-semibold shadow-[0_2px_7px_rgba(0,0,0,0.055)] ring-1 ring-black/[0.05]'
        : 'text-[#4A4B53] font-medium hover:bg-black/[0.035]'
    }`;

  return (
    <aside className="w-[288px] shrink-0 h-full apple-frosted-sidebar border-r border-black/[0.065] flex flex-col select-none z-30">
      {/* Brand Header */}
      <div className="px-5 pt-5 pb-3.5 flex items-center gap-3">
        <PitEmblem size={38} />
        <div className="min-w-0">
          <div className="text-[15.5px] font-bold tracking-tight text-[#1A1A1E] leading-tight">
            Aexus Colosseum
          </div>
          <div className="text-[10px] font-semibold tracking-[0.14em] text-[#6F7078] uppercase mt-0.5">
            AI CYBER ARENA
          </div>
        </div>
      </div>

      {/* Scrollable Navigation Sections */}
      <div className="flex-1 overflow-y-auto px-3.5 py-2 space-y-5">
        {/* Section 1: ARENA */}
        <div>
          <div className="px-2.5 mb-1.5 text-[10px] font-bold tracking-[0.12em] text-[#6F7078] uppercase">
            ARENA · 攻防竞技
          </div>
          <div className="space-y-1">
            <button
              type="button"
              onClick={onSelectCreateMatch}
              className={navItemClass(activeTab === 'arena' && arenaSubStage === 'lobby')}
            >
              <span className="flex items-center gap-2.5">
                <PlusSquare
                  className={`w-4 h-4 ${
                    activeTab === 'arena' && arenaSubStage === 'lobby'
                      ? 'text-[#007AFF]'
                      : 'text-[#6F7078]'
                  }`}
                />
                <span>创建对决</span>
              </span>
              <span className="text-[11px] font-mono text-[#6F7078]">{seatsCount} 席</span>
            </button>

            <button
              type="button"
              onClick={onSelectLiveHud}
              className={navItemClass(activeTab === 'arena' && arenaSubStage === 'hud')}
            >
              <span className="flex items-center gap-2.5">
                <Activity
                  className={`w-4 h-4 ${
                    activeTab === 'arena' && arenaSubStage === 'hud'
                      ? 'text-[#007AFF]'
                      : 'text-[#6F7078]'
                  }`}
                />
                <span>实况战场</span>
              </span>
              {matchStatus === 'running' ? (
                <span className="px-2 py-0.5 rounded-full bg-[#007AFF] text-white text-[9.5px] font-bold tracking-wider">
                  LIVE
                </span>
              ) : matchStatus === 'finished' || matchStatus === 'completed' ? (
                <span className="px-2 py-0.5 rounded-full bg-[#1C9457]/12 text-[#1C9457] text-[9.5px] font-bold">
                  已完赛
                </span>
              ) : null}
            </button>

            <button
              type="button"
              onClick={onSelectLeaderboard}
              className={navItemClass(activeTab === 'leaderboard')}
            >
              <span className="flex items-center gap-2.5">
                <Trophy
                  className={`w-4 h-4 ${
                    activeTab === 'leaderboard' ? 'text-[#007AFF]' : 'text-[#6F7078]'
                  }`}
                />
                <span>天梯与战局录像</span>
              </span>
              <span className="text-[11px] font-mono text-[#6F7078]">{replaysCount}</span>
            </button>
          </div>
        </div>

        {/* Section 2: ARMORY */}
        <div>
          <div className="px-2.5 mb-1.5 text-[10px] font-bold tracking-[0.12em] text-[#6F7078] uppercase">
            ARMORY · 素材与工具
          </div>
          <div className="space-y-1">
            <button
              type="button"
              onClick={() => onSelectArmoryMaps('all')}
              className={navItemClass(
                activeTab === 'armory' && armorySection === 'maps' && selectedCategory === 'all'
              )}
            >
              <span className="flex items-center gap-2.5">
                <LayoutGrid
                  className={`w-4 h-4 ${
                    activeTab === 'armory' && armorySection === 'maps'
                      ? 'text-[#007AFF]'
                      : 'text-[#6F7078]'
                  }`}
                />
                <span>全部靶标地图</span>
              </span>
              <span className="text-[11px] font-mono text-[#6F7078]">{maps.length}</span>
            </button>

            <button
              type="button"
              onClick={onSelectArmoryHarnesses}
              className={navItemClass(activeTab === 'armory' && armorySection === 'harnesses')}
            >
              <span className="flex items-center gap-2.5">
                <Cpu
                  className={`w-4 h-4 ${
                    activeTab === 'armory' && armorySection === 'harnesses'
                      ? 'text-[#007AFF]'
                      : 'text-[#6F7078]'
                  }`}
                />
                <span>传奇渗透智能体</span>
              </span>
              <span className="text-[11px] font-mono text-[#6F7078]">{harnessesCount}</span>
            </button>
          </div>
        </div>

        {/* Section 3: Expandable Categories Tree (Matching Aexus Spear) */}
        <div>
          <div className="px-2.5 mb-1.5 text-[10px] font-bold tracking-[0.12em] text-[#6F7078] uppercase">
            CATEGORIES · 靶标分类
          </div>
          <div className="space-y-1">
            {categories.map((cat) => {
              const catMaps = maps.filter((m) => m.category === cat.id);
              const isOpen = expandedCat === cat.id;
              const isCatSelected =
                activeTab === 'armory' && armorySection === 'maps' && selectedCategory === cat.id;

              return (
                <div key={cat.id}>
                  <button
                    type="button"
                    onClick={() => {
                      setExpandedCat(isOpen ? '' : cat.id);
                      onSelectArmoryMaps(cat.id);
                    }}
                    className={`w-full flex items-center justify-between px-2.5 py-1.5 rounded-[9px] text-[12.5px] transition-colors ${
                      isCatSelected
                        ? 'bg-[#007AFF]/10 text-[#007AFF] font-semibold'
                        : 'text-[#4A4B53] hover:bg-black/[0.035] font-medium'
                    }`}
                  >
                    <span className="flex items-center gap-2 truncate">
                      <span
                        className="w-2 h-2 rounded-full shrink-0"
                        style={{ backgroundColor: cat.color }}
                      />
                      <span className="truncate">{cat.name}</span>
                    </span>
                    <span className="flex items-center gap-1 text-[11px] font-mono text-[#6F7078] shrink-0">
                      <span>{catMaps.length}</span>
                      {isOpen ? (
                        <ChevronDown className="w-3.5 h-3.5" />
                      ) : (
                        <ChevronRight className="w-3.5 h-3.5" />
                      )}
                    </span>
                  </button>

                  {isOpen && (
                    <div className="mt-1 ml-2 pl-2 border-l border-black/[0.06] space-y-0.5">
                      {catMaps.slice(0, 10).map((m) => (
                        <button
                          key={m.id}
                          type="button"
                          onClick={() => onQuickSelectMap(m.id)}
                          className="w-full flex items-center justify-between gap-2 px-2 py-1.5 rounded-lg hover:bg-white/80 text-left transition-colors group"
                          title={`选作靶标：${m.name}`}
                        >
                          <span className="flex items-center gap-2 min-w-0">
                            <AppleSquircleIcon
                              colors={[cat.color, '#007AFF']}
                              size={20}
                            >
                              {cat.id === 'web' ? (
                                <Globe className="w-2.5 h-2.5" />
                              ) : (
                                <Shield className="w-2.5 h-2.5" />
                              )}
                            </AppleSquircleIcon>
                            <span className="text-[12px] text-[#2C2D33] group-hover:text-[#007AFF] truncate">
                              {m.name}
                            </span>
                          </span>
                          <span className="w-1.5 h-1.5 rounded-full bg-[#1C9457] shrink-0" />
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Bottom Workspace Engine Card (Matching Aexus Spear Footer) */}
      <div className="p-3.5 border-t border-black/[0.06] space-y-2">
        <div className="rounded-2xl bg-white/90 border border-black/[0.06] shadow-[0_3px_10px_rgba(0,0,0,0.035)] px-3 py-2.5 flex items-center justify-between gap-2">
          <div className="flex items-center gap-2.5 min-w-0">
            <div className="w-7 h-7 rounded-lg bg-[#007AFF]/10 text-[#007AFF] flex items-center justify-center shrink-0">
              <Zap className="w-3.5 h-3.5" />
            </div>
            <div className="min-w-0">
              <div className="text-[9.5px] font-bold tracking-wider text-[#007AFF] uppercase">
                ARENA ENGINE
              </div>
              <div className="text-[11.5px] font-semibold text-[#1A1A1E] truncate">
                {backendConnected ? 'Linux eBPF 真机在线' : '未连接后端 pitd'}
              </div>
            </div>
          </div>
          <span className="text-[10.5px] font-mono font-semibold text-[#1C9457] shrink-0">
            {ebpfEventsCount.toLocaleString()} eBPF
          </span>
        </div>

        <div className="px-1 flex items-center justify-between text-[10.5px] text-[#6F7078]">
          <span>{backendConnected ? 'Docker + eBPF 就绪' : '等待后端服务'}</span>
          <span>{maps.length} 款靶标可用</span>
        </div>
      </div>
    </aside>
  );
};
