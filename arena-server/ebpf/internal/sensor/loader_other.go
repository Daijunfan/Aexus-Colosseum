//go:build !linux

package sensor

import (
	"context"
	"fmt"
	"runtime"
)

func (e *Engine) runKernelSensor(_ context.Context) error {
	return fmt.Errorf("kernel eBPF probes require Linux (current OS: %s/%s); pass --replay-demo for local telemetry simulation",
		runtime.GOOS, runtime.GOARCH)
}
