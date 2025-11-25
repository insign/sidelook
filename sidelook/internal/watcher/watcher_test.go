// internal/watcher/watcher_test.go
package watcher

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestIsImageFile(t *testing.T) {
	tests := []struct {
		path     string
		expected bool
	}{
		{"foto.jpg", true},
		{"foto.jpeg", true},
		{"foto.PNG", true}, // case insensitive
		{"animacao.gif", true},
		{"imagem.webp", true},
		{"vetor.svg", true},
		{"bitmap.bmp", true},
		{"scan.tiff", true},
		{"scan.tif", true},
		{"arquivo.txt", false},
		{"doc.pdf", false},
		{"arquivo", false},
	}

	for _, tt := range tests {
		t.Run(tt.path, func(t *testing.T) {
			result := IsImageFile(tt.path)
			if result != tt.expected {
				t.Errorf("IsImageFile(%q) = %v, want %v", tt.path, result, tt.expected)
			}
		})
	}
}

func TestImageWatcher_New(t *testing.T) {
	// Diretório válido
	tmpDir, err := os.MkdirTemp("", "sidelook_test_*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	w, err := New(tmpDir)
	if err != nil {
		t.Errorf("New() error = %v, want nil", err)
	}
	if w != nil {
		w.Stop()
	}

	// Diretório inválido
	_, err = New("/caminho/que/nao/existe")
	if err == nil {
		t.Error("New() com diretório inválido deveria retornar erro")
	}
}

func TestImageWatcher_ScanExisting(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "sidelook_test_*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	// Criar algumas imagens
	img1 := filepath.Join(tmpDir, "img1.png")
	if err := os.WriteFile(img1, []byte{0x89, 0x50, 0x4E, 0x47}, 0644); err != nil {
		t.Fatal(err)
	}

	time.Sleep(100 * time.Millisecond)

	img2 := filepath.Join(tmpDir, "img2.jpg")
	if err := os.WriteFile(img2, []byte{0xFF, 0xD8, 0xFF}, 0644); err != nil {
		t.Fatal(err)
	}

	// Criar arquivo não-imagem
	txt := filepath.Join(tmpDir, "readme.txt")
	if err := os.WriteFile(txt, []byte("hello"), 0644); err != nil {
		t.Fatal(err)
	}

	w, err := New(tmpDir)
	if err != nil {
		t.Fatal(err)
	}
	defer w.Stop()

	count, mostRecent, err := w.ScanExisting()
	if err != nil {
		t.Errorf("ScanExisting() error = %v", err)
	}

	if count != 2 {
		t.Errorf("ScanExisting() count = %d, want 2", count)
	}

	if mostRecent == nil {
		t.Fatal("ScanExisting() mostRecent = nil, want non-nil")
	}

	if mostRecent.Path != img2 {
		t.Errorf("ScanExisting() mostRecent.Path = %q, want %q", mostRecent.Path, img2)
	}
}

func TestImageWatcher_DetectNewImage(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "sidelook_test_*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	w, err := New(tmpDir)
	if err != nil {
		t.Fatal(err)
	}
	defer w.Stop()

	detected := make(chan string, 1)
	w.OnNewImage = func(path string) {
		detected <- path
	}

	if err := w.Start(); err != nil {
		t.Fatal(err)
	}

	// Dar tempo para watcher inicializar
	time.Sleep(100 * time.Millisecond)

	// Criar nova imagem
	newImg := filepath.Join(tmpDir, "nova.png")
	if err := os.WriteFile(newImg, []byte{0x89, 0x50, 0x4E, 0x47}, 0644); err != nil {
		t.Fatal(err)
	}

	// Aguardar detecção
	select {
	case path := <-detected:
		if path != "nova.png" {
			t.Errorf("OnNewImage path = %q, want %q", path, "nova.png")
		}
	case <-time.After(5 * time.Second):
		t.Error("Timeout aguardando detecção de nova imagem")
	}
}
