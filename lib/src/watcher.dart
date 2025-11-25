// lib/src/watcher.dart

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

/// Extensões de imagem suportadas (lowercase)
const supportedImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.svg',
  '.bmp',
  '.tiff',
  '.tif',
};

/// Verifica se um arquivo é uma imagem suportada
bool isImageFile(String path) {
  final ext = p.extension(path).toLowerCase();
  return supportedImageExtensions.contains(ext);
}

/// Resultado do scan inicial de imagens
class ImageScanResult {
  const ImageScanResult({this.mostRecent, required this.count});

  /// Imagem mais recente encontrada (null se nenhuma)
  final File? mostRecent;

  /// Total de imagens encontradas
  final int count;
}

/// Monitor de diretório para imagens
class ImageWatcher {
  ImageWatcher(this.directoryPath) : _directory = Directory(directoryPath);

  final String directoryPath;
  final Directory _directory;

  DirectoryWatcher? _watcher;
  StreamSubscription<WatchEvent>? _subscription;

  /// Stream de novas imagens detectadas
  final _imageController = StreamController<File>.broadcast();
  Stream<File> get onNewImage => _imageController.stream;

  /// Imagem atual sendo exibida
  File? _currentImage;
  File? get currentImage => _currentImage;

  /// Verifica se o diretório existe e é válido
  Future<bool> validate() async {
    if (!await _directory.exists()) {
      return false;
    }
    // Verificar se é um diretório (não um arquivo)
    final stat = await _directory.stat();
    return stat.type == FileSystemEntityType.directory;
  }

  /// Faz scan inicial e retorna a imagem mais recente
  Future<ImageScanResult> scanExisting() async {
    File? mostRecent;
    DateTime? mostRecentTime;
    var count = 0;

    await for (final entity in _directory.list()) {
      if (entity is File && isImageFile(entity.path)) {
        count++;
        try {
          final modified = await entity.lastModified();
          if (mostRecentTime == null || modified.isAfter(mostRecentTime)) {
            mostRecentTime = modified;
            mostRecent = entity;
          }
        } catch (_) {
          // Ignorar arquivos que não conseguimos ler
        }
      }
    }

    _currentImage = mostRecent;
    return ImageScanResult(mostRecent: mostRecent, count: count);
  }

  /// Inicia o monitoramento
  Future<void> start() async {
    _watcher = DirectoryWatcher(directoryPath);
    _subscription = _watcher!.events.listen(_handleEvent);
  }

  void _handleEvent(WatchEvent event) {
    // Interessados apenas em criação e modificação
    if (event.type == ChangeType.REMOVE) return;

    final path = event.path;
    if (!isImageFile(path)) return;

    final file = File(path);

    // Verificar se o arquivo existe (pode ter sido deletado rapidamente)
    if (!file.existsSync()) return;

    // Atualizar imagem atual e notificar
    _currentImage = file;
    _imageController.add(file);
  }

  /// Para o monitoramento e libera recursos
  Future<void> stop() async {
    await _subscription?.cancel();
    await _imageController.close();
  }

  /// Obtém o nome do arquivo relativo ao diretório monitorado
  String getRelativePath(File file) {
    return p.relative(file.path, from: directoryPath);
  }
}
