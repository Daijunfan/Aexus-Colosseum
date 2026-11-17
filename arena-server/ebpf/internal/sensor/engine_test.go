package sensor

import (
	"bufio"
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"aexus.colosseum/pit-ebpf-sensor/internal/model"
)

func TestDecodeRawKernelEventBinaryLayout(t *testing.T) {
	buf := make([]byte, model.RawEventByteSize)
	le := binary.LittleEndian

	le.PutUint64(buf[0:8], 987654321)
	le.PutUint64(buf[8:16], 9176)
	le.PutUint32(buf[16:20], 4182)
	le.PutUint32(buf[20:24], 4182)
	le.PutUint32(buf[24:28], 33)
	le.PutUint32(buf[28:32], 3910)
	buf[44], buf[45], buf[46], buf[47] = 172, 28, 0, 50
	le.PutUint16(buf[48:50], 8080)
	payload := []byte("GET /flag HTTP/1.1\r\n")
	le.PutUint16(buf[50:52], uint16(len(payload)))
	buf[52] = model.RawEventExecve
	buf[54] = 3
	copy(buf[56:72], "sh\x00")
	copy(buf[72:88], "python3\x00")
	copy(buf[88:280], "/bin/sh\x00")
	copy(buf[280:344], "/bin/sh\x00")
	copy(buf[344:408], "-c\x00")
	copy(buf[408:536], "cat /flag\x00")
	copy(buf[664:], payload)
	le.PutUint64(buf[1176:1184], 184250)

	ev, err := model.DecodeRawKernelEvent(buf)
	if err != nil {
		t.Fatalf("DecodeRawKernelEvent failed: %v", err)
	}
	if ev.CgroupID != 9176 || ev.PID != 4182 || ev.PPID != 3910 || ev.UID != 33 || ev.DurationNs != 184250 {
		t.Fatalf("unexpected header fields: %+v", ev)
	}
	if ev.DstIP != "172.28.0.50" || ev.DstPort != 8080 {
		t.Fatalf("unexpected socket fields: ip=%s port=%d", ev.DstIP, ev.DstPort)
	}
	if ev.Comm != "sh" || ev.ParentComm != "python3" || ev.Cmdline() != "/bin/sh -c cat /flag" {
		t.Fatalf("unexpected strings: comm=%q parent=%q cmd=%q", ev.Comm, ev.ParentComm, ev.Cmdline())
	}
}

func TestReplayPipelineStatusSSEAndPitdShipper(t *testing.T) {
	var (
		ingestedMu sync.Mutex
		ingested   []model.EventEnvelope
	)
	pitdSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Events []model.EventEnvelope `json:"events"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		ingestedMu.Lock()
		ingested = append(ingested, body.Events...)
		ingestedMu.Unlock()
		w.WriteHeader(http.StatusOK)
	}))
	defer pitdSrv.Close()

	var stdoutBuf bytes.Buffer
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	engine := NewEngine(Config{
		PitdURL:        pitdSrv.URL,
		ReplayDemo:     true,
		ReplayInterval: 5 * time.Millisecond,
		ReplayLoop:     false,
		DedupWindow:    0,
		Stdout:         &stdoutBuf,
		Stderr:         &bytes.Buffer{},
	})

	addr, err := engine.StartHTTPServer(ctx, "127.0.0.1:0")
	if err != nil {
		t.Fatalf("StartHTTPServer failed: %v", err)
	}

	if err := engine.Run(ctx); err != nil {
		t.Fatalf("Run replay failed: %v", err)
	}

	// Wait briefly for async shipper flush
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		ingestedMu.Lock()
		n := len(ingested)
		ingestedMu.Unlock()
		if n >= 9 {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}

	ingestedMu.Lock()
	gotCount := len(ingested)
	ingestedMu.Unlock()
	if gotCount != 9 {
		t.Fatalf("expected all 9 VFX stages shipped to pitd, got %d", gotCount)
	}

	// Verify /status endpoint
	resp, err := http.Get("http://" + addr + "/status")
	if err != nil {
		t.Fatalf("GET /status failed: %v", err)
	}
	defer resp.Body.Close()
	var st model.SensorStatus
	if err := json.NewDecoder(resp.Body).Decode(&st); err != nil {
		t.Fatalf("decode /status failed: %v", err)
	}
	if !st.OK || st.Mode != "replay_sim" || st.EventsCaptured != 9 || st.TrackedContainers != 2 {
		t.Fatalf("unexpected /status payload: %+v", st)
	}

	// Verify /events SSE replay stream
	sseCtx, sseCancel := context.WithTimeout(ctx, 500*time.Millisecond)
	defer sseCancel()
	req, _ := http.NewRequestWithContext(sseCtx, http.MethodGet, "http://"+addr+"/events?stream=1&replay=3", nil)
	sseResp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("GET /events SSE failed: %v", err)
	}
	defer sseResp.Body.Close()
	scanner := bufio.NewScanner(sseResp.Body)
	seenDataLines := 0
	for scanner.Scan() {
		if strings.HasPrefix(scanner.Text(), "data: ") {
			seenDataLines++
			if seenDataLines >= 3 {
				break
			}
		}
	}
	if seenDataLines < 3 {
		t.Fatalf("expected >=3 SSE data events, got %d", seenDataLines)
	}
}
