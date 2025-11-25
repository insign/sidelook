import 'package:test/test.dart';
import 'package:sidelook/src/utils/version_compare.dart';

void main() {
  group('VersionCompare', () {
    group('normalize', () {
      test('remove prefixo v', () {
        expect(VersionCompare.normalize('v1.2.3'), equals('1.2.3'));
      });

      test('remove sufixo -beta', () {
        expect(VersionCompare.normalize('1.2.3-beta'), equals('1.2.3'));
      });

      test('remove sufixo +build', () {
        expect(VersionCompare.normalize('1.2.3+456'), equals('1.2.3'));
      });

      test('mantém versão limpa', () {
        expect(VersionCompare.normalize('1.2.3'), equals('1.2.3'));
      });
    });

    group('parse', () {
      test('versão completa', () {
        expect(VersionCompare.parse('1.2.3'), equals([1, 2, 3]));
      });

      test('versão sem patch', () {
        expect(VersionCompare.parse('1.2'), equals([1, 2, 0]));
      });

      test('versão só major', () {
        expect(VersionCompare.parse('1'), equals([1, 0, 0]));
      });
    });

    group('compare', () {
      test('versão igual', () {
        expect(
          VersionCompare.compare('1.0.0', '1.0.0'),
          equals(VersionComparison.equal),
        );
      });

      test('local mais antiga (major)', () {
        expect(
          VersionCompare.compare('1.0.0', '2.0.0'),
          equals(VersionComparison.older),
        );
      });

      test('local mais antiga (minor)', () {
        expect(
          VersionCompare.compare('1.1.0', '1.2.0'),
          equals(VersionComparison.older),
        );
      });

      test('local mais antiga (patch)', () {
        expect(
          VersionCompare.compare('1.0.0', '1.0.1'),
          equals(VersionComparison.older),
        );
      });

      test('local mais recente', () {
        expect(
          VersionCompare.compare('2.0.0', '1.0.0'),
          equals(VersionComparison.newer),
        );
      });

      test('ignora prefixo v', () {
        expect(
          VersionCompare.compare('v1.0.0', '1.0.0'),
          equals(VersionComparison.equal),
        );
      });
    });

    group('hasUpdate', () {
      test('retorna true quando há atualização', () {
        expect(VersionCompare.hasUpdate('1.0.0', '1.0.1'), isTrue);
      });

      test('retorna false quando versões iguais', () {
        expect(VersionCompare.hasUpdate('1.0.0', '1.0.0'), isFalse);
      });

      test('retorna false quando local é mais recente', () {
        expect(VersionCompare.hasUpdate('2.0.0', '1.0.0'), isFalse);
      });
    });
  });
}
