import 'dart:io';

import 'package:path/path.dart' as path;

import './hook_installer.dart' as hook_installer;

class ConfigManager {
  static String _mergeAnalysisOptions(String current, String defaults) {
    // 直接返回模板中的默认配置，完全覆盖目标工程的配置
    return defaults;
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
