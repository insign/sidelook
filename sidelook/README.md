# sidelook

Visualizador de imagens em tempo real via navegador.

## Funcionalidades

- 🖼 Monitora um diretório por novas imagens
- 🌐 Serve as imagens via HTTP local
- ⚡ Atualização em tempo real via WebSocket
- 🖥 Abre navegador automaticamente
- 🔄 Auto-update integrado
- 🎯 Fullscreen ao clicar (ou tecla F)

## Instalação

Baixe na [página de releases](https://github.com/insign/sidelook/releases/latest):

- Linux: `sidelook-linux`
- macOS: `sidelook-macos` (Universal)
- Windows: `sidelook-windows.exe`

` + "```" + `bash
chmod +x sidelook-linux
sudo mv sidelook-linux /usr/local/bin/sidelook
` + "```" + `

## Uso

` + "```" + `bash
sidelook                    # Diretório atual
sidelook ~/Downloads        # Pasta específica
sidelook -p 3000            # Porta específica
sidelook --update           # Atualizar
sidelook --version          # Versão
` + "```" + `

## Formatos

JPG, PNG, GIF, WebP, SVG, BMP, TIFF

## Desenvolvimento

` + "```" + `bash
go mod tidy
go run ./cmd/sidelook .
go test ./...
make build
` + "```" + `

## Licença

MIT
