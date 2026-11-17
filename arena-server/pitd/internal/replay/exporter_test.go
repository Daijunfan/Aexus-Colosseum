package replay

import (
	"strings"
	"testing"

	"aexus.io/pitd/internal/model"
)

func TestRenderHTMLIntegrityAndScriptEscaping(t *testing.T) {
	bundle := model.ReplayBundle{
		OK:      true,
		Format:  "aexus.pitreplay.v1",
		Version: "1.0.0",
		Match: model.MatchState{
			ID:          "m-test-replay",
			Title:       "Replay Escape Test <script>alert(1)</script>",
			Mode:        model.ModeGrail,
			TokenBudget: 1_000_000,
			Seats: []model.SeatState{
				{ID: "seat-1", Name: "Strix", TeamColor: "#FF5A36", Score: 500},
			},
		},
		Timeline: []model.EventEnvelope{
			{
				Seq:     1,
				TsMs:    1000,
				MatchID: "m-test-replay",
				Kind:    model.KindEBPFEvent,
				Payload: model.EBPFEventPayload{
					Probe:            "uprobe/SSL_write",
					VFXType:          model.VFXSSLCleartextIntercept,
					CleartextPayload: "POST /xss </script><script>evil()</script>",
				},
			},
		},
	}

	out, err := RenderHTML(bundle)
	if err != nil {
		t.Fatalf("RenderHTML failed: %v", err)
	}
	htmlStr := string(out)

	if !strings.Contains(htmlStr, "<!DOCTYPE html>") {
		t.Fatalf("missing DOCTYPE")
	}
	if !strings.Contains(htmlStr, `id="pit-replay-data"`) {
		t.Fatalf("missing embedded pit-replay-data JSON script tag")
	}
	// Ensure zero external HTTP CDN dependencies
	if strings.Contains(htmlStr, `src="http`) || strings.Contains(htmlStr, `href="http`) {
		t.Fatalf("standalone .pitreplay.html must have zero external HTTP asset dependencies")
	}
	// Ensure malicious </script> inside JSON payload was safely escaped to <\/script>
	if strings.Contains(htmlStr, "</script><script>evil()") {
		t.Fatalf("dangerous </script> inside payload was NOT escaped")
	}
	if !strings.Contains(htmlStr, "Space") || !strings.Contains(htmlStr, "xrayVisor") {
		t.Fatalf("missing Space-key X-Ray Hacker Visor support")
	}
}
