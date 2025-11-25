// bin/sidelook.dart

import 'dart:io';

import 'package:sidelook/src/cli.dart';
import 'package:sidelook/src/browser.dart';
import 'package:sidelook/src/server.dart';
import 'package:sidelook/src/updater.dart';
import 'package:sidelook/src/version.g.dart';
import 'package:sidelook/src/watcher.dart';
import 'package:sidelook/src/utils/logger.dart';

Future<void> main(List<String> args) async {
  final parser = CliParser();

  // Parse de argumentos
  final CliConfig config;
  try {
    config = parser.parse(args);
  } on FormatException catch (e) {
    Logger.error(e.message);
    exit(1);
  }

  // --help
  if (config.showHelp) {
    Logger.plain(parser.usage);
    exit(0);
  }

  // --version
  if (config.showVersion) {
    Logger.plain('$packageName $packageVersion');
    exit(0);
  }

  // --update
  if (config.update) {
    final success = await Updater.performUpdate();
    exit(success ? 0 : 1);
  }

  // Modo normal: iniciar servidor
  await _runServer(config);
}

Future<void> _runServer(CliConfig config) async {
  // Verificar diretório
  final watcher = ImageWatcher(config.directory);
  if (!await watcher.validate()) {
    Logger.error('Diretório não encontrado: ${config.directory}');
    exit(1);
  }

  // Verificar atualizações em background (não bloqueia)
  Updater.checkInBackground();

  // Scan inicial de imagens
  final scanResult = await watcher.scanExisting();
  if (scanResult.count > 0) {
    Logger.info('${scanResult.count} imagem(ns) encontrada(s)');
  } else {
    Logger.info('Nenhuma imagem encontrada. Aguardando...');
  }

  // Iniciar watcher
  await watcher.start();

  // Iniciar servidor
  final server = ImageServer(
    startPort: config.port ?? 8080,
    watcher: watcher,
  );

  try {
    await server.start();
  } catch (e) {
    Logger.error('Falha ao iniciar servidor: $e');
    await watcher.stop();
    exit(1);
  }

  Logger.serverStarted(server.url);

  // Abrir navegador
  await BrowserLauncher.open(server.url);

  // Configurar handler para SIGINT (Ctrl+C)
  ProcessSignal.sigint.watch().listen((_) async {
    Logger.info('Encerrando...');
    await server.stop();
    await watcher.stop();
    exit(0);
  });

  // Manter processo rodando
  // O servidor já mantém o event loop vivo, mas podemos adicionar
  // um Completer se necessário
}
