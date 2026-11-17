package api

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"aexus.io/pitd/internal/armory"
	"aexus.io/pitd/internal/engine"
	"aexus.io/pitd/internal/gateway"
	"aexus.io/pitd/internal/model"
	"aexus.io/pitd/internal/runtime"
	"aexus.io/pitd/internal/ws"
	"github.com/gorilla/websocket"
)

func TestFullRESTAndWebSocketEndToEnd(t *testing.T) {
	webDir := t.TempDir()
	_ = os.WriteFile(filepath.Join(webDir, "index.html"), []byte("<html><body>SPA_INDEX_OK</body></html>"), 0o644)

	arm := armory.NewRegistry("/nonexistent")
	hub := ws.NewHub()
	drv := runtime.NewCompositeDriver(t.TempDir(), nil)
	mgr := engine.NewManager(arm, hub, drv, 18880, "127.0.0.1")
	drv.SetCallbacks(mgr)
	defer mgr.Shutdown()

	gw := gateway.NewGateway(mgr)
	apiSrv := NewServer(arm, mgr, hub, gw, webDir)
	ts := httptest.NewServer(apiSrv.Handler())
	defer ts.Close()

	// 1. CORS Preflight OPTIONS check
	optReq, _ := http.NewRequest(http.MethodOptions, ts.URL+"/api/v1/matches", nil)
	optResp, err := http.DefaultClient.Do(optReq)
	if err != nil {
		t.Fatal(err)
	}
	_ = optResp.Body.Close()
	if optResp.StatusCode != http.StatusNoContent || optResp.Header.Get("Access-Control-Allow-Origin") != "*" {
		t.Fatalf("CORS preflight failed: status=%d allow-origin=%q", optResp.StatusCode, optResp.Header.Get("Access-Control-Allow-Origin"))
	}

	// 2. GET /api/v1/health
	var health model.HealthResponse
	getJSON(t, ts.URL+"/api/v1/health", &health)
	if !health.OK || health.ArmoryMapsCount < 100 || health.HarnessesCount < 8 {
		t.Fatalf("unexpected /api/v1/health: %+v", health)
	}

	// 3. GET /api/v1/armory
	var armResp model.ArmoryResponse
	getJSON(t, ts.URL+"/api/v1/armory", &armResp)
	if len(armResp.Maps) < 100 || len(armResp.Harnesses) < 8 {
		t.Fatalf("unexpected /api/v1/armory counts: maps=%d harnesses=%d", len(armResp.Maps), len(armResp.Harnesses))
	}

	// 4. Clean empty cold-start (zero fake/seeded matches or leaderboard entries)
	var matchesList struct {
		OK      bool                 `json:"ok"`
		Matches []model.MatchSummary `json:"matches"`
	}
	getJSON(t, ts.URL+"/api/v1/matches", &matchesList)
	if len(matchesList.Matches) != 0 {
		t.Fatalf("expected clean zero cold-start matches, got %+v", matchesList)
	}

	var lbResp model.GlobalLeaderboardResponse
	getJSON(t, ts.URL+"/api/v1/leaderboard", &lbResp)
	if len(lbResp.Leaderboard) != 0 {
		t.Fatalf("expected clean zero cold-start leaderboard, got %d entries", len(lbResp.Leaderboard))
	}

	// 5. POST /api/v1/matches (sim driver for fast deterministic test) + WebSocket live stream
	createBody := `{
		"title": "Integration Grail Battle",
		"mode": "grail",
		"map_id": "llm-redteam",
		"token_budget": 10000,
		"execution_driver": "sim",
		"auto_start": true
	}`
	createResp, err := http.Post(ts.URL+"/api/v1/matches", "application/json", bytes.NewBufferString(createBody))
	if err != nil {
		t.Fatal(err)
	}
	var created model.MatchState
	_ = json.NewDecoder(createResp.Body).Decode(&created)
	_ = createResp.Body.Close()
	if createResp.StatusCode != http.StatusCreated || created.ID == "" {
		t.Fatalf("CreateMatch failed: status=%d id=%q", createResp.StatusCode, created.ID)
	}

	// Verify real created match immediately drives GET /api/v1/leaderboard and replay.html
	getJSON(t, ts.URL+"/api/v1/leaderboard", &lbResp)
	if len(lbResp.Leaderboard) != len(created.Seats) {
		t.Fatalf("expected %d real seats on leaderboard, got %d", len(created.Seats), len(lbResp.Leaderboard))
	}
	replayResp, err := http.Get(ts.URL + "/api/v1/matches/" + created.ID + "/replay.html")
	if err != nil {
		t.Fatal(err)
	}
	replayHTML, _ := io.ReadAll(replayResp.Body)
	_ = replayResp.Body.Close()
	if replayResp.StatusCode != http.StatusOK || !strings.Contains(string(replayHTML), "Integration Grail Battle") {
		t.Fatalf("real match replay.html failed: status=%d len=%d", replayResp.StatusCode, len(replayHTML))
	}

	// Connect WebSocket client to /api/v1/ws?match_id=<created.ID>
	wsURL := "ws" + strings.TrimPrefix(ts.URL, "http") + "/api/v1/ws?match_id=" + created.ID
	wsConn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("WebSocket dial failed: %v", err)
	}
	defer wsConn.Close()

	// First frame on WS must be immediate MATCH_STATE hydration
	_ = wsConn.SetReadDeadline(time.Now().Add(3 * time.Second))
	_, initMsg, err := wsConn.ReadMessage()
	if err != nil {
		t.Fatalf("failed reading initial WS frame: %v", err)
	}
	var initEnv model.EventEnvelope
	_ = json.Unmarshal(initMsg, &initEnv)
	if initEnv.Kind != model.KindMatchState || initEnv.MatchID != created.ID {
		t.Fatalf("expected initial WS frame MATCH_STATE for %s, got %+v", created.ID, initEnv)
	}

	// 6. POST /api/v1/internal/ebpf-ingest -> verify broadcast over WS
	ebpfPayload := `[{"match_id":"` + created.ID + `","probe":"sched_process_exec","vfx_type":"RCE_PARASITE_BREACH","source_seat_id":"seat-1","target_id":"target-grail","organ_layer":"code_organ","comm":"sh","parent_comm":"python3","cmdline":"/bin/sh -c cat /flag"}]`
	ingResp, err := http.Post(ts.URL+"/api/v1/internal/ebpf-ingest", "application/json", bytes.NewBufferString(ebpfPayload))
	if err != nil {
		t.Fatal(err)
	}
	_ = ingResp.Body.Close()
	if ingResp.StatusCode != http.StatusOK {
		t.Fatalf("ebpf-ingest returned %d", ingResp.StatusCode)
	}

	sawEBPF := false
	sawCameraCue := false
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) && (!sawEBPF || !sawCameraCue) {
		_ = wsConn.SetReadDeadline(time.Now().Add(1 * time.Second))
		_, raw, err := wsConn.ReadMessage()
		if err != nil {
			break
		}
		var env model.EventEnvelope
		if json.Unmarshal(raw, &env) == nil {
			if env.Kind == model.KindEBPFEvent {
				sawEBPF = true
			}
			if env.Kind == model.KindCameraCue {
				sawCameraCue = true
			}
		}
	}
	if !sawEBPF || !sawCameraCue {
		t.Fatalf("expected WS to broadcast EBPF_EVENT (%v) and CAMERA_CUE (%v)", sawEBPF, sawCameraCue)
	}

	// 7. Human Takeover intervene: possess + terminal_input + hint
	for _, body := range []string{
		`{"type":"possess","enabled":true}`,
		`{"type":"terminal_input","data":"id"}`,
		`{"type":"hint","prompt":"Attack /api/diagnostics/ping now!"}`,
	} {
		r, err := http.Post(ts.URL+"/api/v1/matches/"+created.ID+"/seats/seat-4/intervene", "application/json", bytes.NewBufferString(body))
		if err != nil {
			t.Fatal(err)
		}
		_ = r.Body.Close()
		if r.StatusCode != http.StatusOK {
			t.Fatalf("intervene %s failed: %d", body, r.StatusCode)
		}
	}

	// 8. Control stop match
	stopResp, err := http.Post(ts.URL+"/api/v1/matches/"+created.ID+"/control", "application/json", bytes.NewBufferString(`{"action":"stop"}`))
	if err != nil {
		t.Fatal(err)
	}
	_ = stopResp.Body.Close()
	if stopResp.StatusCode != http.StatusOK {
		t.Fatalf("stop match failed: %d", stopResp.StatusCode)
	}

	// 9. SPA fallback serves index.html for client routes like /lobby/grail
	spaResp, err := http.Get(ts.URL + "/lobby/grail")
	if err != nil {
		t.Fatal(err)
	}
	spaBody, _ := io.ReadAll(spaResp.Body)
	_ = spaResp.Body.Close()
	if spaResp.StatusCode != http.StatusOK || !strings.Contains(string(spaBody), "SPA_INDEX_OK") {
		t.Fatalf("SPA fallback failed: status=%d body=%s", spaResp.StatusCode, string(spaBody))
	}
}

func getJSON(t *testing.T, url string, dst any) {
	t.Helper()
	resp, err := http.Get(url)
	if err != nil {
		t.Fatalf("GET %s: %v", url, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(resp.Body)
		t.Fatalf("GET %s returned %d: %s", url, resp.StatusCode, string(raw))
	}
	if err := json.NewDecoder(resp.Body).Decode(dst); err != nil {
		t.Fatalf("decode %s: %v", url, err)
	}
}
