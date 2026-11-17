package ws

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"aexus.io/pitd/internal/model"
	"github.com/gorilla/websocket"
)

const (
	writeWait  = 8 * time.Second
	pongWait   = 60 * time.Second
	pingPeriod = 25 * time.Second
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 8192,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type client struct {
	hub     *Hub
	conn    *websocket.Conn
	matchID string // "" or "*" means receive all matches
	send    chan []byte
}

// InitialSnapshotProvider returns initial envelopes sent to a newly connected client.
type InitialSnapshotProvider func(matchID string) []model.EventEnvelope

// Hub manages concurrent WebSocket subscribers with non-blocking fan-out.
type Hub struct {
	mu      sync.RWMutex
	clients map[*client]struct{}
}

func NewHub() *Hub {
	return &Hub{
		clients: make(map[*client]struct{}),
	}
}

func (h *Hub) Broadcast(env model.EventEnvelope) {
	raw, err := json.Marshal(env)
	if err != nil {
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()

	for c := range h.clients {
		if c.matchID != "" && c.matchID != "*" && c.matchID != env.MatchID {
			continue
		}
		select {
		case c.send <- raw:
		default:
			// Drop oldest frame if client buffer is saturated so slow viewers never stall combat.
			select {
			case <-c.send:
			default:
			}
			select {
			case c.send <- raw:
			default:
			}
		}
	}
}

func (h *Hub) ClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

func (h *Hub) ServeWS(w http.ResponseWriter, r *http.Request, initProvider InitialSnapshotProvider) {
	matchID := r.URL.Query().Get("match_id")
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	c := &client{
		hub:     h,
		conn:    conn,
		matchID: matchID,
		send:    make(chan []byte, 256),
	}

	h.mu.Lock()
	h.clients[c] = struct{}{}
	h.mu.Unlock()

	if initProvider != nil {
		for _, env := range initProvider(matchID) {
			if raw, err := json.Marshal(env); err == nil {
				select {
				case c.send <- raw:
				default:
				}
			}
		}
	}

	go c.writePump()
	go c.readPump()
}

func (c *client) remove() {
	c.hub.mu.Lock()
	if _, ok := c.hub.clients[c]; ok {
		delete(c.hub.clients, c)
		close(c.send)
	}
	c.hub.mu.Unlock()
	_ = c.conn.Close()
}

func (c *client) readPump() {
	defer c.remove()
	c.conn.SetReadLimit(16384)
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})
	for {
		_, msg, err := c.conn.ReadMessage()
		if err != nil {
			break
		}
		// Allow dynamic match_id subscription switch over WS if client sends {"subscribe":"m-..."}
		var sub struct {
			Subscribe string `json:"subscribe"`
			MatchID   string `json:"match_id"`
		}
		if json.Unmarshal(msg, &sub) == nil {
			target := sub.Subscribe
			if target == "" {
				target = sub.MatchID
			}
			if target != "" {
				c.hub.mu.Lock()
				c.matchID = target
				c.hub.mu.Unlock()
			}
		}
	}
}

func (c *client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		_ = c.conn.Close()
	}()
	for {
		select {
		case message, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
