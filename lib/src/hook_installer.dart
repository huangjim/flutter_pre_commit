import 'dart:io';
import 'dart:convert';

import 'package:flutter_pre_commit/src/config_manager.dart';
import 'package:path/path.dart' as path;

class HookInstaller {
  static Future<void> install({bool force = false}) async {
    final projectDir = Directory.current;
    final pubspec = File(path.join(projectDir.path, 'pubspec.yaml'));

    if (!pubspec.existsSync()) {
      throw Exception('Not a Dart/Flutter project: pubspec.yaml not found');
    }

    print('\u2699\ufe0f Performing pre-install checks...');
    print('\u2713 Environment checks passed');
    print('\ud83d\udd04 Installing pre-commit hook...');

    // 直接从模板文件复制并安装到 .git/hooks
    await _installHookScript(force);

    // 创建/更新分析配置
    await ConfigManager.ensureAnalysisOptions(projectDir);

    print('\u2705 Flutter pre-commit hook installed successfully!');
    print('   All Dart files will be checked before commit.');
    
    print('\n\u2705 Installation completed successfully!');
    print('   Pre-commit hook will now validate your Dart code');
  }

  static Future<void> _installHookScript(bool force) async {
    final gitDirPath = path.join(Directory.current.path, '.git');
    final hooksDir = path.join(gitDirPath, 'hooks');
    
    // 确保 hooks 目录存在
    final hooksDirectory = Directory(hooksDir);
    if (!hooksDirectory.existsSync()) {
      hooksDirectory.createSync(recursive: true);
    }
    
    final hookFilePath = path.join(hooksDir, 'pre-commit');
    final preCommitFile = File(hookFilePath);
    
    // 检查是否已存在钩子
    if (preCommitFile.existsSync() && !force) {
      final content = preCommitFile.readAsStringSync();
      
      // 如果不是我们的钩子，且未强制覆盖，则报错
      if (!content.contains('flutter_pre_commit')) {
        throw Exception('Pre-commit hook already exists. Use --force to overwrite');
      }
    }
    
    String preCommitContent;
    
    try {
      // 尝试从模板文件复制
      final templatePath = findTemplateFile('pre-commit');
      preCommitContent = File(templatePath).readAsStringSync();
      print('从模板文件复制钩子脚本: $templatePath');
    } catch (e) {
      // 使用默认内置模板
      print('复制钩子脚本失败: $e');
      print('使用内置模板作为备用');
      preCommitContent = _getDefaultPreCommitTemplate();
    }
    
    // 写入 pre-commit 钩子文件
    preCommitFile.writeAsStringSync(preCommitContent);
    
    // 设置可执行权限
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['+x', hookFilePath]);
    }
    
    print('Git 钩子安装完成: $hookFilePath');
  }

  static String _getDefaultPreCommitTemplate() {
    return '''#!/bin/sh
# Flutter pre-commit hook

DART_TOOL_FOLDER="\$(dirname "\$0")/../../"\n
cd "\$DART_TOOL_FOLDER" || exit 1

exec dart analyze
''';
  }

  // 尝试多种策略查找模板文件
  static String findTemplateFile(String filename) {
    print('查找模板文件: $filename');
    final possiblePaths = <String>[];
    final scriptPath = Platform.script.toFilePath();
    print('当前脚本路径: $scriptPath');
    final currentDir = Directory.current.path;
    print('当前工作目录: $currentDir');
    
    // 1. 首先尝试从 package_config.json 中找到准确的包路径
    try {
      final packageConfigPath = path.join(currentDir, '.dart_tool', 'package_config.json');
      print('从 package_config.json 查找依赖包路径: $packageConfigPath');
      final packageConfigFile = File(packageConfigPath);
      
      if (packageConfigFile.existsSync()) {
        // 首先尝试使用 JSON 解析
        try {
          final content = packageConfigFile.readAsStringSync();
          final jsonData = jsonDecode(content) as Map<String, dynamic>;
          final packages = jsonData['packages'] as List<dynamic>;
          
          for (final package in packages) {
            if (package['name'] == 'flutter_pre_commit') {
              var rootUri = package['rootUri'] as String;
              print('找到依赖包URI: $rootUri');
              
              // 处理相对路径，它们是相对于 .dart_tool 目录的
              if (rootUri.startsWith('file://')) {
                // 绝对 URI
                rootUri = rootUri.substring(7);
              } else if (rootUri.startsWith('../') || rootUri.startsWith('./')) {
                // 相对 URI，从 .dart_tool 目录开始计算
                final dartToolDir = path.dirname(packageConfigPath);
                rootUri = path.normalize(path.join(dartToolDir, rootUri));
              }
              
              // 生成完整的模板路径
              final templatePath = path.join(rootUri, 'lib', 'templates', filename);
              print('检查依赖包模板路径: $templatePath');
              
              if (File(templatePath).existsSync()) {
                print('成功从依赖包找到模板文件: $templatePath');
                return templatePath;
              }
            }
          }
        } catch (e) {
          print('解析 JSON 失败，尝试其他方法: $e');
        }
        
        // 如果 JSON 解析失败，尝试使用正则表达式
        try {
          final content = packageConfigFile.readAsStringSync();
          final packageIndex = content.indexOf('"name":"flutter_pre_commit"');
          
          if (packageIndex != -1) {
            final rootUriIndex = content.indexOf('"rootUri":', packageIndex);
            
            if (rootUriIndex != -1) {
              final startQuote = content.indexOf('"', rootUriIndex + 10);
              final endQuote = content.indexOf('"', startQuote + 1);
              
              if (startQuote != -1 && endQuote != -1) {
                var rootUri = content.substring(startQuote + 1, endQuote);
                print('找到依赖包URI: $rootUri');
                
                // 处理相对路径，它们是相对于 .dart_tool 目录的
                if (rootUri.startsWith('file://')) {
                  // 绝对 URI
                  rootUri = rootUri.substring(7);
                } else if (rootUri.startsWith('../') || rootUri.startsWith('./')) {
                  // 相对 URI，从 .dart_tool 目录开始计算
                  final dartToolDir = path.dirname(packageConfigPath);
                  rootUri = path.normalize(path.join(dartToolDir, rootUri));
                }
                
                // 生成完整的模板路径
                final templatePath = path.join(rootUri, 'lib', 'templates', filename);
                print('检查依赖包模板路径: $templatePath');
                
                if (File(templatePath).existsSync()) {
                  print('成功从依赖包找到模板文件: $templatePath');
                  return templatePath;
                }
              }
            }
          }
        } catch (e) {
          print('使用正则表达式处理失败: $e');
        }
      }
    } catch (e) {
      print('读取 package_config.json 时出错: $e');
    }
    
    // 2. 如果从 package_config.json 找不到，尝试以下其他路径
    
    // 2.1 当前项目根目录下的 lib/templates
    possiblePaths.add(path.join(currentDir, 'lib', 'templates', filename));
    
    // 2.2 当前项目根目录下的 templates
    possiblePaths.add(path.join(currentDir, 'templates', filename));
    
    // 2.3 包所在目录下的 lib/templates（通过脚本路径推断）
    try {
      // 向上查找包根目录
      String? packageDir;
      
      // 2.3.1 如果是在 .dart_tool/pub/bin 中运行
      if (scriptPath.contains('.dart_tool/pub/bin/flutter_pre_commit')) {
        // 从脚本路径向上找，看看是否能找到 package
        var dir = path.dirname(scriptPath);
        // 向上最多查找 10 层目录
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
      // 2.3.2 如果是在开发模式下运行
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
    
    // 2.4 对于本地路径引用，尝试查找相对路径
    try {
      // 2.4.1 直接上一级目录查找
      final localPackagePath = path.join(currentDir, '..', 'flutter_pre_commit');
      if (Directory(localPackagePath).existsSync()) {
        possiblePaths.add(path.join(localPackagePath, 'lib', 'templates', filename));
        possiblePaths.add(path.join(localPackagePath, 'templates', filename));
      }
      
      // 2.4.2 如果在 demo 子目录下，尝试特殊处理
      if (currentDir.contains('/demo/')) {
        // 尝试找到上一级的 demo 目录下的 flutter_pre_commit
        final demoParentDir = path.dirname(path.dirname(currentDir));
        final parentDemoPath = path.join(demoParentDir, 'flutter_pre_commit');
        if (Directory(parentDemoPath).existsSync()) {
          possiblePaths.add(path.join(parentDemoPath, 'lib', 'templates', filename));
          possiblePaths.add(path.join(parentDemoPath, 'templates', filename));
        }
      }
    } catch (e) {
      print('查找本地包路径时出错: $e');
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
    throw Exception('找不到模板文件: $filename，将使用内置模板');
  }
}
