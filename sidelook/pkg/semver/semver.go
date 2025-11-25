// pkg/semver/semver.go
package semver

import (
	"strconv"
	"strings"
)

// Comparison representa o resultado da comparação de versões
type Comparison int

const (
	// Older indica que a versão local é mais antiga
	Older Comparison = -1
	// Equal indica que as versões são iguais
	Equal Comparison = 0
	// Newer indica que a versão local é mais recente
	Newer Comparison = 1
)

// Normalize remove prefixos e sufixos de uma string de versão
// Exemplo: "v1.2.3-beta" -> "1.2.3"
func Normalize(version string) string {
	v := strings.TrimSpace(strings.ToLower(version))

	// Remover prefixo 'v'
	v = strings.TrimPrefix(v, "v")

	// Remover sufixo pré-release (-beta, -alpha, etc)
	if idx := strings.Index(v, "-"); idx != -1 {
		v = v[:idx]
	}

	// Remover metadata de build (+build)
	if idx := strings.Index(v, "+"); idx != -1 {
		v = v[:idx]
	}

	return v
}

// Parse converte uma string de versão em [major, minor, patch]
func Parse(version string) [3]int {
	normalized := Normalize(version)
	parts := strings.Split(normalized, ".")

	var result [3]int
	for i := 0; i < 3 && i < len(parts); i++ {
		if n, err := strconv.Atoi(parts[i]); err == nil {
			result[i] = n
		}
	}

	return result
}

// Compare compara duas versões
// Retorna Older se local < remote, Equal se iguais, Newer se local > remote
func Compare(local, remote string) Comparison {
	localParts := Parse(local)
	remoteParts := Parse(remote)

	for i := 0; i < 3; i++ {
		if localParts[i] < remoteParts[i] {
			return Older
		}
		if localParts[i] > remoteParts[i] {
			return Newer
		}
	}

	return Equal
}

// HasUpdate verifica se há atualização disponível
func HasUpdate(local, remote string) bool {
	return Compare(local, remote) == Older
}
