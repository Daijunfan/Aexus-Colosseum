package api

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"aexus.io/pitd/internal/armory"
	"aexus.io/pitd/internal/engine"
	"aexus.io/pitd/internal/gateway"
	"aexus.io/pitd/internal/model"
	"aexus.io/pitd/internal/replay"
	"aexus.io/pitd/internal/ws"
)

type Server struct {
	armory  *armory.Registry
	mgr     *engine.Manager
	hub     *ws.Hub
	gw      *gateway.Gateway
	webDir  string
	handler http.Handler
}

func NewServer(arm *armory.Registry, mgr *engine.Manager, hub *ws.Hub, gw *gateway.Gateway, webDir string) *Server {
	s := &Server{
		armory: arm,
		mgr:    mgr,
		hub:    hub,
		gw:     gw,
		webDir: webDir,
	}
	s.handler = withCORS(s.buildMux())
	return s
}

func (s *Server) Handler() http.Handler {
	return s.handler
}

func (s *Server) buildMux() *http.ServeMux {
	mux := http.NewServeMux()

	// Control Plane REST API (/api/v1/...)
	mux.HandleFunc("GET /api/v1/health", s.handleHealth)
	mux.HandleFunc("GET /api/v1/armory", s.handleArmory)
	mux.HandleFunc("GET /api/v1/matches", s.handleListMatches)
	mux.HandleFunc("POST /api/v1/matches", s.handleCreateMatch)
	mux.HandleFunc("GET /api/v1/matches/{id}", s.handleGetMatch)
	mux.HandleFunc("POST /api/v1/matches/{id}/control", s.handleControlMatch)
	mux.HandleFunc("POST /api/v1/matches/{id}/seats/{seat_id}/intervene", s.handleIntervene)
	mux.HandleFunc("POST /api/v1/matches/{id}/submit-flag", s.handleSubmitFlag)
	mux.HandleFunc("GET /api/v1/matches/{id}/replay", s.handleGetReplayJSON)
	mux.HandleFunc("GET /api/v1/matches/{id}/replay.html", s.handleGetReplayHTML)
	mux.HandleFunc("GET /api/v1/leaderboard", s.handleLeaderboard)
	mux.HandleFunc("POST /api/v1/internal/ebpf-ingest", s.handleEBPFIngest)

	// Real-time WebSocket Stream
	mux.HandleFunc("GET /api/v1/ws", func(w http.ResponseWriter, r *http.Request) {
		s.hub.ServeWS(w, r, s.mgr.InitialWSFrames)
	})

	// Convenience root /replay.html shortcut (renders latest or ?match_id= match)
	mux.HandleFunc("GET /replay.html", s.handleShortcutReplayHTML)

	// Forced Transparent LLM Metering Gateway
	mux.HandleFunc("GET /llm-gateway/{seat_token}/v1/models", s.gw.HandleModels)
	mux.HandleFunc("POST /llm-gateway/{seat_token}/v1/chat/completions", s.gw.HandleOpenAIChat)
	mux.HandleFunc("POST /llm-gateway/{seat_token}/chat/completions", s.gw.HandleOpenAIChat)
	mux.HandleFunc("POST /llm-gateway/{seat_token}/anthropic/v1/messages", s.gw.HandleAnthropicMessages)
	mux.HandleFunc("POST /llm-gateway/{seat_token}/v1/messages", s.gw.HandleAnthropicMessages)

	// Static Web UI + SPA index.html fallback
	mux.HandleFunc("/", s.handleSPAOrFallback)

	return mux
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, s.mgr.Health())
}

func (s *Server) handleArmory(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, s.armory.Snapshot())
}

func (s *Server) handleListMatches(w http.ResponseWriter, r *http.Request) {
	list := s.mgr.ListMatches()
	if r.URL.Query().Get("format") == "array" {
		writeJSON(w, http.StatusOK, list)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":      true,
		"count":   len(list),
		"matches": list,
	})
}

func (s *Server) handleCreateMatch(w http.ResponseWriter, r *http.Request) {
	var req model.CreateMatchRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	st, err := s.mgr.CreateMatch(req)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, st)
}

func (s *Server) handleGetMatch(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	st, err := s.mgr.GetMatch(id)
	if err != nil {
		status := http.StatusNotFound
		if !errors.Is(err, engine.ErrMatchNotFound) {
			status = http.StatusBadRequest
		}
		writeError(w, status, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, st)
}

func (s *Server) handleControlMatch(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	var req model.MatchControlRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	st, err := s.mgr.ControlMatch(id, req)
	if err != nil {
		status := http.StatusBadRequest
		if errors.Is(err, engine.ErrMatchNotFound) {
			status = http.StatusNotFound
		}
		writeError(w, status, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, st)
}

func (s *Server) handleIntervene(w http.ResponseWriter, r *http.Request) {
	matchID := r.PathValue("id")
	seatID := r.PathValue("seat_id")
	var req model.InterveneRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	res, err := s.mgr.Intervene(r.Context(), matchID, seatID, req)
	if err != nil {
		status := http.StatusBadRequest
		if errors.Is(err, engine.ErrMatchNotFound) || errors.Is(err, engine.ErrSeatNotFound) {
			status = http.StatusNotFound
		}
		writeError(w, status, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, res)
}

func (s *Server) handleSubmitFlag(w http.ResponseWriter, r *http.Request) {
	matchID := r.PathValue("id")
	var req model.SubmitFlagRequest
	if err := decodeBody(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	res, err := s.mgr.SubmitFlag(matchID, req)
	if err != nil {
		status := http.StatusBadRequest
		if errors.Is(err, engine.ErrMatchNotFound) || errors.Is(err, engine.ErrSeatNotFound) {
			status = http.StatusNotFound
		}
		writeError(w, status, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, res)
}

func (s *Server) handleGetReplayJSON(w http.ResponseWriter, r *http.Request) {
	matchID := r.PathValue("id")
	bundle, err := s.mgr.ExportReplayBundle(matchID)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	w.Header().Set("Content-Disposition", fmt.Sprintf("inline; filename=%q", matchID+".pitreplay.json"))
	writeJSON(w, http.StatusOK, bundle)
}

func (s *Server) handleGetReplayHTML(w http.ResponseWriter, r *http.Request) {
	matchID := r.PathValue("id")
	s.serveReplayHTMLFor(w, matchID)
}

func (s *Server) handleShortcutReplayHTML(w http.ResponseWriter, r *http.Request) {
	matchID := r.URL.Query().Get("match_id")
	if matchID == "" {
		matches := s.mgr.ListMatches()
		if len(matches) == 0 {
			writeError(w, http.StatusNotFound, "no recorded matches yet")
			return
		}
		matchID = matches[0].ID
	}
	s.serveReplayHTMLFor(w, matchID)
}

func (s *Server) serveReplayHTMLFor(w http.ResponseWriter, matchID string) {
	bundle, err := s.mgr.ExportReplayBundle(matchID)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	htmlBytes, err := replay.RenderHTML(bundle)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(htmlBytes)
}

func (s *Server) handleLeaderboard(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, s.mgr.GlobalLeaderboard())
}

// handleEBPFIngest accepts single EBPF_EVENT object, []EBPF_EVENT array, or {"events":[...]}.
func (s *Server) handleEBPFIngest(w http.ResponseWriter, r *http.Request) {
	raw, err := io.ReadAll(io.LimitReader(r.Body, 4*1024*1024))
	if err != nil {
		writeError(w, http.StatusBadRequest, "failed reading body")
		return
	}
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 {
		writeError(w, http.StatusBadRequest, "empty payload")
		return
	}

	var events []model.EBPFEventPayload
	if trimmed[0] == '[' {
		if err := json.Unmarshal(trimmed, &events); err != nil {
			writeError(w, http.StatusBadRequest, "invalid JSON array: "+err.Error())
			return
		}
	} else {
		var wrapper struct {
			Events []model.EBPFEventPayload `json:"events"`
		}
		if json.Unmarshal(trimmed, &wrapper) == nil && wrapper.Events != nil {
			events = wrapper.Events
		} else {
			var single model.EBPFEventPayload
			if err := json.Unmarshal(trimmed, &single); err != nil {
				writeError(w, http.StatusBadRequest, "invalid EBPF_EVENT JSON: "+err.Error())
				return
			}
			events = []model.EBPFEventPayload{single}
		}
	}

	accepted := s.mgr.IngestEBPFEvents(events, true)
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":       true,
		"received": len(events),
		"accepted": accepted,
	})
}

func (s *Server) handleSPAOrFallback(w http.ResponseWriter, r *http.Request) {
	if strings.HasPrefix(r.URL.Path, "/api/") || strings.HasPrefix(r.URL.Path, "/llm-gateway/") {
		writeError(w, http.StatusNotFound, "endpoint not found: "+r.URL.Path)
		return
	}

	if s.webDir != "" {
		if info, err := os.Stat(s.webDir); err == nil && info.IsDir() {
			cleanRel := strings.TrimPrefix(filepath.Clean(r.URL.Path), "/")
			candidate := filepath.Join(s.webDir, cleanRel)
			if cleanRel != "" {
				if st, err := os.Stat(candidate); err == nil && !st.IsDir() {
					http.ServeFile(w, r, candidate)
					return
				}
			}
			indexFile := filepath.Join(s.webDir, "index.html")
			if _, err := os.Stat(indexFile); err == nil {
				http.ServeFile(w, r, indexFile)
				return
			}
		}
	}

	// Clean standalone diagnostic landing page if web-ui/dist is not yet built
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = io.WriteString(w, `<!doctype html><html><head><meta charset="utf-8"><title>pitd · Aexus Colosseum Core</title>
<style>body{background:#07090e;color:#e2e8f0;font-family:ui-monospace,monospace;padding:48px}a{color:#00f0ff;text-decoration:none}li{margin:8px 0}</style></head>
<body><h2 style="color:#ff2e4c">AEXUS COLOSSEUM · pitd CONTROL PLANE ONLINE</h2>
<ul>
  <li><a href="/api/v1/health">GET /api/v1/health</a></li>
  <li><a href="/api/v1/armory">GET /api/v1/armory (130+ Maps & Legendary Harnesses)</a></li>
  <li><a href="/api/v1/matches">GET /api/v1/matches</a></li>
  <li><a href="/api/v1/leaderboard">GET /api/v1/leaderboard</a></li>
  <li><a href="/replay.html">GET /replay.html (Standalone 60fps Showcase Replay Player)</a></li>
</ul></body></html>`)
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-API-Key, anthropic-version, X-Pit-Seat-Token, X-Pit-Token-Cost, Accept, Origin")
		w.Header().Set("Access-Control-Expose-Headers", "Content-Type, X-Pit-Mana-Remaining")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func decodeBody(r *http.Request, dst any) error {
	raw, err := io.ReadAll(io.LimitReader(r.Body, 2*1024*1024))
	if err != nil {
		return err
	}
	if len(bytes.TrimSpace(raw)) == 0 {
		return nil
	}
	return json.Unmarshal(raw, dst)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]any{
		"ok":    false,
		"error": msg,
	})
}
