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
    final fileName = path.basename(relativePath);
    String packageRoot;
    
    // 尝试多个可能的位置
    final possiblePaths = <String>[];
    
    // 1. 首先尝试从当前脚本路径推断
    if (scriptPath.contains('bin/flutter_pre_commit.dart')) {
      // 开发模式：包根目录是 bin 目录的上级
      packageRoot = path.dirname(path.dirname(scriptPath));
      possiblePaths.add(path.join(packageRoot, relativePath));
    } else if (scriptPath.contains('.dart_tool/pub/bin/flutter_pre_commit')) {
      // 安装模式：需要找到包的实际位置
      final parts = scriptPath.split(path.separator);
      final packageIndex = parts.indexWhere((part) => part == 'flutter_pre_commit');
      if (packageIndex != -1) {
        packageRoot = path.joinAll(parts.sublist(0, packageIndex + 1));
        possiblePaths.add(path.join(packageRoot, relativePath));
      }
    }
    
    // 2. 尝试在当前项目目录下查找
    possiblePaths.add(path.join(Directory.current.path, relativePath));
    
    // 3. 尝试在 lib/templates 目录下查找（作为包资源）
    if (relativePath.startsWith('templates/')) {
      possiblePaths.add(path.join(Directory.current.path, 'lib', relativePath));
    }
    
    // 4. 尝试在包的资源目录中查找
    try {
      // 获取当前工作目录
      final currentDir = Directory.current.path;
      
      // 尝试在当前项目的 .dart_tool/package/flutter_pre_commit 目录下查找
      final packageDir = path.join(currentDir, '.dart_tool', 'package', 'flutter_pre_commit');
      if (File(packageDir).existsSync()) {
        // 读取包目录链接文件
        final packageLink = File(packageDir).readAsStringSync().trim();
        possiblePaths.add(path.join(packageLink, relativePath));
      }
    } catch (e) {
      // 忽略错误，继续尝试其他方法
    }
    
    // 检查所有可能的路径
    for (final pathToCheck in possiblePaths) {
      if (File(pathToCheck).existsSync()) {
        return pathToCheck;
      }
    }
    
    // 如果上述方法都失败，尝试一个最后的方法：查找包含在 lib/templates 中的资源
    final packageName = 'flutter_pre_commit';
    final packagePath = _findPackagePath(packageName);
    if (packagePath != null) {
      final resourcePath = path.join(packagePath, 'lib', 'templates', fileName);
      if (File(resourcePath).existsSync()) {
        return resourcePath;
      }
    }
    
    // 5. 直接尝试使用当前目录下的模板文件
    final directPath = path.join(Directory.current.path, 'templates', fileName);
    if (File(directPath).existsSync()) {
      return directPath;
    }
    
    // 确保路径有前导斜杠
    var resultPath = possiblePaths.isNotEmpty ? possiblePaths.first : path.join('templates', fileName);
    if (!resultPath.startsWith('/')) {
      resultPath = '/$resultPath';
    }
    
    return resultPath;
  }
  
  // 查找包的路径
  static String? _findPackagePath(String packageName) {
    try {
      // 尝试在 .packages 文件中查找包路径
      final packagesFile = File('.packages');
      if (packagesFile.existsSync()) {
        final content = packagesFile.readAsStringSync();
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.startsWith('$packageName:')) {
            final parts = line.split(':');
            if (parts.length > 1) {
              var packageUri = parts[1];
              // 移除 file:// 前缀
              if (packageUri.startsWith('file://')) {
                packageUri = packageUri.substring(7);
              }
              return packageUri;
            }
          }
        }
      }
      
      // 尝试在 .dart_tool/package_config.json 中查找
      final packageConfigFile = File('.dart_tool/package_config.json');
      if (packageConfigFile.existsSync()) {
        final content = packageConfigFile.readAsStringSync();
        final packageIndex = content.indexOf('"name":"$packageName"');
        if (packageIndex != -1) {
          final rootUriIndex = content.indexOf('"rootUri":', packageIndex);
          if (rootUriIndex != -1) {
            final startQuote = content.indexOf('"', rootUriIndex + 10);
            final endQuote = content.indexOf('"', startQuote + 1);
            if (startQuote != -1 && endQuote != -1) {
              var packageUri = content.substring(startQuote + 1, endQuote);
              // 移除 file:// 前缀
              if (packageUri.startsWith('file://')) {
                packageUri = packageUri.substring(7);
              }
              return packageUri;
            }
          }
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
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
