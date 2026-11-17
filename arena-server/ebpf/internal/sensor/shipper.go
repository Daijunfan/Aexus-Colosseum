package sensor

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"sync/atomic"
	"time"

	"aexus.colosseum/pit-ebpf-sensor/internal/model"
)

// ingestWireEnvelope includes top-level event fields, nested payload, and an events[] slice
// so pitd can decode single-event, envelope, or batch ingest schemas seamlessly.
type ingestWireEnvelope struct {
	model.EventEnvelope
	Events []model.EventEnvelope `json:"events"`
}

// Shipper streams EBPF_EVENT records asynchronously to pitd with <5ms localhost latency
// and bounded non-blocking retry.
type Shipper struct {
	targetURL string
	authToken string
	client    *http.Client
	queue     chan model.EventEnvelope

	shippedCount atomic.Uint64
	errorCount   atomic.Uint64
}

func NewShipper(targetURL, authToken string) *Shipper {
	if targetURL == "" {
		return nil
	}
	transport := &http.Transport{
		MaxIdleConns:        16,
		MaxIdleConnsPerHost: 16,
		IdleConnTimeout:     60 * time.Second,
		DisableCompression:  true,
	}
	return &Shipper{
		targetURL: targetURL,
		authToken: authToken,
		client: &http.Client{
			Transport: transport,
			Timeout:   1500 * time.Millisecond,
		},
		queue: make(chan model.EventEnvelope, 2048),
	}
}

func (s *Shipper) Start(ctx context.Context) {
	if s == nil {
		return
	}
	const workers = 4
	for i := 0; i < workers; i++ {
		go s.worker(ctx)
	}
}

// Enqueue submits an event without ever blocking the eBPF ringbuf reader.
func (s *Shipper) Enqueue(ev model.EventEnvelope) {
	if s == nil {
		return
	}
	select {
	case s.queue <- ev:
	default:
		s.errorCount.Add(1)
	}
}

func (s *Shipper) Stats() (shipped uint64, errs uint64) {
	if s == nil {
		return 0, 0
	}
	return s.shippedCount.Load(), s.errorCount.Load()
}

func (s *Shipper) worker(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case first := <-s.queue:
			// Opportunistically drain any queued bursts that arrived in the same microsecond
			batch := make([]model.EventEnvelope, 1, 16)
			batch[0] = first
		drain:
			for len(batch) < 16 {
				select {
				case next := <-s.queue:
					batch = append(batch, next)
				default:
					break drain
				}
			}
			s.sendWithRetry(ctx, batch)
		}
	}
}

func (s *Shipper) sendWithRetry(ctx context.Context, batch []model.EventEnvelope) {
	wire := ingestWireEnvelope{
		EventEnvelope: batch[len(batch)-1],
		Events:        batch,
	}
	body, err := json.Marshal(wire)
	if err != nil {
		s.errorCount.Add(uint64(len(batch)))
		return
	}

	backoffs := []time.Duration{0, 25 * time.Millisecond, 75 * time.Millisecond}
	for _, wait := range backoffs {
		if wait > 0 {
			select {
			case <-ctx.Done():
				return
			case <-time.After(wait):
			}
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.targetURL, bytes.NewReader(body))
		if err != nil {
			break
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Pit-Sensor", "pit-ebpf-sensor")
		if s.authToken != "" {
			req.Header.Set("Authorization", "Bearer "+s.authToken)
		}
		resp, err := s.client.Do(req)
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				s.shippedCount.Add(uint64(len(batch)))
				return
			}
		}
	}
	s.errorCount.Add(uint64(len(batch)))
}
