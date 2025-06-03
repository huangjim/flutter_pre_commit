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
    try {
      // 获取模板文件路径并复制pre-commit文件
      final templatePath = findTemplateFile('pre-commit');
      final targetFile = File(path.join(targetDir.path, 'pre-commit'));
      
      print('找到模板文件路径: $templatePath');
      final templateContent = File(templatePath).readAsStringSync();
      targetFile.writeAsStringSync(templateContent);
      
      // 设置权限（Unix系统）
      if (Platform.isLinux || Platform.isMacOS) {
        Process.runSync('chmod', ['+x', targetFile.path]);
      }
      
      // 复制analysis_options.yaml
      try {
        final analysisTemplatePath = findTemplateFile('analysis_options.yaml');
        final analysisTargetFile = File(path.join(targetDir.path, 'analysis_options.yaml'));
        
        print('找到分析配置模板文件路径: $analysisTemplatePath');
        final analysisContent = File(analysisTemplatePath).readAsStringSync();
        analysisTargetFile.writeAsStringSync(analysisContent);
      } catch (e) {
        print('复制analysis_options.yaml失败，但这不是关键错误: $e');
      }
    } catch (e) {
      print('复制钩子脚本失败: $e');
      // 尝试使用内置模板作为备用
      _useEmbeddedTemplate(targetDir);
    }
  }

  // 内置模板内容作为备用
  static void _useEmbeddedTemplate(Directory targetDir) {
    print('使用内置模板作为备用');
    final preCommitContent = '''#!/bin/sh
# Flutter pre-commit hook

DART_TOOL_FOLDER=\"\$(dirname \"\$0\")/../../\"\n
cd \"\\\$DART_TOOL_FOLDER\" || exit 1

exec dart analyze
''';
    
    final targetFile = File(path.join(targetDir.path, 'pre-commit'));
    targetFile.writeAsStringSync(preCommitContent);
    
    if (Platform.isLinux || Platform.isMacOS) {
      Process.runSync('chmod', ['+x', targetFile.path]);
    }
    
    // 内置analysis_options.yaml内容
    final analysisContent = '''include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_single_quotes
    - sort_child_properties_last
    - avoid_print
''';
    
    final analysisTargetFile = File(path.join(targetDir.path, 'analysis_options.yaml'));
    analysisTargetFile.writeAsStringSync(analysisContent);
  }

  // 尝试多种策略查找模板文件
  static String findTemplateFile(String filename) {
    print('查找模板文件: $filename');
    final possiblePaths = <String>[];
    
    // 1. 当前项目根目录下的lib/templates
    possiblePaths.add(path.join(Directory.current.path, 'lib', 'templates', filename));
    
    // 2. 当前项目根目录下的templates
    possiblePaths.add(path.join(Directory.current.path, 'templates', filename));
    
    // 3. 包所在目录下的lib/templates
    try {
      final scriptPath = Platform.script.toFilePath();
      print('当前脚本路径: $scriptPath');
      
      // 向上查找包根目录
      String? packageDir;
      
      // 3.1 如果是在.dart_tool/pub/bin中运行
      if (scriptPath.contains('.dart_tool/pub/bin/flutter_pre_commit')) {
        // 从脚本路径向上找，看看是否能找到package
        var dir = path.dirname(scriptPath);
        // 向上最多查找10层目录
        for (var i = 0; i < 10; i++) {
          final libTemplatesDir = path.join(dir, 'lib', 'templates');
          final templatesDir = path.join(dir, 'templates');
          
          if (Directory(libTemplatesDir).existsSync()) {
            packageDir = dir;
            break;
          }
          if (Directory(templatesDir).existsSync()) {
            packageDir = dir;
            break;
          }
          dir = path.dirname(dir);
        }
      } 
      // 3.2 如果是在开发模式下运行
      else if (scriptPath.contains('bin/flutter_pre_commit.dart')) {
        packageDir = path.dirname(path.dirname(scriptPath));
      }
      
      if (packageDir != null) {
        possiblePaths.add(path.join(packageDir, 'lib', 'templates', filename));
        possiblePaths.add(path.join(packageDir, 'templates', filename));
      }
    } catch (e) {
      print('查找包路径时出错: $e');
    }
    
    // 4. 对于本地路径引用，尝试查找相对路径
    try {
      final currentDir = Directory.current.path;
      final localPackagePath = path.join(currentDir, '..', 'flutter_pre_commit');
      if (Directory(localPackagePath).existsSync()) {
        possiblePaths.add(path.join(localPackagePath, 'lib', 'templates', filename));
        possiblePaths.add(path.join(localPackagePath, 'templates', filename));
      }
    } catch (e) {
      print('查找本地包路径时出错: $e');
    }
    
    // 5. 尝试在.dart_tool/package_config.json中查找包路径
    try {
      final packageConfigFile = File(path.join(Directory.current.path, '.dart_tool', 'package_config.json'));
      if (packageConfigFile.existsSync()) {
        final content = packageConfigFile.readAsStringSync();
        final packageIndex = content.indexOf('"name":"flutter_pre_commit"');
        if (packageIndex != -1) {
          final rootUriIndex = content.indexOf('"rootUri":', packageIndex);
          if (rootUriIndex != -1) {
            final startQuote = content.indexOf('"', rootUriIndex + 10);
            final endQuote = content.indexOf('"', startQuote + 1);
            if (startQuote != -1 && endQuote != -1) {
              var packageUri = content.substring(startQuote + 1, endQuote);
              // 移除file://前缀
              if (packageUri.startsWith('file://')) {
                packageUri = packageUri.substring(7);
              }
              possiblePaths.add(path.join(packageUri, 'lib', 'templates', filename));
              possiblePaths.add(path.join(packageUri, 'templates', filename));
            }
          }
        }
      }
    } catch (e) {
      print('读取package_config.json时出错: $e');
    }
    
    // 尝试所有可能的路径
    for (final pathToCheck in possiblePaths) {
      print('检查路径: $pathToCheck');
      if (File(pathToCheck).existsSync()) {
        print('找到模板文件: $pathToCheck');
        return pathToCheck;
      }
    }
    
    // 如果以上方法都失败，抛出异常
    throw Exception('找不到模板文件 $filename，尝试了以下路径: \n${possiblePaths.join('\n')}');
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
