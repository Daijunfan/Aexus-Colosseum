package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"syscall"
	"time"

	"aexus.io/pitd/internal/api"
	"aexus.io/pitd/internal/armory"
	"aexus.io/pitd/internal/engine"
	"aexus.io/pitd/internal/gateway"
	"aexus.io/pitd/internal/runtime"
	"aexus.io/pitd/internal/ws"
)

func main() {
	defaultAddr := envOr("PIT_ADDR", ":18880")
	defaultArenaRoot := envOr("ARENA_ROOT", "/srv/arena")
	defaultWebDir := envOr("PIT_WEB_DIR", "")
	defaultGatewayHost := envOr("PIT_GATEWAY_HOST", "host.docker.internal")
	defaultWorkDir := envOr("PIT_WORK_DIR", filepath.Join(os.TempDir(), "pitd-runtime"))

	addr := flag.String("addr", defaultAddr, "HTTP & WebSocket listen address (e.g. :18880 or 127.0.0.1:18880)")
	arenaRoot := flag.String("arena-root", defaultArenaRoot, "Arena root containing catalog/catalog.json")
	webDir := flag.String("web-dir", defaultWebDir, "Static web-ui/dist directory for SPA hosting")
	gatewayHost := flag.String("gateway-host", defaultGatewayHost, "Hostname/IP reachable by Fighter containers for /llm-gateway")
	workDir := flag.String("work-dir", defaultWorkDir, "Runtime scratch directory for container workspaces")
	flag.Parse()

	resolvedWebDir := resolveWebDir(*webDir)
	gwPort := extractPort(*addr, 18880)

	arm := armory.NewRegistry(*arenaRoot)
	hub := ws.NewHub()
	drv := runtime.NewCompositeDriver(*workDir, nil)
	mgr := engine.NewManager(arm, hub, drv, gwPort, *gatewayHost)
	_ = mgr.EnableLedgerPersistence(filepath.Join(*workDir, "matches_ledger.json"))
	drv.SetCallbacks(mgr)

	gw := gateway.NewGateway(mgr)
	srv := api.NewServer(arm, mgr, hub, gw, resolvedWebDir)

	httpSrv := &http.Server{
		Addr:              *addr,
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	stopCh := make(chan os.Signal, 1)
	signal.Notify(stopCh, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		log.Printf("[pitd] Aexus Colosseum Core listening on %s (maps=%d, harnesses=%d, webDir=%q)",
			*addr, arm.MapCount(), arm.HarnessCount(), resolvedWebDir)
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("[pitd] listen error: %v", err)
		}
	}()

	<-stopCh
	log.Printf("[pitd] Shutting down gracefully & tearing down active match sandboxes...")
	mgr.Shutdown()

	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	_ = httpSrv.Shutdown(ctx)
	fmt.Println("[pitd] Shutdown complete.")
}

func resolveWebDir(explicit string) string {
	if explicit != "" {
		return explicit
	}
	candidates := []string{
		"/srv/arena/web-ui/dist",
		"../../web-ui/dist",
		"../web-ui/dist",
		"./web-ui/dist",
	}
	for _, c := range candidates {
		if info, err := os.Stat(c); err == nil && info.IsDir() {
			abs, err := filepath.Abs(c)
			if err == nil {
				return abs
			}
			return c
		}
	}
	return "../../web-ui/dist"
}

func extractPort(addr string, fallback int) int {
	_, portStr, err := net.SplitHostPort(addr)
	if err != nil {
		return fallback
	}
	p, err := strconv.Atoi(portStr)
	if err != nil || p <= 0 {
		return fallback
	}
	return p
}

func envOr(key, fb string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fb
}
