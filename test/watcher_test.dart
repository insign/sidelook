import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import 'package:sidelook/src/watcher.dart';
import 'package:path/path.dart' as p;

void main() {
  group('isImageFile', () {
    test('aceita jpg', () => expect(isImageFile('foto.jpg'), isTrue));
    test('aceita jpeg', () => expect(isImageFile('foto.jpeg'), isTrue));
    test('aceita png',
        () => expect(isImageFile('foto.PNG'), isTrue)); // case insensitive
    test('aceita gif', () => expect(isImageFile('animacao.gif'), isTrue));
    test('aceita webp', () => expect(isImageFile('imagem.webp'), isTrue));
    test('aceita svg', () => expect(isImageFile('vetor.svg'), isTrue));
    test('aceita bmp', () => expect(isImageFile('bitmap.bmp'), isTrue));
    test('aceita tiff', () => expect(isImageFile('scan.tiff'), isTrue));
    test('aceita tif', () => expect(isImageFile('scan.tif'), isTrue));

    test('rejeita txt', () => expect(isImageFile('arquivo.txt'), isFalse));
    test('rejeita pdf', () => expect(isImageFile('doc.pdf'), isFalse));
    test('rejeita sem extensão', () => expect(isImageFile('arquivo'), isFalse));
  });

  group('ImageWatcher', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sidelook_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('validate retorna true para diretório válido', () async {
      final watcher = ImageWatcher(tempDir.path);
      expect(await watcher.validate(), isTrue);
    });

    test('validate retorna false para diretório inexistente', () async {
      final watcher = ImageWatcher('/caminho/que/nao/existe');
      expect(await watcher.validate(), isFalse);
    });

    test('scanExisting encontra imagem mais recente', () async {
      // Criar algumas imagens com diferentes timestamps
      final img1 = File(p.join(tempDir.path, 'img1.png'));
      await img1.writeAsBytes([0x89, 0x50, 0x4E, 0x47]); // PNG magic bytes
      await Future<void>.delayed(Duration(milliseconds: 100));

      final img2 = File(p.join(tempDir.path, 'img2.jpg'));
      await img2.writeAsBytes([0xFF, 0xD8, 0xFF]); // JPEG magic bytes

      final watcher = ImageWatcher(tempDir.path);
      final result = await watcher.scanExisting();

      expect(result.count, equals(2));
      expect(result.mostRecent?.path, equals(img2.path));
    });

    test('scanExisting retorna null se não há imagens', () async {
      // Criar arquivo não-imagem
      final txt = File(p.join(tempDir.path, 'readme.txt'));
      await txt.writeAsString('Hello');

      final watcher = ImageWatcher(tempDir.path);
      final result = await watcher.scanExisting();

      expect(result.count, equals(0));
      expect(result.mostRecent, isNull);
    });

    test('detecta nova imagem', () async {
      final watcher = ImageWatcher(tempDir.path);
      await watcher.start();

      // Dar tempo para watcher inicializar
      await Future<void>.delayed(Duration(milliseconds: 100));

      // Criar listener
      final completer = Completer<File>();
      watcher.onNewImage.first.then<void>(completer.complete);

      // Criar nova imagem
      final newImg = File(p.join(tempDir.path, 'nova.png'));
      await newImg.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

      // Aguardar detecção (com timeout)
      final detected = await completer.future.timeout(
        Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Imagem não detectada'),
      );

      expect(detected.path, equals(newImg.path));

      await watcher.stop();
    }, timeout: Timeout(Duration(seconds: 10)));
  });
}
