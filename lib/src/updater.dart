// lib/src/updater.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'version.g.dart';
import 'utils/logger.dart';
import 'utils/version_compare.dart';

/// Informações sobre uma release do GitHub
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    this.downloadUrl,
    this.publishedAt,
  });

  final String version;
  final String? downloadUrl;
  final DateTime? publishedAt;
}

/// Gerenciador de atualizações via GitHub Releases
class Updater {
  static const _apiUrl =
      'https://api.github.com/repos/insign/sidelook/releases/latest';
  static const _timeout = Duration(seconds: 10);

  /// Obtém informações da release mais recente
  static Future<ReleaseInfo?> checkLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'sidelook/$packageVersion',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String?;
      if (tagName == null) return null;

      // Encontrar asset para o SO atual
      final assets = data['assets'] as List<dynamic>?;
      String? downloadUrl;

      if (assets != null) {
        final assetName = _getAssetName();
        for (final asset in assets) {
          if (asset['name'] == assetName) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      return ReleaseInfo(
        version: tagName,
        downloadUrl: downloadUrl,
        publishedAt: DateTime.tryParse(data['published_at'] as String? ?? ''),
      );
    } catch (e) {
      // Silenciosamente falhar - não queremos interromper o usuário
      return null;
    }
  }

  /// Retorna o nome do asset para o SO atual
  static String _getAssetName() {
    if (Platform.isLinux) return 'sidelook-linux';
    if (Platform.isMacOS) return 'sidelook-macos';
    if (Platform.isWindows) return 'sidelook-windows.exe';
    return 'sidelook';
  }

  /// Verifica atualizações em background e notifica se houver
  ///
  /// NÃO bloqueia - retorna imediatamente
  static void checkInBackground() {
    // Executar em um Future separado (não await)
    Future(() async {
      final release = await checkLatestRelease();
      if (release == null) return;

      if (VersionCompare.hasUpdate(packageVersion, release.version)) {
        Logger.updateAvailable(packageVersion, release.version);
      }
    });
  }

  /// Executa a atualização completa
  ///
  /// Retorna true se atualização foi bem-sucedida
  static Future<bool> performUpdate() async {
    Logger.info('Verificando atualizações...');

    final release = await checkLatestRelease();
    if (release == null) {
      Logger.error(
          'Não foi possível verificar atualizações. Verifique sua conexão.');
      return false;
    }

    if (!VersionCompare.hasUpdate(packageVersion, release.version)) {
      Logger.success('Você já está na versão mais recente ($packageVersion)');
      return true;
    }

    if (release.downloadUrl == null) {
      Logger.error(
          'Não foi encontrado download para ${Platform.operatingSystem}');
      return false;
    }

    Logger.info('Baixando versão ${release.version}...');

    try {
      // Baixar para arquivo temporário
      final response = await http.get(Uri.parse(release.downloadUrl!)).timeout(
            const Duration(minutes: 5),
          );

      if (response.statusCode != 200) {
        Logger.error('Falha no download (HTTP ${response.statusCode})');
        return false;
      }

      // Salvar em arquivo temporário
      final tempDir = Directory.systemTemp;
      final tempFile = File(p.join(tempDir.path,
          'sidelook_update_${DateTime.now().millisecondsSinceEpoch}'));
      await tempFile.writeAsBytes(response.bodyBytes);

      // Obter caminho do executável atual
      final currentExe = File(Platform.resolvedExecutable);
      final currentPath = currentExe.path;

      Logger.info('Instalando atualização...');

      if (Platform.isWindows) {
        // Windows: não consegue sobrescrever executável em uso
        // Criar script batch para fazer a substituição após sair
        final batchContent = '''
@echo off
timeout /t 1 /nobreak >nul
del "$currentPath"
move "${tempFile.path}" "$currentPath"
echo Atualização concluída!
''';
        final batchFile = File(p.join(tempDir.path, 'sidelook_update.bat'));
        await batchFile.writeAsString(batchContent);

        Logger.warn('No Windows, execute manualmente: ${batchFile.path}');
        Logger.info('Ou baixe a nova versão em: ${release.downloadUrl}');
        return true;
      } else {
        // Unix: substituição atômica via rename
        final backupPath = '$currentPath.old';

        // Dar permissão de execução ao novo arquivo
        await Process.run('chmod', ['+x', tempFile.path]);

        // Backup do atual (opcional, pode falhar)
        try {
          if (await File(backupPath).exists()) {
            await File(backupPath).delete();
          }
          await currentExe.rename(backupPath);
        } catch (_) {
          // Ignorar erro no backup
        }

        // Mover novo para posição do atual
        await tempFile.rename(currentPath);

        // Limpar backup
        try {
          await File(backupPath).delete();
        } catch (_) {}

        Logger.success('Atualizado para versão ${release.version}!');
        return true;
      }
    } catch (e) {
      Logger.error('Erro durante atualização: $e');
      return false;
    }
  }
}
