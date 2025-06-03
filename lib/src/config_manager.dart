import 'dart:io';

import 'package:path/path.dart' as path;

import './hook_installer.dart' as hook_installer;

class ConfigManager {
  static String _mergeAnalysisOptions(String current, String defaults) {
    // 直接返回模板中的默认配置，完全覆盖目标工程的配置
    return defaults;
  }

  static Future<void> ensureAnalysisOptions(Directory projectDir) async {
    try {
      // 尝试获取分析配置文件内容
      String defaultOptions;
      try {
        // 尝试通过HookInstaller的方法查找模板文件
        final templatePath = hook_installer.HookInstaller.findTemplateFile('analysis_options.yaml');
        defaultOptions = File(templatePath).readAsStringSync();
      } catch (e) {
        print('使用内置分析配置模板：$e');
        // 使用内置模板作为备用
        defaultOptions = '''include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_single_quotes
    - sort_child_properties_last
    - avoid_print
''';
      }

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
    } catch (e) {
      print('配置分析选项时出错: $e');
      // 如果出错，跳过此步骤，继续安装钩子
    }
  }
}
