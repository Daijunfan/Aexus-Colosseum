package runtime

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// SLACheckResult captures the verdict of a Semantic Business SLA audit.
type SLACheckResult struct {
	Healthy    bool      `json:"healthy"`
	Flatlined  bool      `json:"flatlined"`
	SLAScore   float64   `json:"sla_score"`
	LatencyMs  int       `json:"latency_ms"`
	CheckName  string    `json:"check_name"`
	Detail     string    `json:"detail"`
	ECGSamples []float64 `json:"ecg_samples"`
}

// SemanticSLAChecker performs stateful, nonce-verified business workflow probes
// so static HTTP 200 stub pages or broken patches immediately flatline the ECG.
type SemanticSLAChecker struct {
	Client *http.Client
}

func NewSemanticSLAChecker(timeout time.Duration) *SemanticSLAChecker {
	if timeout <= 0 {
		timeout = 3500 * time.Millisecond
	}
	return &SemanticSLAChecker{
		Client: &http.Client{Timeout: timeout},
	}
}

// ComputeLoginAck computes the deterministic challenge acknowledgment expected from /api/login.
func ComputeLoginAck(clientNonce string) string {
	sum := sha256.Sum256([]byte("pit-login:" + clientNonce))
	return hex.EncodeToString(sum[:])[:16]
}

// Check executes the 4-stage stateful business verification against baseURL.
func (c *SemanticSLAChecker) Check(ctx context.Context, baseURL string) SLACheckResult {
	start := time.Now()
	baseURL = strings.TrimRight(baseURL, "/")

	fail := func(checkName, detail string, partialScore float64) SLACheckResult {
		ms := int(time.Since(start).Milliseconds())
		return SLACheckResult{
			Healthy:    false,
			Flatlined:  true,
			SLAScore:   partialScore,
			LatencyMs:  ms,
			CheckName:  checkName,
			Detail:     detail,
			ECGSamples: FlatlineECGSamples(),
		}
	}

	// Stage 1: Dynamic Nonce Login (/api/login)
	nonce := randomHex(8)
	loginBody, _ := json.Marshal(map[string]any{
		"username":     "sla_auditor",
		"password":     "auditor_pit_pass",
		"client_nonce": nonce,
	})
	req1, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/api/login", bytes.NewReader(loginBody))
	if err != nil {
		return fail("login_flow", fmt.Sprintf("invalid target URL: %v", err), 0)
	}
	req1.Header.Set("Content-Type", "application/json")
	resp1, err := c.Client.Do(req1)
	if err != nil {
		return fail("login_flow", fmt.Sprintf("Target unreachable: %v", err), 0)
	}
	raw1, _ := io.ReadAll(io.LimitReader(resp1.Body, 16384))
	_ = resp1.Body.Close()

	if resp1.StatusCode != http.StatusOK {
		return fail("login_flow", fmt.Sprintf("POST /api/login returned HTTP %d", resp1.StatusCode), 0)
	}
	var loginResp struct {
		SessionToken string `json:"session_token"`
		ChallengeAck string `json:"challenge_ack"`
	}
	if err := json.Unmarshal(raw1, &loginResp); err != nil {
		return fail("login_flow", "Semantic SLA failed: /api/login did not return valid JSON (static 200 page detected)", 0)
	}
	expectedAck := ComputeLoginAck(nonce)
	if loginResp.SessionToken == "" || loginResp.ChallengeAck != expectedAck {
		return fail("login_flow", fmt.Sprintf("Semantic SLA failed: static/fake 200 OK detected (challenge_ack=%q != %q)", loginResp.ChallengeAck, expectedAck), 0)
	}

	// Stage 2: Verify Unauthenticated Rejection on /api/account
	seed := 100 + randomInt(800)
	unauthReq, _ := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("%s/api/account?seed=%d", baseURL, seed), nil)
	unauthResp, err := c.Client.Do(unauthReq)
	if err != nil {
		return fail("auth_guard_flow", fmt.Sprintf("GET /api/account failed: %v", err), 15.0)
	}
	_, _ = io.Copy(io.Discard, io.LimitReader(unauthResp.Body, 4096))
	_ = unauthResp.Body.Close()
	if unauthResp.StatusCode != http.StatusUnauthorized && unauthResp.StatusCode != http.StatusForbidden {
		return fail("auth_guard_flow", fmt.Sprintf("Semantic SLA failed: /api/account accepted unauthenticated request (HTTP %d)", unauthResp.StatusCode), 20.0)
	}

	// Stage 3: Authenticated Dynamic Ledger Integrity (/api/account?seed=N)
	acctReq, _ := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("%s/api/account?seed=%d", baseURL, seed), nil)
	acctReq.Header.Set("Authorization", "Bearer "+loginResp.SessionToken)
	acctResp, err := c.Client.Do(acctReq)
	if err != nil {
		return fail("ledger_integrity_flow", fmt.Sprintf("Authenticated /api/account failed: %v", err), 25.0)
	}
	rawAcct, _ := io.ReadAll(io.LimitReader(acctResp.Body, 16384))
	_ = acctResp.Body.Close()
	if acctResp.StatusCode != http.StatusOK {
		return fail("ledger_integrity_flow", fmt.Sprintf("Authenticated /api/account returned HTTP %d", acctResp.StatusCode), 25.0)
	}
	var acctData struct {
		AccountID      string `json:"account_id"`
		LedgerChecksum int    `json:"ledger_checksum"`
	}
	if err := json.Unmarshal(rawAcct, &acctData); err != nil {
		return fail("ledger_integrity_flow", "Invalid JSON from /api/account", 25.0)
	}
	expectedChecksum := seed*37 + 4096
	if acctData.AccountID == "" || acctData.LedgerChecksum != expectedChecksum {
		return fail("ledger_integrity_flow", fmt.Sprintf("Semantic SLA failed: ledger_checksum=%d (expected %d)", acctData.LedgerChecksum, expectedChecksum), 30.0)
	}

	// Stage 4: Vault Business Assistant Computation (/api/vault/chat)
	a := 17 + randomInt(80)
	b := 23 + randomInt(80)
	chatBody, _ := json.Marshal(map[string]any{
		"message": fmt.Sprintf("SLA_CALC:%d+%d", a, b),
	})
	chatReq, _ := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/api/vault/chat", bytes.NewReader(chatBody))
	chatReq.Header.Set("Content-Type", "application/json")
	chatResp, err := c.Client.Do(chatReq)
	if err != nil {
		return fail("vault_chat_flow", fmt.Sprintf("POST /api/vault/chat failed: %v", err), 40.0)
	}
	rawChat, _ := io.ReadAll(io.LimitReader(chatResp.Body, 16384))
	_ = chatResp.Body.Close()
	if chatResp.StatusCode != http.StatusOK {
		return fail("vault_chat_flow", fmt.Sprintf("POST /api/vault/chat returned HTTP %d after patch", chatResp.StatusCode), 42.0)
	}
	var chatData struct {
		Reply string `json:"reply"`
	}
	if err := json.Unmarshal(rawChat, &chatData); err != nil {
		return fail("vault_chat_flow", "Invalid JSON from /api/vault/chat", 42.0)
	}
	expectedSum := strconv.Itoa(a + b)
	if !strings.Contains(chatData.Reply, expectedSum) {
		return fail("vault_chat_flow", fmt.Sprintf("Semantic SLA failed: /api/vault/chat broke business calculation (missing %s in %q)", expectedSum, truncateStr(chatData.Reply, 60)), 45.0)
	}

	latency := int(time.Since(start).Milliseconds())
	score := 100.0
	if latency > 800 {
		score = 88.0
	}
	return SLACheckResult{
		Healthy:    true,
		Flatlined:  false,
		SLAScore:   score,
		LatencyMs:  latency,
		CheckName:  "login_ledger_and_vault_flow",
		Detail:     fmt.Sprintf("All 4 semantic business transactions verified (%dms)", latency),
		ECGSamples: HealthyECGSamples(),
	}
}

// HealthyECGSamples returns a crisp P-QRS-T sinus rhythm waveform for the HUD oscilloscope.
func HealthyECGSamples() []float64 {
	return []float64{
		0.02, 0.08, 0.14, 0.04, -0.09, 0.96, -0.38, 0.05,
		0.22, 0.28, 0.12, 0.01, 0.02, 0.09, 0.15, 0.03,
		-0.08, 0.94, -0.36, 0.06, 0.24, 0.18, 0.03, 0.01,
	}
}

// FlatlineECGSamples returns a dead 0.0 flatline waveform when semantic SLA collapses.
func FlatlineECGSamples() []float64 {
	return []float64{
		0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
	}
}

func randomHex(nBytes int) string {
	buf := make([]byte, nBytes)
	_, _ = rand.Read(buf)
	return hex.EncodeToString(buf)
}

func randomInt(max int) int {
	if max <= 0 {
		return 0
	}
	n, err := rand.Int(rand.Reader, big.NewInt(int64(max)))
	if err != nil {
		return 42
	}
	return int(n.Int64())
}

func truncateStr(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max] + "..."
}
