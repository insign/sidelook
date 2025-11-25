// lib/src/utils/logger.dart

import 'dart:io';

/// ANSI color codes para terminal
class _AnsiColors {
  static const reset = '\x1B[0m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const magenta = '\x1B[35m';
  static const cyan = '\x1B[36m';
  static const bold = '\x1B[1m';
  static const dim = '\x1B[2m';
}

/// Logger centralizado para output formatado
class Logger {
  /// Detecta se o terminal suporta cores
  static bool get supportsAnsi {
    if (Platform.isWindows) {
      // Windows 10+ suporta ANSI, mas é complexo detectar
      // Assumir que suporta se stdout é TTY
      return stdout.hasTerminal;
    }
    return stdout.hasTerminal && Platform.environment['TERM'] != 'dumb';
  }

  static String _colorize(String text, String color) {
    if (!supportsAnsi) return text;
    return '$color$text${_AnsiColors.reset}';
  }

  /// Log informativo (azul)
  static void info(String message) {
    stdout.writeln(_colorize('ℹ $message', _AnsiColors.blue));
  }

  /// Log de sucesso (verde)
  static void success(String message) {
    stdout.writeln(_colorize('✓ $message', _AnsiColors.green));
  }

  /// Log de aviso (amarelo)
  static void warn(String message) {
    stdout.writeln(_colorize('⚠ $message', _AnsiColors.yellow));
  }

  /// Log de erro (vermelho)
  static void error(String message) {
    stderr.writeln(_colorize('✗ $message', _AnsiColors.red));
  }

  /// Log de atualização disponível (cyan + negrito)
  static void updateAvailable(String currentVersion, String newVersion) {
    final msg = '''

${_colorize('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', _AnsiColors.cyan)}
${_colorize('  Nova versão disponível: $currentVersion → $newVersion', '${_AnsiColors.bold}${_AnsiColors.cyan}')}
${_colorize('  Execute: sidelook --update', _AnsiColors.cyan)}
${_colorize('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', _AnsiColors.cyan)}
''';
    stdout.write(msg);
  }

  /// Log de servidor iniciado
  static void serverStarted(String url) {
    stdout.writeln('');
    stdout.writeln(_colorize(
        '🖼  sidelook rodando', '${_AnsiColors.bold}${_AnsiColors.green}'));
    stdout.writeln(_colorize('   $url', _AnsiColors.dim));
    stdout.writeln('');
  }

  /// Log de nova imagem detectada
  static void newImage(String filename) {
    stdout.writeln(_colorize('→ Nova imagem: $filename', _AnsiColors.magenta));
  }

  /// Log simples sem formatação
  static void plain(String message) {
    stdout.writeln(message);
  }
}
