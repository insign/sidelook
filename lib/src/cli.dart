// lib/src/cli.dart

import 'package:args/args.dart';

/// Configuração parseada dos argumentos CLI
class CliConfig {
  const CliConfig({
    required this.directory,
    this.port,
    this.update = false,
    this.showVersion = false,
    this.showHelp = false,
  });

  /// Diretório a monitorar
  final String directory;

  /// Porta especificada (null = auto)
  final int? port;

  /// Executar atualização
  final bool update;

  /// Exibir versão
  final bool showVersion;

  /// Exibir ajuda
  final bool showHelp;
}

/// Parser de argumentos de linha de comando
class CliParser {
  CliParser() {
    _parser = ArgParser()
      ..addOption(
        'port',
        abbr: 'p',
        help: 'Porta do servidor HTTP (padrão: 8080)',
        valueHelp: 'número',
      )
      ..addFlag(
        'update',
        abbr: 'u',
        negatable: false,
        help: 'Atualizar para a versão mais recente',
      )
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Exibir versão atual',
      )
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Exibir esta ajuda',
      );
  }

  late final ArgParser _parser;

  /// Gera texto de ajuda
  String get usage => '''
sidelook - Visualizador de imagens em tempo real

Uso: sidelook [opções] [diretório]

Opções:
${_parser.usage}

Exemplos:
  sidelook                    # Monitora diretório atual
  sidelook ~/Downloads        # Monitora pasta Downloads
  sidelook -p 3000            # Usa porta 3000
  sidelook --update           # Atualiza para versão mais recente
''';

  /// Faz parse dos argumentos
  ///
  /// Lança [FormatException] se argumentos inválidos
  CliConfig parse(List<String> args) {
    final ArgResults results;
    try {
      results = _parser.parse(args);
    } on FormatException catch (e) {
      throw FormatException('Erro ao processar argumentos: ${e.message}');
    }

    // Diretório é o primeiro argumento posicional, ou '.' se não especificado
    final directory = results.rest.isEmpty ? '.' : results.rest.first;

    // Parse da porta
    int? port;
    final portStr = results.option('port');
    if (portStr != null) {
      port = int.tryParse(portStr);
      if (port == null || port < 1 || port > 65535) {
        throw FormatException(
          'Porta inválida: "$portStr". Use um número entre 1 e 65535.',
        );
      }
    }

    return CliConfig(
      directory: directory,
      port: port,
      update: results.flag('update'),
      showVersion: results.flag('version'),
      showHelp: results.flag('help'),
    );
  }
}
