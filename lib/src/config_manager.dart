import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import './hook_installer.dart' as hook_installer;

class ConfigManager {
  // static Future<void> ensureAnalysisOptions(Directory projectDir) async {
  //
  //   // 使用相同的路径解析方法
  //   final templatePath = hook_installer.HookInstaller.resolvePackagePath(
  //       'templates/analysis_options.yaml'
  //   );
  //
  //   final optionsFile = File(path.join(projectDir.path, templatePath));
  //
  //   if (!optionsFile.existsSync()) {
  //     // 创建默认配置
  //     _createDefaultAnalysisOptions(optionsFile);
  //     print('ℹ️ Created default analysis_options.yaml');
  //     return;
  //   }
  //
  //   // 检查是否需要更新
  //   final currentContent = optionsFile.readAsStringSync();
  //   final defaultContent = await _getDefaultAnalysisOptions();
  //
  //   if (!currentContent.contains('flutter_pre_commit')) {
  //     // 合并配置
  //     final mergedContent = _mergeAnalysisOptions(currentContent, defaultContent);
  //     optionsFile.writeAsStringSync(mergedContent);
  //     print('🔄 Updated analysis_options.yaml with latest rules');
  //   }
  // }

  // static String _mergeAnalysisOptions(String current, String defaults) {
  //   try {
  //     // 解析当前配置
  //     final currentMap = loadYaml(current) as Map? ?? {};
  //     // 解析默认配置
  //     final defaultMap = loadYaml(defaults) as Map? ?? {};
  //
  //     // 创建一个新的合并配置
  //     final mergedMap = Map<String, dynamic>.from(currentMap.cast<String, dynamic>());
  //
  //     // 只添加默认配置中不存在于当前配置的键
  //     defaultMap.cast<String, dynamic>().forEach((key, value) {
  //       if (!mergedMap.containsKey(key)) {
  //         mergedMap[key] = value;
  //       } else if (key == 'analyzer' && value is Map) {
  //         // 特殊处理 analyzer 部分
  //         if (!mergedMap['analyzer'].containsKey('plugins')) {
  //           mergedMap['analyzer']['plugins'] = value['plugins'];
  //         }
  //       }
  //     });
  //
  //     // 添加包含指令
  //     if (!mergedMap.containsKey('include')) {
  //       mergedMap['include'] = 'package:flutter_pre_commit/analysis_options.yaml';
  //     }
  //
  //     // 将合并后的配置转换为YAML字符串
  //     return _toYamlString(mergedMap);
  //   } catch (e) {
  //     print('⚠️ Error merging analysis options: $e');
  //     // 出错时回退到默认配置
  //     return defaults;
  //   }
  // }

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
          'include: $existingInclude',
          'include: package:flutter_pre_commit/analysis_options.yaml'
      );
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
    final templatePath = hook_installer.HookInstaller.resolvePackagePath(
        'templates/analysis_options.yaml'
    );

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

  static String x(String current, String defaults) {
    try {
      // 解析当前配置
      final currentMap = loadYaml(current) as Map? ?? {};
      // 解析默认配置
      final defaultMap = loadYaml(defaults) as Map? ?? {};

      // 深度合并配置
      final mergedMap = _deepMergeMaps(
          currentMap.cast<String, dynamic>(),
          defaultMap.cast<String, dynamic>()
      );

      // 将合并后的配置转换为YAML字符串
      return _toYamlString(mergedMap);
    } catch (e) {
      print('⚠️ Error merging analysis options: $e');
      // 出错时回退到默认配置
      return defaults;
    }
  }

  static void _writeYamlList(List list, StringBuffer buffer, int indent) {
    final indentStr = '  ' * indent;

    for (final item in list) {
      buffer.write('$indentStr- ');

      if (item is Map<String, dynamic>) {
        buffer.writeln();
        _writeYamlMap(item, buffer, indent + 1);
      } else if (item is List) {
        buffer.writeln();
        _writeYamlList(item, buffer, indent + 1);
      } else {
        buffer.writeln('$item');
      }
    }
  }

  static void _writeYamlMap(Map<String, dynamic> map, StringBuffer buffer, int indent) {
    final indentStr = '  ' * indent;

    map.forEach((key, value) {
      buffer.write('$indentStr$key:');

      if (value is Map<String, dynamic>) {
        buffer.writeln();
        _writeYamlMap(value, buffer, indent + 1);
      } else if (value is List) {
        buffer.writeln();
        _writeYamlList(value, buffer, indent + 1);
      } else {
        buffer.writeln(' $value');
      }
    });
  }

  static String _toYamlString(Map<String, dynamic> map) {
    final buffer = StringBuffer();
    _writeYamlMap(map, buffer, 0);
    return buffer.toString();
  }

  static Map<String, dynamic> _deepMergeMaps(
      Map<String, dynamic> map1,
      Map<String, dynamic> map2
      ) {
    final result = Map<String, dynamic>.from(map1);

    map2.forEach((key, value) {
      if (value is Map<String, dynamic> &&
          result.containsKey(key) &&
          result[key] is Map<String, dynamic>) {
        // 递归合并嵌套Map
        result[key] = _deepMergeMaps(
            result[key] as Map<String, dynamic>,
            value
        );
      } else if (value is List &&
          result.containsKey(key) &&
          result[key] is List) {
        // 合并列表，去重
        final combinedList = [
          ...(result[key] as List),
          ...value
        ].toSet().toList();
        result[key] = combinedList;
      } else {
        // 覆盖其他值
        result[key] = value;
      }
    });

    return result;
  }
}