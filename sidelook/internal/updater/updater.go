// internal/updater/updater.go
package updater

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"github.com/insign/sidelook/internal/version"
	"github.com/insign/sidelook/pkg/semver"
)

const (
	apiURL  = "https://api.github.com/repos/insign/sidelook/releases/latest"
	timeout = 10 * time.Second
)

// ReleaseInfo contém informações sobre uma release do GitHub
type ReleaseInfo struct {
	Version     string
	DownloadURL string
	PublishedAt time.Time
}

// githubRelease representa a resposta da API do GitHub
type githubRelease struct {
	TagName     string        `json:"tag_name"`
	PublishedAt string        `json:"published_at"`
	Assets      []githubAsset `json:"assets"`
}

type githubAsset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
}

// CheckLatestRelease verifica a release mais recente no GitHub
func CheckLatestRelease() (*ReleaseInfo, error) {
	client := &http.Client{Timeout: timeout}

	req, err := http.NewRequest("GET", apiURL, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("User-Agent", "sidelook/"+version.Version)

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API retornou status %d", resp.StatusCode)
	}

	var release githubRelease
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return nil, err
	}

	// Encontrar asset para o SO atual
	assetName := getAssetName()
	var downloadURL string
	for _, asset := range release.Assets {
		if asset.Name == assetName {
			downloadURL = asset.BrowserDownloadURL
			break
		}
	}

	publishedAt, _ := time.Parse(time.RFC3339, release.PublishedAt)

	return &ReleaseInfo{
		Version:     release.TagName,
		DownloadURL: downloadURL,
		PublishedAt: publishedAt,
	}, nil
}

// getAssetName retorna o nome do asset para o SO atual
func getAssetName() string {
	switch runtime.GOOS {
	case "linux":
		return "sidelook-linux"
	case "darwin":
		return "sidelook-macos"
	case "windows":
		return "sidelook-windows.exe"
	default:
		return "sidelook"
	}
}

// CheckResult é o resultado da verificação de atualização
type CheckResult struct {
	HasUpdate      bool
	CurrentVersion string
	LatestVersion  string
}

// CheckInBackground verifica atualizações em background
// Retorna um channel que receberá o resultado
func CheckInBackground() <-chan *CheckResult {
	ch := make(chan *CheckResult, 1)

	go func() {
		defer close(ch)

		release, err := CheckLatestRelease()
		if err != nil {
			return
		}

		result := &CheckResult{
			CurrentVersion: version.Version,
			LatestVersion:  release.Version,
			HasUpdate:      semver.HasUpdate(version.Version, release.Version),
		}

		ch <- result
	}()

	return ch
}

// PerformUpdate executa a atualização completa
func PerformUpdate() error {
	fmt.Println("Verificando atualizações...")

	release, err := CheckLatestRelease()
	if err != nil {
		return fmt.Errorf("não foi possível verificar atualizações: %w", err)
	}

	if !semver.HasUpdate(version.Version, release.Version) {
		fmt.Printf("Você já está na versão mais recente (%s)\n", version.Version)
		return nil
	}

	if release.DownloadURL == "" {
		return fmt.Errorf("não foi encontrado download para %s", runtime.GOOS)
	}

	fmt.Printf("Baixando versão %s...\n", release.Version)

	// Baixar para arquivo temporário
	resp, err := http.Get(release.DownloadURL)
	if err != nil {
		return fmt.Errorf("falha no download: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download falhou com status %d", resp.StatusCode)
	}

	// Criar arquivo temporário
	tempFile, err := os.CreateTemp("", "sidelook_update_*")
	if err != nil {
		return fmt.Errorf("não foi possível criar arquivo temporário: %w", err)
	}
	tempPath := tempFile.Name()

	_, err = io.Copy(tempFile, resp.Body)
	tempFile.Close()
	if err != nil {
		os.Remove(tempPath)
		return fmt.Errorf("falha ao salvar download: %w", err)
	}

	// Obter caminho do executável atual
	currentExe, err := os.Executable()
	if err != nil {
		os.Remove(tempPath)
		return fmt.Errorf("não foi possível determinar executável atual: %w", err)
	}
	currentExe, _ = filepath.EvalSymlinks(currentExe)

	fmt.Println("Instalando atualização...")

	if runtime.GOOS == "windows" {
		// Windows: não consegue sobrescrever executável em uso
		fmt.Println("\nNo Windows, a atualização precisa ser feita manualmente.")
		fmt.Printf("1. Feche este programa\n")
		fmt.Printf("2. Substitua %s pelo arquivo baixado em:\n   %s\n", currentExe, tempPath)
		return nil
	}

	// Unix: substituição atômica

	// Dar permissão de execução
	if err := os.Chmod(tempPath, 0755); err != nil {
		os.Remove(tempPath)
		return fmt.Errorf("falha ao definir permissões: %w", err)
	}

	// Backup do atual (opcional)
	backupPath := currentExe + ".old"
	os.Remove(backupPath)             // Ignorar erro
	os.Rename(currentExe, backupPath) // Ignorar erro no backup

	// Mover novo para posição do atual
	if err := os.Rename(tempPath, currentExe); err != nil {
		// Tentar restaurar backup
		os.Rename(backupPath, currentExe)
		return fmt.Errorf("falha ao instalar atualização: %w", err)
	}

	// Limpar backup
	os.Remove(backupPath)

	fmt.Printf("Atualizado para versão %s!\n", release.Version)
	return nil
}
