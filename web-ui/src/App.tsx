import React, { useCallback, useEffect, useRef, useState } from 'react';
import { CheckCircle2 } from 'lucide-react';
import {
  ARMORY_MAPS,
  LEGENDARY_HARNESSES,
  QUICK_PRESETS,
} from './data/armoryCatalog';
import { soundEngine } from './audio/soundEngine';
import {
  applyWsEnvelope,
  createMatchOnApi,
  fetchActiveMatchFromApi,
  fetchArmoryFromApi,
  fetchLeaderboardFromApi,
  fetchMatchByIdFromApi,
  fetchMatchHistoryFromApi,
  getReplayHtmlApiUrl,
  getSavedApiBaseUrl,
  probePitHealth,
  resolveWsUrl,
  sendMatchControlApi,
  sendSeatInterveneApi,
  setSavedApiBaseUrl,
} from './services/pitApi';
import {
  ArmoryMap,
  CreateMatchRequest,
  HarnessSpec,
  HealthResponse,
  LeaderboardEntry,
  MapCategory,
  MatchState,
  SavedReplaySummary,
} from './types/pit';
import {
  ArenaSubStage,
  ArmorySubSection,
  PrimaryTab,
  TopGlobalBar,
} from './components/TopGlobalBar';
import { WebSidebar } from './components/WebSidebar';
import { BroadcastHUD } from './components/BroadcastHUD';
import { MatchLobby } from './components/MatchLobby';
import { XRayVisorOverlay } from './components/XRayVisorOverlay';
import { PosterModal } from './components/PosterModal';
import { ArmoryView } from './components/ArmoryView';
import { LeaderboardView } from './components/LeaderboardView';

const UI_SCALE_KEY = 'aexus.pit.uiScale';

export const App: React.FC = () => {
  // Default to self-explanatory Guided 3-Step Lobby so users immediately understand how to use the arena
  const [activeTab, setActiveTab] = useState<PrimaryTab>('arena');
  const [arenaSubStage, setArenaSubStage] = useState<ArenaSubStage>('lobby');
  const [armorySection, setArmorySection] = useState<ArmorySubSection>('maps');
  const [armoryCategory, setArmoryCategory] = useState<MapCategory | 'all'>('all');
  const [armoryQuery, setArmoryQuery] = useState('');
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);

  const [uiScale, setUiScale] = useState<number>(() => {
    const raw = Number(window.localStorage.getItem(UI_SCALE_KEY));
    return raw >= 0.75 && raw <= 1.5 ? raw : 1.0;
  });
  const [toastText, setToastText] = useState<string | null>(null);
  const toastTimerRef = useRef<number | null>(null);

  const [apiBaseUrl, setApiBaseUrlState] = useState<string>(() => getSavedApiBaseUrl());
  const [backendConnected, setBackendConnected] = useState(false);
  const [health, setHealth] = useState<HealthResponse | null>(null);

  const [maps, setMaps] = useState<ArmoryMap[]>(ARMORY_MAPS);
  const [harnesses, setHarnesses] = useState<HarnessSpec[]>(LEGENDARY_HARNESSES);
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
  const [replays, setReplays] = useState<SavedReplaySummary[]>([]);

  const [match, setMatch] = useState<MatchState | null>(null);
  const [focusedSeatId, setFocusedSeatId] = useState<string>('seat-1');
  const [stagedMapId, setStagedMapId] = useState<string | null>(null);
  const [stagedHarnessId, setStagedHarnessId] = useState<string | null>(null);

  const [sfxEnabled, setSfxEnabled] = useState(false);
  const [xrayOpen, setXrayOpen] = useState(false);
  const [posterOpen, setPosterOpen] = useState(false);

  const wsRef = useRef<WebSocket | null>(null);

  const showToast = useCallback((msg: string) => {
    setToastText(msg);
    if (toastTimerRef.current) window.clearTimeout(toastTimerRef.current);
    toastTimerRef.current = window.setTimeout(() => setToastText(null), 1800);
  }, []);

  const applyScale = useCallback(
    (nextVal: number, announce = true) => {
      const clamped = Math.round(Math.min(1.5, Math.max(0.75, nextVal)) * 100) / 100;
      setUiScale((prev) => {
        if (Math.abs(prev - clamped) > 0.001 && announce) {
          showToast(`界面缩放 ${Math.round(clamped * 100)}%`);
        }
        window.localStorage.setItem(UI_SCALE_KEY, String(clamped));
        return clamped;
      });
    },
    [showToast]
  );

  const connectWsForMatch = useCallback((matchId: string, baseOverride?: string) => {
    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
    }
    try {
      const ws = new WebSocket(resolveWsUrl(matchId, baseOverride));
      wsRef.current = ws;
      ws.onmessage = (ev) => {
        try {
          const msg = JSON.parse(ev.data) as Record<string, unknown>;
          setMatch((prev) => (prev ? applyWsEnvelope(prev, msg).next : prev));
        } catch {
          // ignore malformed packet
        }
      };
    } catch {
      // fallback safely
    }
  }, []);

  const probeBackend = useCallback(async () => {
    const probed = await probePitHealth();
    if (!probed) {
      setBackendConnected(false);
      setHealth(null);
      return;
    }

    setBackendConnected(true);
    setHealth(probed.health);

    const [armoryData, lbData, historyData, activeMatch] = await Promise.all([
      fetchArmoryFromApi(),
      fetchLeaderboardFromApi(),
      fetchMatchHistoryFromApi(),
      fetchActiveMatchFromApi(),
    ]);

    if (armoryData?.maps?.length) setMaps(armoryData.maps);
    if (armoryData?.harnesses?.length) setHarnesses(armoryData.harnesses);
    if (lbData !== null) setLeaderboard(lbData);
    if (historyData !== null) setReplays(historyData);

    if (activeMatch) {
      setMatch(activeMatch);
      setFocusedSeatId(activeMatch.seats[0]?.id ?? 'seat-1');
      connectWsForMatch(activeMatch.id, probed.resolvedBase);
    }
  }, [connectWsForMatch]);

  useEffect(() => {
    probeBackend();

    return () => {
      if (wsRef.current) wsRef.current.close();
    };
  }, [probeBackend]);

  // Periodically refresh live kernel eBPF counter & health status while connected
  useEffect(() => {
    if (!backendConnected) return;
    const timer = window.setInterval(async () => {
      const probed = await probePitHealth();
      if (probed) setHealth(probed.health);
    }, 3500);
    return () => window.clearInterval(timer);
  }, [backendConnected]);

  // Refresh real Leaderboard & Replay History whenever viewing Leaderboard or when match completes
  useEffect(() => {
    if (!backendConnected) return;
    if (activeTab === 'leaderboard' || match?.status === 'finished' || match?.status === 'completed') {
      Promise.all([fetchLeaderboardFromApi(), fetchMatchHistoryFromApi()]).then(
        ([lbData, historyData]) => {
          if (lbData !== null) setLeaderboard(lbData);
          if (historyData !== null) setReplays(historyData);
        }
      );
    }
  }, [backendConnected, activeTab, match?.status]);

  // Global Hotkeys: Command/Ctrl + '+' / '=' / '-' / '0' for UI Zoom + Space for Inspector Drawer
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && !e.altKey) {
        if (e.key === '+' || e.key === '=' || e.code === 'Equal' || e.code === 'NumpadAdd') {
          e.preventDefault();
          applyScale(uiScale + 0.08);
          return;
        }
        if (e.key === '-' || e.key === '_' || e.code === 'Minus' || e.code === 'NumpadSubtract') {
          e.preventDefault();
          applyScale(uiScale - 0.08);
          return;
        }
        if ((e.key === '0' || e.code === 'Digit0' || e.code === 'Numpad0') && !e.shiftKey) {
          e.preventDefault();
          applyScale(1.0);
          return;
        }
      }

      const tag = (e.target as HTMLElement | null)?.tagName ?? '';
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') {
        if (e.key === 'Escape') setXrayOpen(false);
        return;
      }

      if (e.code === 'Space') {
        if (activeTab === 'arena' && arenaSubStage === 'hud') {
          e.preventDefault();
          setXrayOpen((v) => !v);
          soundEngine.playUiConfirm();
        }
      } else if (e.key === 'Escape') {
        setXrayOpen(false);
        setPosterOpen(false);
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [activeTab, arenaSubStage, applyScale, uiScale]);

  const handleLaunchMatch = async (req: CreateMatchRequest) => {
    soundEngine.playFirstBloodSubBass();
    if (!backendConnected) {
      showToast('尚未连接 pitd 后端，请确认右上角节点在线后再开局');
      return;
    }

    const created = await createMatchOnApi(req);
    if (!created) {
      showToast('启动实网对决失败，请检查后端 Docker 与 LLM 配置');
      return;
    }

    setMatch(created);
    setFocusedSeatId(created.seats[0]?.id ?? 'seat-1');
    connectWsForMatch(created.id);
    setActiveTab('arena');
    setArenaSubStage('hud');
    Promise.all([fetchLeaderboardFromApi(), fetchMatchHistoryFromApi()]).then(
      ([lbData, historyData]) => {
        if (lbData !== null) setLeaderboard(lbData);
        if (historyData !== null) setReplays(historyData);
      }
    );
  };

  const handleTogglePause = async () => {
    if (!match || !backendConnected) return;
    const nextPaused = match.status !== 'paused';
    await sendMatchControlApi(match.id, { action: nextPaused ? 'pause' : 'resume' });
    setMatch((m) => (m ? { ...m, status: nextPaused ? 'paused' : 'running' } : m));
  };

  const handleNextRound = async () => {
    if (!match || !backendConnected) return;
    await sendMatchControlApi(match.id, { action: 'next_round' });
  };

  const handleStopMatch = async () => {
    if (!match || !backendConnected) return;
    const stopped = await sendMatchControlApi(match.id, { action: 'stop' });
    if (stopped) {
      setMatch((m) => (m ? { ...m, status: 'completed', round_remaining_sec: 0 } : m));
      showToast('已结束本局对决并冻结全部沙箱容器');
    }
  };

  const handleTogglePossess = async (seatId: string, enabled: boolean) => {
    if (!match || !backendConnected) return;
    await sendSeatInterveneApi(match.id, seatId, { type: 'possess', enabled });
    setMatch((prev) =>
      prev
        ? {
            ...prev,
            seats: prev.seats.map((s) => (s.id === seatId ? { ...s, possessed: enabled } : s)),
          }
        : prev
    );
  };

  const handleSendTerminalCmd = async (seatId: string, cmd: string) => {
    if (!match || !backendConnected) return;
    await sendSeatInterveneApi(match.id, seatId, { type: 'terminal_input', data: `${cmd}\n` });
  };

  const handleDropHint = async (seatId: string, prompt: string) => {
    if (!match || !backendConnected) return;
    await sendSeatInterveneApi(match.id, seatId, { type: 'hint', prompt });
  };

  const handleTriggerChaos = async (chaosType: 'drop_waf' | 'leak_hint' | 'surge_traffic') => {
    if (!match || !backendConnected) return;
    await sendMatchControlApi(match.id, { action: 'chaos', chaos_type: chaosType });
  };

  const handleExportReplay = () => {
    if (!match || !backendConnected) {
      showToast('尚无后端战局录像可导出');
      return;
    }
    window.open(getReplayHtmlApiUrl(match.id), '_blank', 'noopener,noreferrer');
    showToast('已从后端导出独立 .pitreplay.html 战局录像');
  };

  const ebpfCount = Math.max(health?.ebpf?.events_captured ?? 0, match?.events.length ?? 0);

  const pageTitle =
    activeTab === 'leaderboard'
      ? '天梯榜与战局录像'
      : activeTab === 'armory'
        ? armorySection === 'harnesses'
          ? '传奇渗透智能体 (Harnesses)'
          : '地图与军火素材库'
        : arenaSubStage === 'lobby'
          ? '斗兽场对决编排'
          : match?.title ?? '实况战场（待命）';

  return (
    <div className="h-screen w-screen overflow-hidden apple-canvas-bg text-[#1A1A1E]">
      <div
        style={{
          width: `${100 / uiScale}vw`,
          height: `${100 / uiScale}vh`,
          transform: `scale(${uiScale})`,
          transformOrigin: 'top left',
        }}
        className="flex overflow-hidden"
      >
        {!sidebarCollapsed && (
          <WebSidebar
            activeTab={activeTab}
            arenaSubStage={arenaSubStage}
            armorySection={armorySection}
            selectedCategory={armoryCategory}
            maps={maps}
            harnessesCount={harnesses.length}
            replaysCount={replays.length}
            seatsCount={match?.seats.length ?? 0}
            matchStatus={match?.status ?? null}
            backendConnected={backendConnected}
            ebpfEventsCount={ebpfCount}
            onSelectCreateMatch={() => {
              setActiveTab('arena');
              setArenaSubStage('lobby');
            }}
            onSelectLiveHud={() => {
              setActiveTab('arena');
              setArenaSubStage('hud');
            }}
            onSelectLeaderboard={() => {
              setActiveTab('leaderboard');
            }}
            onSelectArmoryMaps={(cat = 'all') => {
              setActiveTab('armory');
              setArmorySection('maps');
              setArmoryCategory(cat);
            }}
            onSelectArmoryHarnesses={() => {
              setActiveTab('armory');
              setArmorySection('harnesses');
            }}
            onQuickSelectMap={(mid) => {
              setStagedMapId(mid);
              setActiveTab('arena');
              setArenaSubStage('lobby');
              const found = maps.find((m) => m.id === mid);
              if (found) showToast(`已选择「${found.name}」作为对决靶标`);
            }}
          />
        )}

        <div className="flex-1 flex flex-col min-w-0 min-h-0 overflow-hidden">
          <TopGlobalBar
            pageTitle={pageTitle}
            activeTab={activeTab}
            arenaSubStage={arenaSubStage}
            sidebarCollapsed={sidebarCollapsed}
            onToggleSidebar={() => setSidebarCollapsed((v) => !v)}
            onSelectTab={setActiveTab}
            onSelectArenaSubStage={setArenaSubStage}
            armoryQuery={armoryQuery}
            onChangeArmoryQuery={setArmoryQuery}
            uiScale={uiScale}
            onZoomIn={() => applyScale(uiScale + 0.08)}
            onZoomOut={() => applyScale(uiScale - 0.08)}
            onZoomReset={() => applyScale(1.0)}
            backendConnected={backendConnected}
            apiBaseUrl={apiBaseUrl}
            onSaveApiBaseUrl={(url) => {
              setSavedApiBaseUrl(url);
              setApiBaseUrlState(url);
            }}
            onReprobeBackend={probeBackend}
            health={health}
            sfxEnabled={sfxEnabled}
            onToggleSfx={() => setSfxEnabled(soundEngine.toggle())}
          />

          {activeTab === 'arena' && arenaSubStage === 'hud' && (
            <BroadcastHUD
              match={match}
              health={health}
              backendConnected={backendConnected}
              ebpfEventsCount={ebpfCount}
              focusedSeatId={focusedSeatId}
              xrayOpen={xrayOpen}
              onSelectSeat={setFocusedSeatId}
              onOpenXrayForSeat={(sid) => {
                setFocusedSeatId(sid);
                setXrayOpen(true);
              }}
              onToggleXray={() => setXrayOpen((v) => !v)}
              onOpenLobby={() => setArenaSubStage('lobby')}
              onTogglePause={handleTogglePause}
              onStopMatch={handleStopMatch}
              onNextRound={handleNextRound}
              onTriggerChaos={handleTriggerChaos}
              onOpenPoster={() => {
                if (match) setPosterOpen(true);
              }}
              onExportReplay={handleExportReplay}
            />
          )}

          {activeTab === 'arena' && arenaSubStage === 'lobby' && (
            <MatchLobby
              maps={maps}
              harnesses={harnesses}
              initialMapId={stagedMapId}
              initialHarnessId={stagedHarnessId}
              onLaunchMatch={handleLaunchMatch}
              onBrowseArmory={() => {
                setActiveTab('armory');
                setArmorySection('maps');
              }}
              onOpenLeaderboard={() => setActiveTab('leaderboard')}
              onBackToLiveHud={() => setArenaSubStage('hud')}
            />
          )}

          {activeTab === 'armory' && (
            <ArmoryView
              maps={maps}
              harnesses={harnesses}
              section={armorySection}
              onChangeSection={setArmorySection}
              selectedCategory={armoryCategory}
              onSelectCategory={setArmoryCategory}
              searchQuery={armoryQuery}
              onSelectHarnessForLobby={(hid) => {
                setStagedHarnessId(hid);
                setActiveTab('arena');
                setArenaSubStage('lobby');
                const found = harnesses.find((h) => h.id === hid);
                if (found) showToast(`已将「${found.name}」加入参战席位`);
              }}
              onLaunchWithMap={(mid) => {
                setStagedMapId(mid);
                setActiveTab('arena');
                setArenaSubStage('lobby');
                const found = maps.find((m) => m.id === mid);
                if (found) showToast(`已装载「${found.name}」作为实战靶标`);
              }}
              onQuickStartMapNow={(mid) => {
                const found = maps.find((m) => m.id === mid);
                handleLaunchMatch({
                  ...QUICK_PRESETS[0].config,
                  title: `${found?.name ?? mid} · 实网攻防对决`,
                  map_id: mid,
                });
              }}
            />
          )}

          {activeTab === 'leaderboard' && (
            <LeaderboardView
              entries={leaderboard}
              replays={replays}
              onPlayReplayInArena={async (rep) => {
                const loaded = await fetchMatchByIdFromApi(rep.id);
                if (loaded) {
                  setMatch(loaded);
                  setFocusedSeatId(loaded.seats[0]?.id ?? 'seat-1');
                  setActiveTab('arena');
                  setArenaSubStage('hud');
                } else {
                  showToast('未能从后端加载该场次实况记录');
                }
              }}
              onDownloadReplayHtml={(rep) => {
                window.open(getReplayHtmlApiUrl(rep.id), '_blank', 'noopener,noreferrer');
                showToast('已从后端导出独立 .pitreplay.html 战局录像');
              }}
            />
          )}

          {match && (
            <>
              <XRayVisorOverlay
                open={xrayOpen}
                sidebarCollapsed={sidebarCollapsed}
                match={match}
                focusedSeatId={focusedSeatId}
                onSelectSeat={setFocusedSeatId}
                onClose={() => setXrayOpen(false)}
                onTogglePossess={handleTogglePossess}
                onSendTerminalCommand={handleSendTerminalCmd}
                onDropHint={handleDropHint}
                onTriggerChaos={handleTriggerChaos}
              />

              <PosterModal
                open={posterOpen}
                match={match}
                ebpfEventsCount={ebpfCount}
                onClose={() => setPosterOpen(false)}
              />
            </>
          )}
        </div>
      </div>

      {/* Floating Apple Toast Pill */}
      {toastText && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 px-4 py-2 rounded-full bg-white/95 border border-black/[0.08] shadow-[0_12px_32px_rgba(0,0,0,0.12)] flex items-center gap-2 text-[12.5px] font-medium text-[#1A1A1E] pointer-events-none">
          <CheckCircle2 className="w-4 h-4 text-[#1C9457]" />
          <span>{toastText}</span>
        </div>
      )}
    </div>
  );
};

export default App;
