package sensor

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// StartHTTPServer exposes /status, /health, /events (JSON & SSE), and /events/stream.
func (e *Engine) StartHTTPServer(ctx context.Context, listenAddr string) (string, error) {
	if listenAddr == "" {
		return "", nil
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/status", e.handleStatus)
	mux.HandleFunc("/health", e.handleStatus)
	mux.HandleFunc("/events", e.handleEvents)
	mux.HandleFunc("/events/stream", e.handleEventsSSE)

	ln, err := net.Listen("tcp", listenAddr)
	if err != nil {
		return "", err
	}

	srv := &http.Server{
		Handler:           withCORS(mux),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		<-ctx.Done()
		shutCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutCtx)
	}()

	go func() {
		_ = srv.Serve(ln)
	}()

	return ln.Addr().String(), nil
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Accept, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (e *Engine) handleStatus(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(e.Status())
}

func (e *Engine) handleEvents(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	accept := r.Header.Get("Accept")
	if strings.Contains(accept, "text/event-stream") ||
		q.Get("stream") == "1" || q.Get("stream") == "true" || q.Get("sse") == "1" {
		e.handleEventsSSE(w, r)
		return
	}

	limit := 100
	if rawLim := q.Get("limit"); rawLim != "" {
		if n, err := strconv.Atoi(rawLim); err == nil && n > 0 && n <= 1000 {
			limit = n
		}
	}
	recent := e.RecentEvents(limit)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"ok":     true,
		"count":  len(recent),
		"events": recent,
	})
}

func (e *Engine) handleEventsSSE(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.WriteHeader(http.StatusOK)
	flusher.Flush()

	if replayN, err := strconv.Atoi(r.URL.Query().Get("replay")); err == nil && replayN > 0 {
		for _, ev := range e.RecentEvents(replayN) {
			if b, err := json.Marshal(ev); err == nil {
				_, _ = fmt.Fprintf(w, "event: EBPF_EVENT\ndata: %s\n\n", b)
			}
		}
		flusher.Flush()
	}

	subCh, unsub := e.Subscribe()
	defer unsub()

	heartbeat := time.NewTicker(15 * time.Second)
	defer heartbeat.Stop()

	for {
		select {
		case <-r.Context().Done():
			return
		case <-heartbeat.C:
			_, _ = fmt.Fprint(w, ": ping\n\n")
			flusher.Flush()
		case ev, open := <-subCh:
			if !open {
				return
			}
			b, err := json.Marshal(ev)
			if err != nil {
				continue
			}
			_, _ = fmt.Fprintf(w, "event: EBPF_EVENT\ndata: %s\n\n", b)
			flusher.Flush()
		}
	}
}
