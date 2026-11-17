package replay

import (
	_ "embed"
	"encoding/json"
	"html"
	"strings"

	"aexus.io/pitd/internal/model"
)

//go:embed template.html
var replayHTMLTemplate string

// RenderHTML generates a standalone, zero-dependency, single-file 60fps HTML5 interactive replay player.
func RenderHTML(bundle model.ReplayBundle) ([]byte, error) {
	rawJSON, err := json.Marshal(bundle)
	if err != nil {
		return nil, err
	}
	// Escape </ sequences inside JSON strings so embedded exploit payloads never break <script> parsing.
	safeJSON := strings.ReplaceAll(string(rawJSON), "</", "<\\/")
	safeTitle := html.EscapeString(bundle.Match.Title)

	rendered := strings.ReplaceAll(replayHTMLTemplate, "__PIT_PAGE_TITLE__", safeTitle)
	rendered = strings.ReplaceAll(rendered, "__PIT_REPLAY_JSON__", safeJSON)
	return []byte(rendered), nil
}
