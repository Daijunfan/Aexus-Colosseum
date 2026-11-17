package gateway

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"aexus.io/pitd/internal/armory"
	"aexus.io/pitd/internal/engine"
	"aexus.io/pitd/internal/model"
	"aexus.io/pitd/internal/ws"
)

func TestGatewayMeteringAndExact402OutOfManaCutoff(t *testing.T) {
	arm := armory.NewRegistry("/nonexistent")
	hub := ws.NewHub()
	mgr := engine.NewManager(arm, hub, nil, 18880, "127.0.0.1")
	defer mgr.Shutdown()

	autoStart := false
	match, err := mgr.CreateMatch(model.CreateMatchRequest{
		Title:       "Mana Cutoff Test",
		Mode:        model.ModeGrail,
		MapID:       "llm-redteam",
		TokenBudget: 1500, // Tight 1,500 token budget
		AutoStart:   &autoStart,
		Seats: []model.SeatSpec{
			{ID: "seat-1", Name: "Strix", Kind: model.SeatHarness, HarnessID: "strix", Model: "claude-sonnet-4-6"},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	seatTok := match.Seats[0].SeatToken

	gw := NewGateway(mgr)
	mux := http.NewServeMux()
	mux.HandleFunc("POST /llm-gateway/{seat_token}/v1/chat/completions", gw.HandleOpenAIChat)
	mux.HandleFunc("POST /llm-gateway/{seat_token}/anthropic/v1/messages", gw.HandleAnthropicMessages)
	srv := httptest.NewServer(mux)
	defer srv.Close()

	// Call 1: Burn exact 1,000 tokens via OpenAI endpoint -> 200 OK (500 remaining)
	body1 := `{"model":"claude-sonnet-4-6","messages":[{"role":"user","content":"Recon target"}]}`
	req1, _ := http.NewRequest(http.MethodPost, srv.URL+"/llm-gateway/"+seatTok+"/v1/chat/completions", strings.NewReader(body1))
	req1.Header.Set("Content-Type", "application/json")
	req1.Header.Set("X-Pit-Token-Cost", "1000")
	resp1, err := http.DefaultClient.Do(req1)
	if err != nil {
		t.Fatal(err)
	}
	_ = resp1.Body.Close()
	if resp1.StatusCode != http.StatusOK {
		t.Fatalf("expected Call 1 HTTP 200, got %d", resp1.StatusCode)
	}

	// Call 2: Burn 600 tokens via Anthropic endpoint -> hits 1,500 cap (exhausts pool!)
	body2 := `{"model":"claude-sonnet-4-6","max_tokens":256,"messages":[{"role":"user","content":"Exploit RCE"}]}`
	req2, _ := http.NewRequest(http.MethodPost, srv.URL+"/llm-gateway/"+seatTok+"/anthropic/v1/messages", strings.NewReader(body2))
	req2.Header.Set("Content-Type", "application/json")
	req2.Header.Set("X-Pit-Token-Cost", "600")
	resp2, err := http.DefaultClient.Do(req2)
	if err != nil {
		t.Fatal(err)
	}
	_ = resp2.Body.Close()
	if resp2.StatusCode != http.StatusOK {
		t.Fatalf("expected Call 2 HTTP 200 (exhausting remaining 500 tokens), got %d", resp2.StatusCode)
	}

	// Call 3: Seat is now at 1,500 / 1,500 tokens -> MUST immediately return HTTP 402 Payment Required (OUT_OF_MANA)!
	req3, _ := http.NewRequest(http.MethodPost, srv.URL+"/llm-gateway/"+seatTok+"/v1/chat/completions", strings.NewReader(body1))
	req3.Header.Set("Content-Type", "application/json")
	resp3, err := http.DefaultClient.Do(req3)
	if err != nil {
		t.Fatal(err)
	}
	raw3, _ := io.ReadAll(resp3.Body)
	_ = resp3.Body.Close()

	if resp3.StatusCode != http.StatusPaymentRequired {
		t.Fatalf("expected HTTP 402 Payment Required on exhausted Mana pool, got %d (%s)", resp3.StatusCode, string(raw3))
	}
	if !strings.Contains(string(raw3), "OUT_OF_MANA") {
		t.Fatalf("expected OUT_OF_MANA error payload, got %s", string(raw3))
	}

	snap, _ := mgr.GetMatch(match.ID)
	if !snap.Seats[0].ManaExhausted || snap.Seats[0].TokensUsed != 1500 || snap.Seats[0].Status != "out_of_mana" {
		t.Fatalf("expected seat ManaExhausted=true TokensUsed=1500, got %+v", snap.Seats[0])
	}
}

func TestGatewayStreamingSSEAndUpstreamProxy(t *testing.T) {
	// Mock real upstream OpenAI-compatible server
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer sk-mock-upstream" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"id":     "chatcmpl-upstream-1",
			"object": "chat.completion",
			"choices": []map[string]any{
				{"index": 0, "message": map[string]any{"role": "assistant", "content": "Upstream exploit ready", "reasoning_content": "Checked server.py:92"}},
			},
			"usage": map[string]any{
				"prompt_tokens":     310,
				"completion_tokens": 190,
				"total_tokens":      500,
			},
		})
	}))
	defer upstream.Close()

	arm := armory.NewRegistry("/nonexistent")
	hub := ws.NewHub()
	mgr := engine.NewManager(arm, hub, nil, 18880, "127.0.0.1")
	defer mgr.Shutdown()

	autoStart := false
	match, err := mgr.CreateMatch(model.CreateMatchRequest{
		Title:       "Upstream Proxy Test",
		Mode:        model.ModeAWD,
		MapID:       "dvwa",
		TokenBudget: 100_000,
		AutoStart:   &autoStart,
		UpstreamLLM: model.UpstreamLLMConfig{
			BaseURL:      upstream.URL + "/v1",
			APIKey:       "sk-mock-upstream",
			DefaultModel: "gpt-5",
		},
		Seats: []model.SeatSpec{
			{ID: "seat-1", Name: "Shannon", Kind: model.SeatHarness, HarnessID: "shannon"},
			{ID: "seat-2", Name: "Strix", Kind: model.SeatHarness, HarnessID: "strix"},
		},
	})
	if err != nil {
		t.Fatal(err)
	}

	gw := NewGateway(mgr)
	mux := http.NewServeMux()
	mux.HandleFunc("POST /llm-gateway/{seat_token}/v1/chat/completions", gw.HandleOpenAIChat)
	srv := httptest.NewServer(mux)
	defer srv.Close()

	resp, err := http.Post(
		srv.URL+"/llm-gateway/"+match.Seats[0].SeatToken+"/v1/chat/completions",
		"application/json",
		bytes.NewBufferString(`{"model":"gpt-5","messages":[{"role":"user","content":"Audit source"}]}`),
	)
	if err != nil {
		t.Fatal(err)
	}
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 from upstream proxy, got %d", resp.StatusCode)
	}

	after, _ := mgr.GetMatch(match.ID)
	if after.Seats[0].TokensUsed != 500 {
		t.Fatalf("expected exact 500 upstream tokens metered, got %d", after.Seats[0].TokensUsed)
	}

	// Also verify keyless SSE streaming
	matchKeyless, _ := mgr.CreateMatch(model.CreateMatchRequest{
		Title:       "SSE Stream Test",
		Mode:        model.ModeGrail,
		TokenBudget: 50_000,
		AutoStart:   &autoStart,
	})
	sseResp, err := http.Post(
		srv.URL+"/llm-gateway/"+matchKeyless.Seats[0].SeatToken+"/v1/chat/completions",
		"application/json",
		bytes.NewBufferString(`{"model":"claude-sonnet-4-6","stream":true,"messages":[{"role":"user","content":"Stream plan"}]}`),
	)
	if err != nil {
		t.Fatal(err)
	}
	sseBytes, _ := io.ReadAll(sseResp.Body)
	_ = sseResp.Body.Close()
	if !strings.Contains(string(sseBytes), "data: [DONE]") {
		t.Fatalf("expected SSE [DONE] marker, got %s", string(sseBytes))
	}
}
