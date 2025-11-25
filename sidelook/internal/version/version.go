// internal/version/version.go
package version

// Estas variáveis são definidas em tempo de compilação via ldflags
// Exemplo: go build -ldflags "-X github.com/insign/sidelook/internal/version.Version=1.0.0"
var (
	// Version é a versão semântica do aplicativo
	Version = "dev"

	// Commit é o hash do commit git
	Commit = "unknown"

	// BuildDate é a data de compilação
	BuildDate = "unknown"
)

// Info retorna string formatada com informações de versão
func Info() string {
	return Version
}

// Full retorna informações completas de versão
func Full() string {
	return Version + " (" + Commit + ") built " + BuildDate
}
