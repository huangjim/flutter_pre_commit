import 'dart:io';

import 'package:path/path.dart' as path;

import './hook_installer.dart' as hook_installer;

class ConfigManager {
  static String _mergeAnalysisOptions(String current, String defaults) {
    // 检查是否已包含 flutter_pre_commit
    if (current.contains('include: package:flutter_pre_commit/analysis_options.yaml')) {
      return current; // 已包含，不做修改
    }

    // 检查是否包含其他 include
    final includeMatch = RegExp(r'include:\s*([^\n]+)').firstMatch(current);
    if (includeMatch != null) {
      // 有其他 include，需要处理冲突
      final existingInclude = includeMatch.group(1)?.trim() ?? '';

      // 创建flutter_pre_commit的分析配置文件，让它包含原来的配置
      // 然后在项目中只包含flutter_pre_commit
      return current.replaceFirst(
          'include: $existingInclude', 'include: package:flutter_pre_commit/analysis_options.yaml');
    }

    // 没有任何 include，添加 flutter_pre_commit
    return '''
# 包含 flutter_pre_commit 默认规则
include: package:flutter_pre_commit/analysis_options.yaml

# 项目特定规则
$current
''';
  }

  static Future<void> ensureAnalysisOptions(Directory projectDir) async {
    // 获取模板文件的正确路径
    final templatePath =
        hook_installer.HookInstaller.resolvePackagePath('templates/analysis_options.yaml');

    // 读取模板内容
    final defaultOptions = File(templatePath).readAsStringSync();

    // 项目中的 analysis_options.yaml 路径
    final optionsFilePath = path.join(projectDir.path, 'analysis_options.yaml');
    final optionsFile = File(optionsFilePath);

    if (!optionsFile.existsSync()) {
      // 创建默认配置
      optionsFile.writeAsStringSync(defaultOptions);
      print('✅ Created default analysis_options.yaml');
    } else {
      // 合并配置
      final currentOptions = optionsFile.readAsStringSync();
      final mergedOptions = _mergeAnalysisOptions(currentOptions, defaultOptions);

      if (mergedOptions != currentOptions) {
        optionsFile.writeAsStringSync(mergedOptions);
        print('✅ Updated analysis_options.yaml with recommended rules');
      }
    }
  }
}
