// lib/src/server.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'html_assets.dart';
import 'watcher.dart';
import 'utils/logger.dart';

/// Helper para indicar que um Future não será awaited intencionalmente
void unawaited(Future<void> future) {}

/// Servidor HTTP com suporte a WebSocket
class ImageServer {
  ImageServer({
    required this.startPort,
    required this.watcher,
  });

  final int startPort;
  final ImageWatcher watcher;

  HttpServer? _server;
  int? _actualPort;
  final List<WebSocket> _clients = [];

  /// Porta em que o servidor está rodando
  int? get port => _actualPort;

  /// URL completa do servidor
  String get url => 'http://localhost:$_actualPort';

  /// Inicia o servidor, tentando portas sequenciais se necessário
  Future<void> start() async {
    var port = startPort;
    const maxAttempts = 100;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        _server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        _actualPort = port;
        break;
      } on SocketException catch (e) {
        if (e.osError?.errorCode == 98 || // Linux: Address already in use
            e.osError?.errorCode == 48 || // macOS: Address already in use
            e.osError?.errorCode == 10048) {
          // Windows: WSAEADDRINUSE
          port++;
          continue;
        }
        rethrow;
      }
    }

    if (_server == null) {
      throw StateError(
        'Não foi possível iniciar servidor. Portas $startPort-${startPort + maxAttempts - 1} indisponíveis.',
      );
    }

    // Escutar requisições
    _server!.listen(_handleRequest);

    // Escutar novas imagens do watcher
    watcher.onNewImage.listen(_broadcastNewImage);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;

    try {
      if (path == '/' || path.isEmpty) {
        await _serveHtml(request);
      } else if (path == '/ws') {
        await _handleWebSocket(request);
      } else if (path.startsWith('/image/')) {
        await _serveImage(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      Logger.error('Erro ao processar requisição: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveHtml(HttpRequest request) async {
    final currentImage = watcher.currentImage;
    final imagePath =
        currentImage != null ? watcher.getRelativePath(currentImage) : null;

    final html = generateHtml(
      wsPort: _actualPort!,
      initialImage: imagePath,
    );

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(html);
    await request.response.close();
  }

  Future<void> _handleWebSocket(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    _clients.add(socket);

    unawaited(socket.done.then((_) {
      _clients.remove(socket);
    }));
  }

  Future<void> _serveImage(HttpRequest request) async {
    // Extrair caminho da imagem (remover /image/ prefix)
    var imagePath = request.uri.path.substring('/image/'.length);
    // Decodificar URL encoding
    imagePath = Uri.decodeComponent(imagePath);

    // Construir caminho completo
    final fullPath = p.join(watcher.directoryPath, imagePath);
    final file = File(fullPath);

    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    // Verificar se é uma imagem válida
    if (!isImageFile(fullPath)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    // Determinar content type
    final ext = p.extension(fullPath).toLowerCase();
    final contentType = _getContentType(ext);

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = contentType
      ..headers.add('Cache-Control', 'no-cache, no-store, must-revalidate');

    await file.openRead().pipe(request.response);
  }

  ContentType _getContentType(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return ContentType('image', 'jpeg');
      case '.png':
        return ContentType('image', 'png');
      case '.gif':
        return ContentType('image', 'gif');
      case '.webp':
        return ContentType('image', 'webp');
      case '.svg':
        return ContentType('image', 'svg+xml');
      case '.bmp':
        return ContentType('image', 'bmp');
      case '.tiff':
      case '.tif':
        return ContentType('image', 'tiff');
      default:
        return ContentType('application', 'octet-stream');
    }
  }

  void _broadcastNewImage(File image) {
    final relativePath = watcher.getRelativePath(image);
    final message = jsonEncode({
      'type': 'new_image',
      'path': relativePath,
    });

    Logger.newImage(relativePath);

    // Enviar para todos os clientes conectados
    for (final client in _clients.toList()) {
      try {
        client.add(message);
      } catch (e) {
        // Cliente provavelmente desconectado
        _clients.remove(client);
      }
    }
  }

  /// Para o servidor
  Future<void> stop() async {
    // Fechar todos os WebSockets
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();

    await _server?.close();
  }
}
