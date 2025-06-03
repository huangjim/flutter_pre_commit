#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pre_commit/flutter_pre_commit.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'force',
      abbr: 'f',
      defaultsTo: false,
      help: 'Force overwrite existing hook',
    )
    ..addFlag(
      'skip-checks',
      abbr: 's',
      defaultsTo: false,
      help: 'Skip environment checks',
    )
    ..addFlag(
      'version',
      abbr: 'v',
      defaultsTo: false,
      help: 'Print current version',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      defaultsTo: false,
      help: 'Show usage information',
    );

  try {
    final results = parser.parse(args);

    if (results['help'] as bool) {
      _printHelp(parser);
      return;
    }

    if (results['version'] as bool) {
      _printVersion();
      return;
    }

    // 环境预检
    if (!(results['skip-checks'] as bool)) {
      debugPrint('⚙️ Performing pre-install checks...');
      await preInstallCheck();
      debugPrint('✓ Environment checks passed');
    }

    // 执行安装
    debugPrint('🔄 Installing pre-commit hook...');
    await HookInstaller.install(force: results['force'] as bool);

    debugPrint('\n✅ Installation completed successfully!');
    debugPrint('   Pre-commit hook will now validate your Dart code');
  } catch (e) {
    debugPrint('\n❌ Installation failed: ${e.toString()}');
    debugPrint('   Use --skip-checks to bypass validation (not recommended)');
    exit(1);
  }
}

void _printHelp(ArgParser parser) {
  debugPrint('''
Flutter Pre-Commit Hook Installer v$packageVersion

Usage:
  flutter pub run flutter_pre_commit:install [options]

Options:
${parser.usage}

Examples:
  # Standard installation
  flutter pub run flutter_pre_commit:install
  
  # Force overwrite existing hook
  flutter pub run flutter_pre_commit:install --force
  
  # Skip environment checks
  flutter pub run flutter_pre_commit:install --skip-checks
''');
}

void _printVersion() {
  print('''
flutter_pre_commit v$packageVersion
Minimum required Flutter version: $minFlutterVersion
''');
}