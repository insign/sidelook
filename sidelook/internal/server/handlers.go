// internal/server/handlers.go
package server

import (
	"encoding/json"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/insign/sidelook/internal/assets"
	"github.com/insign/sidelook/internal/watcher"
)

// registerRoutes registra os handlers HTTP
func (s *Server) registerRoutes() {
	s.mux.HandleFunc("/", s.handleIndex)
	s.mux.HandleFunc("/ws", s.handleWebSocket)
	s.mux.HandleFunc("/image/", s.handleImage)
}

// handleIndex serve a página HTML principal
func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	initialImage := s.watcher.CurrentImageRelative()
	html := assets.GenerateHTML(initialImage)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(html))
}

// handleImage serve arquivos de imagem
func (s *Server) handleImage(w http.ResponseWriter, r *http.Request) {
	// Extrair caminho da imagem (remover /image/ prefix)
	imagePath := strings.TrimPrefix(r.URL.Path, "/image/")
	if imagePath == "" {
		http.NotFound(w, r)
		return
	}

	// Construir caminho completo
	fullPath := filepath.Join(s.watcher.Dir(), imagePath)

	// Segurança: verificar se o caminho está dentro do diretório monitorado
	absDir, err := filepath.Abs(s.watcher.Dir())
	if err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	absPath, err := filepath.Abs(fullPath)
	if err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	if !strings.HasPrefix(absPath, absDir) {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}

	// Verificar se é uma imagem válida
	if !watcher.IsImageFile(fullPath) {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}

	// Verificar se arquivo existe
	if _, err := os.Stat(fullPath); os.IsNotExist(err) {
		http.NotFound(w, r)
		return
	}

	// Determinar content type
	ext := filepath.Ext(fullPath)
	contentType := mime.TypeByExtension(ext)
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")

	http.ServeFile(w, r, fullPath)
}

// wsMessage é a estrutura de mensagem WebSocket
type wsMessage struct {
	Type string `json:"type"`
	Path string `json:"path,omitempty"`
}

// broadcastNewImage envia notificação de nova imagem para todos os clientes
func (s *Server) broadcastNewImage(path string) {
	msg := wsMessage{
		Type: "new_image",
		Path: path,
	}

	data, err := json.Marshal(msg)
	if err != nil {
		return
	}

	s.clientsMu.RLock()
	defer s.clientsMu.RUnlock()

	for client := range s.clients {
		go func(c *wsClient) {
			c.send <- data
		}(client)
	}
}
