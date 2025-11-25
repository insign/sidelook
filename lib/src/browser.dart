// lib/src/browser.dart

import 'dart:io';

import 'utils/logger.dart';

/// Abre URL no navegador padrão do sistema
class BrowserLauncher {
  /// Abre a URL no navegador padrão
  ///
  /// Retorna true se conseguiu executar o comando (não garante que abriu)
  static Future<bool> open(String url) async {
    try {
      final String command;
      final List<String> args;

      if (Platform.isLinux) {
        command = 'xdg-open';
        args = [url];
      } else if (Platform.isMacOS) {
        command = 'open';
        args = [url];
      } else if (Platform.isWindows) {
        command = 'cmd';
        args = ['/c', 'start', '', url];
      } else {
        Logger.warn(
            'Sistema operacional não suportado para abertura automática de navegador.');
        Logger.info('Acesse manualmente: $url');
        return false;
      }

      // Executar de forma não-bloqueante
      final result = await Process.run(
        command,
        args,
        runInShell: Platform.isWindows,
      );

      if (result.exitCode != 0) {
        Logger.warn('Não foi possível abrir o navegador automaticamente.');
        Logger.info('Acesse manualmente: $url');
        return false;
      }

      return true;
    } catch (e) {
      Logger.warn('Erro ao abrir navegador: $e');
      Logger.info('Acesse manualmente: $url');
      return false;
    }
  }
}
