// library flutter_pre_commit;

import 'dart:io';

// 导出公共API接口
export 'src/hook_installer.dart' show HookInstaller;
export 'src/config_manager.dart' show ConfigManager;
// export 'src/hook_updater.dart' show HookUpdater;

// 版本信息
const String packageVersion = '0.2.2';
const String minFlutterVersion = '3.7.0';

/// 预检查：验证当前环境是否满足要求
Future<void> preInstallCheck() async {
  // 检查Flutter版本
  final result = await Process.run('flutter', ['--version']);
  if (result.exitCode != 0) {
    throw Exception('Flutter not found. Please install Flutter first.');
  }

  final versionOutput = result.stdout as String;
  final versionMatch =
      RegExp(r'Flutter (\d+\.\d+\.\d+)').firstMatch(versionOutput);

  if (versionMatch == null) {
    throw Exception('Could not determine Flutter version');
  }

  final currentVersion = versionMatch.group(1)!;
  if (_compareVersions(currentVersion, minFlutterVersion) < 0) {
    throw Exception(
        'Flutter $minFlutterVersion+ required. Current: $currentVersion');
  }

  // 检查Git仓库
  if (!Directory('.git').existsSync()) {
    throw Exception('Not a Git repository. Please initialize Git first.');
  }
}

// 辅助函数：比较版本号
int _compareVersions(String v1, String v2) {
  final parts1 = v1.split('.').map(int.parse).toList();
  final parts2 = v2.split('.').map(int.parse).toList();

  for (var i = 0; i < 3; i++) {
    final diff = parts1[i] - parts2[i];
    if (diff != 0) return diff;
  }

  return 0;
}
