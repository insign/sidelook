// internal/cli/cli.go
package cli

import (
	"flag"
	"fmt"
	"os"

	"github.com/insign/sidelook/internal/version"
)

// Config contém a configuração parseada dos argumentos CLI
type Config struct {
	// Directory é o diretório a monitorar
	Directory string

	// Port é a porta especificada (0 = auto)
	Port int

	// Update indica se deve executar atualização
	Update bool

	// ShowVersion indica se deve exibir versão
	ShowVersion bool

	// ShowHelp indica se deve exibir ajuda
	ShowHelp bool
}

// Parse faz o parse dos argumentos de linha de comando
func Parse(args []string) (*Config, error) {
	cfg := &Config{}

	fs := flag.NewFlagSet("sidelook", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)

	fs.IntVar(&cfg.Port, "p", 0, "Porta do servidor HTTP (padrão: 8080)")
	fs.IntVar(&cfg.Port, "port", 0, "Porta do servidor HTTP (padrão: 8080)")
	fs.BoolVar(&cfg.Update, "u", false, "Atualizar para a versão mais recente")
	fs.BoolVar(&cfg.Update, "update", false, "Atualizar para a versão mais recente")
	fs.BoolVar(&cfg.ShowVersion, "v", false, "Exibir versão atual")
	fs.BoolVar(&cfg.ShowVersion, "version", false, "Exibir versão atual")
	fs.BoolVar(&cfg.ShowHelp, "h", false, "Exibir esta ajuda")
	fs.BoolVar(&cfg.ShowHelp, "help", false, "Exibir esta ajuda")

	// Custom usage
	fs.Usage = func() {
		fmt.Fprint(os.Stderr, Usage())
	}

	if err := fs.Parse(args); err != nil {
		return nil, err
	}

	// Diretório é o primeiro argumento posicional
	if fs.NArg() > 0 {
		cfg.Directory = fs.Arg(0)
	} else {
		cfg.Directory = "."
	}

	// Validar porta
	if cfg.Port != 0 && (cfg.Port < 1 || cfg.Port > 65535) {
		return nil, fmt.Errorf("porta inválida: %d. Use um número entre 1 e 65535", cfg.Port)
	}

	return cfg, nil
}

// Usage retorna o texto de ajuda
func Usage() string {
	return fmt.Sprintf(`sidelook %s - Visualizador de imagens em tempo real

Uso: sidelook [opções] [diretório]

Opções:
  -p, --port <número>   Porta do servidor HTTP (padrão: 8080)
  -u, --update          Atualizar para a versão mais recente
  -v, --version         Exibir versão atual
  -h, --help            Exibir esta ajuda

Exemplos:
  sidelook                    # Monitora diretório atual
  sidelook ~/Downloads        # Monitora pasta Downloads
  sidelook -p 3000            # Usa porta 3000
  sidelook --update           # Atualiza para versão mais recente

`, version.Version)
}
