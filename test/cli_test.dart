import 'package:test/test.dart';
import 'package:sidelook/src/cli.dart';

void main() {
  late CliParser parser;

  setUp(() {
    parser = CliParser();
  });

  group('CliParser', () {
    test('parse sem argumentos usa diretório atual', () {
      final config = parser.parse([]);
      expect(config.directory, equals('.'));
      expect(config.port, isNull);
      expect(config.update, isFalse);
      expect(config.showVersion, isFalse);
      expect(config.showHelp, isFalse);
    });

    test('parse com diretório', () {
      final config = parser.parse(['/home/user/imagens']);
      expect(config.directory, equals('/home/user/imagens'));
    });

    test('parse --port com valor válido', () {
      final config = parser.parse(['-p', '3000']);
      expect(config.port, equals(3000));
    });

    test('parse -p abreviado', () {
      final config = parser.parse(['-p', '8000']);
      expect(config.port, equals(8000));
    });

    test('parse --port inválido lança exceção', () {
      expect(
        () => parser.parse(['--port', 'abc']),
        throwsA(isA<FormatException>()),
      );
    });

    test('parse --port fora do range lança exceção', () {
      expect(
        () => parser.parse(['--port', '99999']),
        throwsA(isA<FormatException>()),
      );
    });

    test('parse --update', () {
      final config = parser.parse(['--update']);
      expect(config.update, isTrue);
    });

    test('parse -u abreviado', () {
      final config = parser.parse(['-u']);
      expect(config.update, isTrue);
    });

    test('parse --version', () {
      final config = parser.parse(['--version']);
      expect(config.showVersion, isTrue);
    });

    test('parse --help', () {
      final config = parser.parse(['--help']);
      expect(config.showHelp, isTrue);
    });

    test('parse combinação de argumentos', () {
      final config = parser.parse(['-p', '9000', '/tmp/imagens']);
      expect(config.port, equals(9000));
      expect(config.directory, equals('/tmp/imagens'));
    });

    test('usage contém informações essenciais', () {
      final usage = parser.usage;
      expect(usage, contains('sidelook'));
      expect(usage, contains('--port'));
      expect(usage, contains('--update'));
      expect(usage, contains('--version'));
      expect(usage, contains('--help'));
    });
  });
}
