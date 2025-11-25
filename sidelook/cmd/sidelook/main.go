// cmd/sidelook/main.go
package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/insign/sidelook/internal/browser"
	"github.com/insign/sidelook/internal/cli"
	"github.com/insign/sidelook/internal/server"
	"github.com/insign/sidelook/internal/updater"
	"github.com/insign/sidelook/internal/version"
	"github.com/insign/sidelook/internal/watcher"
)

// Cores ANSI
const (
	colorReset  = "\033[0m"
	colorRed    = "\033[31m"
	colorGreen  = "\033[32m"
	colorYellow = "\033[33m"
	colorBlue   = "\033[34m"
	colorCyan   = "\033[36m"
	colorBold   = "\033[1m"
	colorDim    = "\033[2m"
)

func main() {
	// Parse argumentos
	config, err := cli.Parse(os.Args[1:])
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s✗ %s%s\n", colorRed, err, colorReset)
		os.Exit(1)
	}

	// --help
	if config.ShowHelp {
		fmt.Print(cli.Usage())
		return
	}

	// --version
	if config.ShowVersion {
		fmt.Println(version.Info())
		return
	}

	// --update
	if config.Update {
		if err := updater.PerformUpdate(); err != nil {
			fmt.Fprintf(os.Stderr, "%s✗ %s%s\n", colorRed, err, colorReset)
			os.Exit(1)
		}
		return
	}

	// Modo normal: iniciar servidor
	if err := runServer(config); err != nil {
		fmt.Fprintf(os.Stderr, "%s✗ %s%s\n", colorRed, err, colorReset)
		os.Exit(1)
	}
}

func runServer(config *cli.Config) error {
	// Criar watcher
	w, err := watcher.New(config.Directory)
	if err != nil {
		return fmt.Errorf("diretório inválido: %s", config.Directory)
	}

	// Verificar atualizações em background
	updateCh := updater.CheckInBackground()

	// Scan inicial
	count, _, err := w.ScanExisting()
	if err != nil {
		return fmt.Errorf("erro ao escanear diretório: %w", err)
	}

	if count > 0 {
		fmt.Printf("%sℹ %d imagem(ns) encontrada(s)%s\n", colorBlue, count, colorReset)
	} else {
		fmt.Printf("%sℹ Nenhuma imagem encontrada. Aguardando...%s\n", colorBlue, colorReset)
	}

	// Iniciar watcher
	if err := w.Start(); err != nil {
		return fmt.Errorf("erro ao iniciar monitoramento: %w", err)
	}
	defer w.Stop()

	// Iniciar servidor
	srv := server.New(w, config.Port)
	if err := srv.Start(); err != nil {
		return err
	}
	defer srv.Stop()

	// Exibir URL
	fmt.Println()
	fmt.Printf("%s%s🖼  sidelook rodando%s\n", colorBold, colorGreen, colorReset)
	fmt.Printf("%s   %s%s\n", colorDim, srv.URL(), colorReset)
	fmt.Println()

	// Abrir navegador
	if err := browser.Open(srv.URL()); err != nil {
		fmt.Printf("%s⚠ Não foi possível abrir o navegador automaticamente%s\n", colorYellow, colorReset)
		fmt.Printf("  Acesse manualmente: %s\n", srv.URL())
	}

	// Verificar resultado da checagem de atualização
	go func() {
		if result := <-updateCh; result != nil && result.HasUpdate {
			printUpdateAvailable(result.CurrentVersion, result.LatestVersion)
		}
	}()

	// Aguardar sinal de interrupção
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
	<-sigCh

	fmt.Printf("\n%sℹ Encerrando...%s\n", colorBlue, colorReset)
	return nil
}

func printUpdateAvailable(current, latest string) {
	fmt.Println()
	fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n", colorCyan, colorReset)
	fmt.Printf("%s%s  Nova versão disponível: %s → %s%s\n", colorBold, colorCyan, current, latest, colorReset)
	fmt.Printf("%s  Execute: sidelook --update%s\n", colorCyan, colorReset)
	fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n", colorCyan, colorReset)
	fmt.Println()
}
