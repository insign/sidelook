# sidelook

Visualizador de imagens em tempo real via navegador.

## Funcionalidades

- 🖼 Monitora um diretório por novas imagens
- 🌐 Serve as imagens via HTTP local
- ⚡ Atualização em tempo real via WebSocket (sem refresh)
- 🖥 Abre navegador automaticamente
- 🔄 Auto-update integrado
- 🎯 Fullscreen ao clicar na imagem

## Instalação

### Download Direto

Baixe o executável para seu sistema operacional na [página de releases](https://github.com/insign/sidelook/releases/latest):

- **Linux**: `sidelook-linux`
- **macOS**: `sidelook-macos`
- **Windows**: `sidelook-windows.exe`

Depois de baixar, dê permissão de execução (Linux/macOS):

```bash
chmod +x sidelook-linux
sudo mv sidelook-linux /usr/local/bin/sidelook
```

## Uso

```bash
# Monitorar diretório atual
sidelook

# Monitorar pasta específica
sidelook ~/Downloads

# Especificar porta
sidelook -p 3000

# Atualizar para versão mais recente
sidelook --update

# Ver versão
sidelook --version

# Ajuda
sidelook --help
```

## Formatos Suportados

- JPEG (`.jpg`, `.jpeg`)
- PNG (`.png`)
- GIF (`.gif`)
- WebP (`.webp`)
- SVG (`.svg`)
- BMP (`.bmp`)
- TIFF (`.tiff`, `.tif`)

## Desenvolvimento

```bash
# Clonar repositório
git clone https://github.com/insign/sidelook.git
cd sidelook

# Instalar dependências
dart pub get

# Gerar arquivo de versão
dart run tool/generate_version.dart

# Rodar em modo desenvolvimento
dart run bin/sidelook.dart

# Executar testes
dart test

# Compilar executável
dart compile exe bin/sidelook.dart -o sidelook
```

## Licença

MIT
