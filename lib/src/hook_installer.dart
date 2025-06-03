import 'dart:io';

import 'package:flutter_pre_commit/src/config_manager.dart';
import 'package:path/path.dart' as path;

class HookInstaller {
  static Future<void> install({bool force = false}) async {
    final projectDir = Directory.current;
    final pubspec = File(path.join(projectDir.path, 'pubspec.yaml'));

    if (!pubspec.existsSync()) {
      throw Exception('Not a Dart/Flutter project: pubspec.yaml not found');
    }

    // 创建目标目录
    final targetDir = Directory(path.join(projectDir.path, '.dart_tool', 'flutter_pre_commit'));
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    // 复制钩子脚本
    await _copyHookScript(targetDir);

    // 创建/更新分析配置
    await ConfigManager.ensureAnalysisOptions(projectDir);

    // 安装到 .git/hooks
    _installToGitHooks(targetDir, force);

    print('✅ Flutter pre-commit hook installed successfully!');
    print('   All Dart files will be checked before commit.');
  }

  static Future<void> _copyHookScript(Directory targetDir) async {
// 获取模板文件路径
    final templatePath = _getTemplatePath('pre-commit');

    // 创建目标文件
    final targetFile = File(path.join(targetDir.path, 'pre-commit'));

    // 读取模板内容
    final templateContent = File(templatePath).readAsStringSync();

    // 写入目标位置
    targetFile.writeAsStringSync(templateContent);

    // 设置权限（Unix系统）
    if (Platform.isLinux || Platform.isMacOS) {
      Process.runSync('chmod', ['+x', targetFile.path]);
    }
  }

  static String _getTemplatePath(String templateName) {
    final fullPath = resolvePackagePath(path.join('templates', templateName));

    if (!File(fullPath).existsSync()) {
      throw Exception('Template file not found at: $fullPath');
    }

    return fullPath;
  }
  // 提取包根目录路径// 添加在类外部或类内部静态方法
  static String resolvePackagePath(String relativePath) {
    final scriptPath = Platform.script.toFilePath();
    String packageRoot;

    if (scriptPath.contains('bin/flutter_pre_commit.dart')) {
      packageRoot = path.dirname(path.dirname(scriptPath));
    } else if (scriptPath.contains('.dart_tool/pub/bin/flutter_pre_commit/')) {
      final parts = scriptPath.split(path.separator);
      final packageIndex = parts.indexWhere((part) => part == 'flutter_pre_commit');
      if (packageIndex != -1 && packageIndex + 1 < parts.length) {
        packageRoot = path.joinAll(parts.sublist(0, packageIndex + 1));
      } else {
        packageRoot = path.dirname(scriptPath);
      }
    } else {
      packageRoot = path.dirname(path.dirname(scriptPath));
    }

    if (!packageRoot.startsWith('/')) {
      packageRoot = '/$packageRoot';
    }

    return path.join(packageRoot, relativePath);
  }

  static void _installToGitHooks(Directory sourceDir, bool force) {
    final gitHooksDir = Directory('.git/hooks');

    // 验证 .git/hooks 存在
    if (!gitHooksDir.existsSync()) {
      throw Exception('.git/hooks directory not found');
    }

    final targetFile = File(path.join(gitHooksDir.path, 'pre-commit'));
    final sourceFile = File(path.join(sourceDir.path, 'pre-commit'));

    // 检查是否已存在钩子
    if (targetFile.existsSync()) {
      final content = targetFile.readAsStringSync();

      // 如果是我们的钩子，直接覆盖
      if (content.contains('flutter_pre_commit')) {
        targetFile.writeAsStringSync(sourceFile.readAsStringSync());
      }
      // 如果是其他钩子，根据 force 参数处理
      else if (force) {
        targetFile.writeAsStringSync(sourceFile.readAsStringSync());
      } else {
        throw Exception('Pre-commit hook already exists. Use --force to overwrite');
      }
    }
    // 不存在则直接创建
    else {
      targetFile.writeAsStringSync(sourceFile.readAsStringSync());
    }

    // 设置可执行权限
    if (Platform.isLinux || Platform.isMacOS) {
      Process.runSync('chmod', ['+x', targetFile.path]);
    }
  }
}
