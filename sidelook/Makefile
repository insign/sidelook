# Makefile para sidelook

# Variáveis
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LDFLAGS := -ldflags "-s -w \
	-X github.com/insign/sidelook/internal/version.Version=$(VERSION) \
	-X github.com/insign/sidelook/internal/version.Commit=$(COMMIT) \
	-X github.com/insign/sidelook/internal/version.BuildDate=$(BUILD_DATE)"

BINARY := sidelook
CMD_PATH := ./cmd/sidelook

# Alvos
.PHONY: all build build-all test lint clean run install

all: test build

# Build para o SO atual
build:
	go build $(LDFLAGS) -o $(BINARY) $(CMD_PATH)

# Build para todas as plataformas
build-all: build-linux build-darwin build-windows

build-linux:
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(BINARY)-linux $(CMD_PATH)

build-darwin:
	GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o $(BINARY)-macos-amd64 $(CMD_PATH)
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(BINARY)-macos-arm64 $(CMD_PATH)

build-windows:
	GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o $(BINARY)-windows.exe $(CMD_PATH)

# Testes
test:
	go test -v -race -cover ./...

# Lint (requer golangci-lint instalado)
lint:
	golangci-lint run

# Limpar artefatos
clean:
	rm -f $(BINARY) $(BINARY)-linux $(BINARY)-macos-* $(BINARY)-windows.exe
	go clean

# Executar em modo desenvolvimento
run:
	go run $(CMD_PATH) .

# Instalar no sistema
install: build
	cp $(BINARY) $(GOPATH)/bin/

# Formatar código
fmt:
	go fmt ./...

# Verificar dependências
tidy:
	go mod tidy
	go mod verify
