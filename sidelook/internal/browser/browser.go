// internal/browser/browser.go
package browser

import (
	"os/exec"
	"runtime"
)

// Open abre a URL no navegador padrão do sistema
// Retorna erro apenas se o comando falhar ao executar
func Open(url string) error {
	var cmd *exec.Cmd

	switch runtime.GOOS {
	case "linux":
		cmd = exec.Command("xdg-open", url)
	case "darwin":
		cmd = exec.Command("open", url)
	case "windows":
		cmd = exec.Command("cmd", "/c", "start", "", url)
	default:
		// SO não suportado, retornar nil (falha silenciosa)
		return nil
	}

	// Executar de forma não-bloqueante
	return cmd.Start()
}
