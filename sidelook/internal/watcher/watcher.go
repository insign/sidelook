// internal/watcher/watcher.go
package watcher

import (
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
)

// SupportedExtensions são as extensões de imagem suportadas
var SupportedExtensions = map[string]bool{
	".jpg":  true,
	".jpeg": true,
	".png":  true,
	".gif":  true,
	".webp": true,
	".svg":  true,
	".bmp":  true,
	".tiff": true,
	".tif":  true,
}

// IsImageFile verifica se um arquivo é uma imagem suportada
func IsImageFile(path string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	return SupportedExtensions[ext]
}

// ImageInfo contém informações sobre uma imagem
type ImageInfo struct {
	Path    string
	ModTime time.Time
}

// ImageWatcher monitora um diretório por novas imagens
type ImageWatcher struct {
	dir     string
	watcher *fsnotify.Watcher

	mu           sync.RWMutex
	currentImage *ImageInfo

	// OnNewImage é chamado quando uma nova imagem é detectada
	OnNewImage func(path string)

	done chan struct{}
}

// New cria um novo ImageWatcher
func New(dir string) (*ImageWatcher, error) {
	// Verificar se diretório existe
	info, err := os.Stat(dir)
	if err != nil {
		return nil, err
	}
	if !info.IsDir() {
		return nil, os.ErrNotExist
	}

	w, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, err
	}

	return &ImageWatcher{
		dir:     dir,
		watcher: w,
		done:    make(chan struct{}),
	}, nil
}

// ScanExisting faz scan inicial e retorna a imagem mais recente
func (iw *ImageWatcher) ScanExisting() (count int, mostRecent *ImageInfo, err error) {
	entries, err := os.ReadDir(iw.dir)
	if err != nil {
		return 0, nil, err
	}

	var latestInfo *ImageInfo

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		path := filepath.Join(iw.dir, entry.Name())
		if !IsImageFile(path) {
			continue
		}

		count++

		info, err := entry.Info()
		if err != nil {
			continue
		}

		if latestInfo == nil || info.ModTime().After(latestInfo.ModTime) {
			latestInfo = &ImageInfo{
				Path:    path,
				ModTime: info.ModTime(),
			}
		}
	}

	iw.mu.Lock()
	iw.currentImage = latestInfo
	iw.mu.Unlock()

	return count, latestInfo, nil
}

// CurrentImage retorna a imagem atual
func (iw *ImageWatcher) CurrentImage() *ImageInfo {
	iw.mu.RLock()
	defer iw.mu.RUnlock()
	return iw.currentImage
}

// CurrentImageRelative retorna o caminho relativo da imagem atual
func (iw *ImageWatcher) CurrentImageRelative() string {
	img := iw.CurrentImage()
	if img == nil {
		return ""
	}
	rel, err := filepath.Rel(iw.dir, img.Path)
	if err != nil {
		return filepath.Base(img.Path)
	}
	return rel
}

// Start inicia o monitoramento
func (iw *ImageWatcher) Start() error {
	if err := iw.watcher.Add(iw.dir); err != nil {
		return err
	}

	go iw.loop()
	return nil
}

func (iw *ImageWatcher) loop() {
	for {
		select {
		case event, ok := <-iw.watcher.Events:
			if !ok {
				return
			}
			iw.handleEvent(event)

		case err, ok := <-iw.watcher.Errors:
			if !ok {
				return
			}
			// Log error mas continua
			_ = err

		case <-iw.done:
			return
		}
	}
}

func (iw *ImageWatcher) handleEvent(event fsnotify.Event) {
	// Interessados em Create e Write
	if event.Op&(fsnotify.Create|fsnotify.Write) == 0 {
		return
	}

	path := event.Name
	if !IsImageFile(path) {
		return
	}

	// Verificar se arquivo existe (pode ter sido deletado rapidamente)
	info, err := os.Stat(path)
	if err != nil {
		return
	}

	// Atualizar imagem atual
	newImage := &ImageInfo{
		Path:    path,
		ModTime: info.ModTime(),
	}

	iw.mu.Lock()
	iw.currentImage = newImage
	iw.mu.Unlock()

	// Notificar callback
	if iw.OnNewImage != nil {
		rel, err := filepath.Rel(iw.dir, path)
		if err != nil {
			rel = filepath.Base(path)
		}
		iw.OnNewImage(rel)
	}
}

// Stop para o monitoramento
func (iw *ImageWatcher) Stop() error {
	close(iw.done)
	return iw.watcher.Close()
}

// Dir retorna o diretório monitorado
func (iw *ImageWatcher) Dir() string {
	return iw.dir
}
