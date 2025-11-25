// internal/server/server.go
package server

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/insign/sidelook/internal/watcher"
)

// Server é o servidor HTTP com suporte a WebSocket
type Server struct {
	watcher  *watcher.ImageWatcher
	server   *http.Server
	mux      *http.ServeMux
	port     int
	upgrader websocket.Upgrader

	clients   map[*wsClient]bool
	clientsMu sync.RWMutex
}

// wsClient representa um cliente WebSocket conectado
type wsClient struct {
	conn *websocket.Conn
	send chan []byte
}

// New cria um novo servidor
func New(w *watcher.ImageWatcher, preferredPort int) *Server {
	s := &Server{
		watcher: w,
		mux:     http.NewServeMux(),
		clients: make(map[*wsClient]bool),
		upgrader: websocket.Upgrader{
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
			CheckOrigin: func(r *http.Request) bool {
				return true // Aceitar qualquer origem (localhost)
			},
		},
	}

	if preferredPort == 0 {
		preferredPort = 8080
	}
	s.port = preferredPort

	s.registerRoutes()

	// Configurar callback do watcher
	w.OnNewImage = s.broadcastNewImage

	return s
}

// Start inicia o servidor, tentando portas sequenciais se necessário
func (s *Server) Start() error {
	const maxAttempts = 100

	for attempt := 0; attempt < maxAttempts; attempt++ {
		addr := fmt.Sprintf("127.0.0.1:%d", s.port)

		listener, err := net.Listen("tcp", addr)
		if err != nil {
			s.port++
			continue
		}

		s.server = &http.Server{
			Handler:      s.mux,
			ReadTimeout:  15 * time.Second,
			WriteTimeout: 15 * time.Second,
			IdleTimeout:  60 * time.Second,
		}

		go s.server.Serve(listener)
		return nil
	}

	return fmt.Errorf("não foi possível iniciar servidor: portas %d-%d indisponíveis",
		s.port-maxAttempts+1, s.port)
}

// Port retorna a porta em que o servidor está rodando
func (s *Server) Port() int {
	return s.port
}

// URL retorna a URL completa do servidor
func (s *Server) URL() string {
	return fmt.Sprintf("http://localhost:%d", s.port)
}

// Stop para o servidor graciosamente
func (s *Server) Stop() error {
	// Fechar todos os WebSockets
	s.clientsMu.Lock()
	for client := range s.clients {
		close(client.send)
		client.conn.Close()
	}
	s.clients = make(map[*wsClient]bool)
	s.clientsMu.Unlock()

	if s.server != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return s.server.Shutdown(ctx)
	}
	return nil
}

// handleWebSocket gerencia conexões WebSocket
func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	client := &wsClient{
		conn: conn,
		send: make(chan []byte, 256),
	}

	s.clientsMu.Lock()
	s.clients[client] = true
	s.clientsMu.Unlock()

	go s.writePump(client)
	go s.readPump(client)
}

// writePump envia mensagens para o cliente WebSocket
func (s *Server) writePump(client *wsClient) {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		client.conn.Close()
	}()

	for {
		select {
		case message, ok := <-client.send:
			client.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				client.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := client.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			client.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := client.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// readPump lê mensagens do cliente WebSocket (principalmente para detectar desconexão)
func (s *Server) readPump(client *wsClient) {
	defer func() {
		s.clientsMu.Lock()
		delete(s.clients, client)
		s.clientsMu.Unlock()
		client.conn.Close()
	}()

	client.conn.SetReadLimit(512)
	client.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	client.conn.SetPongHandler(func(string) error {
		client.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		if _, _, err := client.conn.ReadMessage(); err != nil {
			break
		}
	}
}
