package armory

import (
	"os"
	"path/filepath"
	"testing"

	"aexus.io/pitd/internal/model"
)

func TestArmoryStandaloneAndMerge(t *testing.T) {
	reg := NewRegistry("/nonexistent/arena-root")
	snap := reg.Snapshot()

	if !snap.OK {
		t.Fatalf("expected ArmoryResponse.OK = true")
	}
	if len(snap.Maps) < 100 {
		t.Fatalf("expected 100+ maps in standalone embedded catalog, got %d", len(snap.Maps))
	}

	requiredMaps := []string{
		"llm-redteam",
		"juice-shop",
		"dvwa",
		"fastjson",
		"comfyui",
		"struts2",
		"httpd-cve-2021-41773",
		"weak-creds",
	}
	for _, id := range requiredMaps {
		m, ok := reg.FindMap(id)
		if !ok {
			t.Fatalf("expected map %q to resolve in armory", id)
		}
		if len(m.Organs) != 5 {
			t.Fatalf("expected map %q to have 5 Organ Layers, got %d", id, len(m.Organs))
		}
		expectedLayers := []model.OrganLayer{
			model.OrganPortGate,
			model.OrganRouteVessel,
			model.OrganCodeOrgan,
			model.OrganDBVault,
			model.OrganFlagHeart,
		}
		for i, want := range expectedLayers {
			if m.Organs[i].Layer != want {
				t.Fatalf("map %q organ[%d] = %q, want %q", id, i, m.Organs[i].Layer, want)
			}
		}
	}

	requiredHarnesses := []string{
		"strix", "shannon", "pentagi", "pentestgpt", "redamon", "claude-code", "codex", "custom",
	}
	for _, hid := range requiredHarnesses {
		h, ok := reg.FindHarness(hid)
		if !ok {
			t.Fatalf("missing required harness %q", hid)
		}
		for _, envKey := range []string{
			"OPENAI_BASE_URL", "ANTHROPIC_BASE_URL", "OPENAI_API_KEY", "ANTHROPIC_API_KEY",
			"PIT_TOKEN_BUDGET", "PIT_TARGETS_JSON", "PIT_SUBMIT_URL", "PIT_DEFENSE_REPO",
		} {
			if h.EnvTemplate[envKey] == "" {
				t.Fatalf("harness %q missing env template var %q", hid, envKey)
			}
		}
	}

	// Test dynamic merge from --arena-root/catalog/catalog.json
	tmp := t.TempDir()
	catDir := filepath.Join(tmp, "catalog")
	if err := os.MkdirAll(catDir, 0o755); err != nil {
		t.Fatal(err)
	}
	customCatalog := `{"categories":[{"id":"web","name":"Web"}],"labs":[{"id":"custom-zero-day-01","name":"Custom Zero Day","category":"cve","difficulty":5,"summary":"Dynamic lab from /srv/arena"}]}`
	if err := os.WriteFile(filepath.Join(catDir, "catalog.json"), []byte(customCatalog), 0o644); err != nil {
		t.Fatal(err)
	}

	reg2 := NewRegistry(tmp)
	if m, ok := reg2.FindMap("custom-zero-day-01"); !ok || m.ID != "custom-zero-day-01" {
		t.Fatalf("expected dynamic map custom-zero-day-01 from disk catalog, got %+v (ok=%v)", m, ok)
	}
}
