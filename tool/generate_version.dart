// tool/generate_version.dart
// Executar com: dart run tool/generate_version.dart

// ignore_for_file: avoid_print

import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  // Encontrar pubspec.yaml (pode estar em .. se rodando de tool/)
  final scriptDir = p.dirname(Platform.script.toFilePath());
  final projectRoot = p.dirname(scriptDir);

  var pubspecPath = p.join(projectRoot, 'pubspec.yaml');
  if (!File(pubspecPath).existsSync()) {
    // Fallback: talvez esteja rodando do root
    pubspecPath = 'pubspec.yaml';
  }

  final pubspecFile = File(pubspecPath);
  if (!pubspecFile.existsSync()) {
    stderr.writeln('ERRO: pubspec.yaml não encontrado');
    exit(1);
  }

  final content = await pubspecFile.readAsString();
  final yaml = loadYaml(content) as YamlMap;

  final name = yaml['name'] as String? ?? 'sidelook';
  final version = yaml['version'] as String? ?? '0.0.0';
  final description = yaml['description'] as String? ?? '';
  final repository = yaml['repository'] as String? ?? '';

  final output = '''
// GERADO AUTOMATICAMENTE - NÃO EDITAR
// Gerado por: dart run tool/generate_version.dart

/// Nome do pacote
const String packageName = '$name';

/// Versão atual do pacote (semver)
const String packageVersion = '$version';

/// Descrição do pacote
const String packageDescription = '$description';

/// URL do repositório GitHub
const String packageRepository = '$repository';
''';

  // Garantir que diretório existe
  final outputDir = Directory(p.join(projectRoot, 'lib', 'src'));
  if (!outputDir.existsSync()) {
    await outputDir.create(recursive: true);
  }

  final outputFile = File(p.join(outputDir.path, 'version.g.dart'));
  await outputFile.writeAsString(output);

  // Formatar o arquivo gerado
  final result = await Process.run('dart', ['format', outputFile.path]);
  if (result.exitCode != 0) {
    print('Aviso: Não foi possível formatar o arquivo gerado.');
    print(result.stderr);
  }

  print('✓ Gerado: ${outputFile.path}');
  print('  Nome: $name');
  print('  Versão: $version');
}
