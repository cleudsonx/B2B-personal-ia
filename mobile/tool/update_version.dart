import 'dart:convert';
import 'dart:io';

/// Script de Versionamento Automático PWA & Mobile
///
/// Uso:
///   dart run tool/update_version.dart
///   dart run tool/update_version.dart --bump=patch
///   dart run tool/update_version.dart --bump=minor
///   dart run tool/update_version.dart --set-version=1.3.1
///   dart run tool/update_version.dart --notes="Atualização de estabilidade"
void main(List<String> args) {
  // 1. Determina o diretório base do mobile
  Directory current = Directory.current;
  Directory mobileDir;
  if (File('${current.path}/pubspec.yaml').existsSync()) {
    mobileDir = current;
  } else if (File('${current.path}/mobile/pubspec.yaml').existsSync()) {
    mobileDir = Directory('${current.path}/mobile');
  } else {
    stderr.writeln('ERRO: Não foi possível localizar mobile/pubspec.yaml');
    exit(1);
  }

  stdout.writeln('🔧 Executando auto-versionamento em: ${mobileDir.path}');

  final pubspecFile = File('${mobileDir.path}/pubspec.yaml');
  final appConfigFile = File('${mobileDir.path}/lib/core/config/app_config.dart');
  final webVersionFile = File('${mobileDir.path}/web/version.json');
  final indexHtmlFile = File('${mobileDir.path}/web/index.html');
  final buildWebDir = Directory('${mobileDir.path}/build/web');

  if (!pubspecFile.existsSync()) {
    stderr.writeln('ERRO: pubspec.yaml não encontrado');
    exit(1);
  }

  // 2. Lê versão atual do pubspec.yaml
  final pubspecContent = pubspecFile.readAsStringSync();
  final versionRegex = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?', multiLine: true);
  final match = versionRegex.firstMatch(pubspecContent);

  if (match == null) {
    stderr.writeln('ERRO: Linha de versão não encontrada no pubspec.yaml');
    exit(1);
  }

  String currentSemVer = match.group(1)!;
  int currentBuild = int.tryParse(match.group(2) ?? '0') ?? 0;

  // 3. Processa argumentos CLI
  String targetSemVer = currentSemVer;
  String? customNotes;

  for (final arg in args) {
    if (arg.startsWith('--set-version=')) {
      targetSemVer = arg.split('=')[1].trim();
    } else if (arg == '--bump=patch') {
      final parts = currentSemVer.split('.').map(int.parse).toList();
      targetSemVer = '${parts[0]}.${parts[1]}.${parts[2] + 1}';
    } else if (arg == '--bump=minor') {
      final parts = currentSemVer.split('.').map(int.parse).toList();
      targetSemVer = '${parts[0]}.${parts[1] + 1}.0';
    } else if (arg == '--bump=major') {
      final parts = currentSemVer.split('.').map(int.parse).toList();
      targetSemVer = '${parts[0] + 1}.0.0';
    } else if (arg.startsWith('--notes=')) {
      customNotes = arg.substring('--notes='.length).trim();
    }
  }

  if (!RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$').hasMatch(targetSemVer)) {
    stderr.writeln('ERRO: Versão de destino inválida: "$targetSemVer". Formato esperado: X.Y.Z');
    exit(1);
  }

  // 4. Calcula novo buildNumber (estritamente monotônico a cada commit/deploy e seguro para 32-bit int)
  final now = DateTime.now().toUtc();
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  final todayPrefix = '$year$month$day'; // ex: 20261017

  int gitCommitCount = 0;
  try {
    final res = Process.runSync('git', ['rev-list', '--count', 'HEAD'], workingDirectory: mobileDir.path);
    if (res.exitCode == 0) {
      gitCommitCount = int.tryParse(res.stdout.toString().trim()) ?? 0;
    }
  } catch (_) {}

  int newBuildNumber;
  final currentBuildStr = currentBuild.toString();

  if (currentBuildStr.length == 10 && currentBuildStr.startsWith(todayPrefix)) {
    newBuildNumber = currentBuild + 1;
  } else {
    final candidate = int.parse('${todayPrefix}01');
    if (candidate > currentBuild) {
      newBuildNumber = candidate;
    } else {
      newBuildNumber = currentBuild + 1;
    }
  }

  // Garante incremento automático mesmo quando o CI roda sem commitar pubspec.yaml de volta:
  if (gitCommitCount > 0) {
    final commitBasedBuild = 2026102600 + gitCommitCount;
    if (commitBasedBuild > newBuildNumber) {
      newBuildNumber = commitBasedBuild;
    }
  }

  // Formatação de data em português
  const meses = [
    '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];
  final dateFormatted = '${now.day} de ${meses[now.month]}, ${now.year}';
  final isoTimestamp = now.toIso8601String();

  stdout.writeln('📦 Versão anterior: $currentSemVer+$currentBuild');
  stdout.writeln('🚀 Nova versão:     $targetSemVer+$newBuildNumber');
  stdout.writeln('📅 Data UTC:        $isoTimestamp ($dateFormatted)');

  // 5. Atualiza pubspec.yaml
  final updatedPubspec = pubspecContent.replaceFirst(
    versionRegex,
    'version: $targetSemVer+$newBuildNumber',
  );
  pubspecFile.writeAsStringSync(updatedPubspec);
  stdout.writeln('✅ Atualizado: mobile/pubspec.yaml');

  // 6. Atualiza lib/core/config/app_config.dart
  if (appConfigFile.existsSync()) {
    var configContent = appConfigFile.readAsStringSync();
    configContent = configContent.replaceAll(
      RegExp(r"static const String appVersion = '[^']+';"),
      "static const String appVersion = '$targetSemVer';",
    );
    configContent = configContent.replaceAll(
      RegExp(r'static const int buildNumber = [0-9]+;'),
      'static const int buildNumber = $newBuildNumber;',
    );
    configContent = configContent.replaceAll(
      RegExp(r"static const String buildDate = '[^']+';"),
      "static const String buildDate = '$dateFormatted';",
    );
    if (customNotes != null && customNotes.isNotEmpty) {
      configContent = configContent.replaceAll(
        RegExp(r"static const String releaseNotes =\s*'[^']*';", multiLine: true),
        "static const String releaseNotes = '$customNotes';",
      );
    }
    appConfigFile.writeAsStringSync(configContent);
    stdout.writeln('✅ Atualizado: mobile/lib/core/config/app_config.dart');
  }

  // 6.1 Atualiza o topo de lib/core/config/app_changelog.dart para manter buildNumber sincronizado
  final changelogFile = File('${mobileDir.path}/lib/core/config/app_changelog.dart');
  if (changelogFile.existsSync()) {
    var changelogContent = changelogFile.readAsStringSync();
    changelogContent = changelogContent.replaceFirst(
      RegExp(r"version:\s*'[^']+'"),
      "version: '$targetSemVer'",
    );
    changelogContent = changelogContent.replaceFirst(
      RegExp(r'buildNumber:\s*[0-9]+'),
      'buildNumber: $newBuildNumber',
    );
    changelogFile.writeAsStringSync(changelogContent);
    stdout.writeln('✅ Atualizado: mobile/lib/core/config/app_changelog.dart');
  }

  // 7. Atualiza web/version.json
  String existingNotes = 'Atualização automática de sistema';
  if (webVersionFile.existsSync()) {
    try {
      final json = jsonDecode(webVersionFile.readAsStringSync()) as Map<String, dynamic>;
      if (json['notes'] != null && json['notes'].toString().isNotEmpty) {
        existingNotes = json['notes'].toString();
      }
    } catch (_) {}
  }
  if (customNotes != null && customNotes.isNotEmpty) {
    existingNotes = customNotes;
  }

  final versionJsonData = {
    'version': targetSemVer,
    'build': newBuildNumber,
    'updated_at': isoTimestamp,
    'notes': existingNotes,
  };
  final jsonString = const JsonEncoder.withIndent('  ').convert(versionJsonData);
  webVersionFile.writeAsStringSync('$jsonString\n');
  stdout.writeln('✅ Atualizado: mobile/web/version.json');

  // 8. Atualiza web/index.html (APP_CURRENT_BUILD)
  if (indexHtmlFile.existsSync()) {
    var indexContent = indexHtmlFile.readAsStringSync();
    final buildConstRegex = RegExp(r'const APP_CURRENT_BUILD = [0-9]+;');
    if (buildConstRegex.hasMatch(indexContent)) {
      indexContent = indexContent.replaceFirst(
        buildConstRegex,
        'const APP_CURRENT_BUILD = $newBuildNumber;',
      );
      indexHtmlFile.writeAsStringSync(indexContent);
      stdout.writeln('✅ Atualizado: mobile/web/index.html (APP_CURRENT_BUILD = $newBuildNumber)');
    }
  }

  // 9. Se existir build/web, copia o version.json compilado diretamente
  if (buildWebDir.existsSync()) {
    final compiledVersionFile = File('${buildWebDir.path}/version.json');
    compiledVersionFile.writeAsStringSync('$jsonString\n');
    stdout.writeln('✅ Sincronizado: mobile/build/web/version.json');
  }

  stdout.writeln('🎉 Auto-versionamento concluído com sucesso!');
}

