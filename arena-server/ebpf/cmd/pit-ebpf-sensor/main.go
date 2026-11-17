package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"aexus.colosseum/pit-ebpf-sensor/internal/sensor"
)

func main() {
	var (
		listenAddr       = flag.String("listen", envOr("PIT_EBPF_LISTEN", "127.0.0.1:18882"), "HTTP status & SSE events listen address (empty to disable)")
		pitdURL          = flag.String("pitd-url", envOr("PIT_INGEST_URL", ""), "pitd ingest HTTP endpoint (e.g. http://127.0.0.1:18880/api/v1/internal/ebpf-ingest)")
		pitdToken        = flag.String("pitd-token", envOr("PIT_INTERNAL_TOKEN", ""), "Optional Bearer token for pitd internal ingest")
		dockerSocket     = flag.String("docker-sock", envOr("DOCKER_SOCK", "/var/run/docker.sock"), "Docker Engine Unix socket path")
		pollMs           = flag.Int("poll-ms", 1200, "Docker container discovery poll interval in milliseconds")
		dedupMs          = flag.Int("dedup-ms", 120, "Burst deduplication window in milliseconds (0 to disable)")
		includeUnlabeled = flag.Bool("include-unlabeled", false, "Track all running Docker containers even without pit.* labels or arena naming")
		replayDemo       = flag.Bool("replay-demo", false, "Run deterministic cross-platform replay simulation (for macOS/non-root testing)")
		replayIntervalMs = flag.Int("replay-interval-ms", 650, "Interval between replay demo events in milliseconds")
		replayOnce       = flag.Bool("replay-once", false, "Emit one 9-stage replay sequence and exit cleanly (with --replay-demo)")
	)
	flag.Parse()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	engine := sensor.NewEngine(sensor.Config{
		DockerSocket:     *dockerSocket,
		PollInterval:     time.Duration(*pollMs) * time.Millisecond,
		IncludeUnlabeled: *includeUnlabeled,
		PitdURL:          *pitdURL,
		PitdToken:        *pitdToken,
		ListenAddr:       *listenAddr,
		ReplayDemo:       *replayDemo,
		ReplayInterval:   time.Duration(*replayIntervalMs) * time.Millisecond,
		ReplayLoop:       !*replayOnce,
		DedupWindow:      time.Duration(*dedupMs) * time.Millisecond,
		Stdout:           os.Stdout,
		Stderr:           os.Stderr,
	})

	if *listenAddr != "" {
		boundAddr, err := engine.StartHTTPServer(ctx, *listenAddr)
		if err != nil {
			fmt.Fprintf(os.Stderr, "[pit-ebpf-sensor] warning: HTTP status server failed on %s: %v\n", *listenAddr, err)
		} else {
			fmt.Fprintf(os.Stderr, "[pit-ebpf-sensor] HTTP status & SSE stream listening on http://%s/status\n", boundAddr)
		}
	}

	if err := engine.Run(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "[pit-ebpf-sensor] fatal: %v\n", err)
		os.Exit(1)
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
