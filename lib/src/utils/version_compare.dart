// lib/src/utils/version_compare.dart

/// Resultado da comparação de versões
enum VersionComparison {
  /// Versão local é mais antiga (atualização disponível)
  older,

  /// Versões são iguais
  equal,

  /// Versão local é mais recente (dev/pre-release?)
  newer,
}

/// Compara versões semânticas (SemVer simplificado)
///
/// Suporta formatos:
/// - "1.0.0"
/// - "v1.0.0" (ignora prefixo 'v')
/// - "1.0.0-beta" (ignora sufixos pre-release para simplificar)
class VersionCompare {
  /// Limpa a string de versão removendo prefixos e sufixos
  static String normalize(String version) {
    var v = version.trim().toLowerCase();
    // Remover prefixo 'v'
    if (v.startsWith('v')) {
      v = v.substring(1);
    }
    // Remover sufixos como -beta, -alpha, +build
    final dashIndex = v.indexOf('-');
    if (dashIndex != -1) {
      v = v.substring(0, dashIndex);
    }
    final plusIndex = v.indexOf('+');
    if (plusIndex != -1) {
      v = v.substring(0, plusIndex);
    }
    return v;
  }

  /// Converte versão em lista de inteiros [major, minor, patch]
  static List<int> parse(String version) {
    final normalized = normalize(version);
    final parts = normalized.split('.');

    final result = <int>[];
    for (var i = 0; i < 3; i++) {
      if (i < parts.length) {
        result.add(int.tryParse(parts[i]) ?? 0);
      } else {
        result.add(0);
      }
    }
    return result;
  }

  /// Compara duas versões
  ///
  /// Retorna:
  /// - [VersionComparison.older] se local < remote
  /// - [VersionComparison.equal] se local == remote
  /// - [VersionComparison.newer] se local > remote
  static VersionComparison compare(String local, String remote) {
    final localParts = parse(local);
    final remoteParts = parse(remote);

    for (var i = 0; i < 3; i++) {
      if (localParts[i] < remoteParts[i]) {
        return VersionComparison.older;
      }
      if (localParts[i] > remoteParts[i]) {
        return VersionComparison.newer;
      }
    }
    return VersionComparison.equal;
  }

  /// Verifica se há atualização disponível
  static bool hasUpdate(String local, String remote) {
    return compare(local, remote) == VersionComparison.older;
  }
}
