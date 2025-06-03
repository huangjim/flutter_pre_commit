# Flutter Pre-Commit 技术文档

## 概述

Flutter Pre-Commit 是一个为 Flutter 项目设计的预提交钩子工具，它可以在代码提交前自动运行代码格式化和静态分析检查，确保代码质量和一致性。本文档详细介绍了该工具的实现原理、使用方法以及如何在特殊情况下跳过检查。

## 实现原理

### 整体架构

Flutter Pre-Commit 主要由以下几个核心组件组成：

1. **钩子安装器 (HookInstaller)**：负责将预提交钩子安装到 Git 仓库中
2. **配置管理器 (ConfigManager)**：管理和应用分析配置文件
3. **预提交脚本 (pre-commit)**：执行实际的代码检查逻辑

### 钩子安装过程

安装过程的主要步骤如下：

1. 验证当前目录是否为有效的 Flutter/Dart 项目（检查 pubspec.yaml 是否存在）
2. 创建工具所需的目录结构（.dart_tool/flutter_pre_commit/）
3. 复制预提交钩子脚本到临时目录
4. 确保项目中存在 analysis_options.yaml 配置文件，如果不存在则创建
5. 将钩子脚本安装到 .git/hooks/pre-commit
6. 设置脚本的可执行权限（在 Unix 系统上）

### 配置管理

配置管理器负责处理 analysis_options.yaml 文件：

1. 检查项目中是否已存在配置文件
2. 如果不存在，则创建默认配置
3. 如果存在，则使用模板中的配置直接覆盖现有配置

### 预提交检查流程

当开发者执行 `git commit` 命令时，预提交钩子会自动执行以下检查：

1. **自动更新**：检查钩子是否为最新版本，如果不是则自动更新
2. **文件筛选**：只检查暂存区中的 Dart 文件
3. **静态分析**：运行 `flutter analyze` 检查代码是否符合规范
4. **格式检查**：运行 `dart format` 检查代码格式
5. **自动修复**：如果发现格式问题，尝试自动修复并重新暂存修改后的文件

## 使用方法

### 安装

1. 添加依赖到项目的 pubspec.yaml 文件：

```yaml
dev_dependencies:
  flutter_pre_commit: ^0.2.0
```

2. 获取依赖：

```bash
flutter pub get
```

3. 安装预提交钩子：

```bash
flutter pub run flutter_pre_commit
```

### 命令行选项

Flutter Pre-Commit 支持以下命令行选项：

- `--force` 或 `-f`：强制覆盖已存在的预提交钩子
- `--skip-checks` 或 `-s`：跳过环境检查
- `--version` 或 `-v`：显示当前版本信息
- `--help` 或 `-h`：显示帮助信息

示例：

```bash
# 标准安装
flutter pub run flutter_pre_commit

# 强制覆盖已存在的钩子
flutter pub run flutter_pre_commit --force

# 跳过环境检查
flutter pub run flutter_pre_commit --skip-checks
```

### 配置分析规则

安装后，工具会创建或更新项目根目录下的 `analysis_options.yaml` 文件。从 0.2.0 版本开始，工具会直接使用模板中的配置覆盖项目中的配置文件，确保所有项目使用统一的代码规范。

默认配置包括：

```yaml
# 包含 Flutter 推荐的 lint 规则
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true       # 强制使用 const 构造函数
    depend_on_referenced_packages: false
  # 可以取消注释以启用或禁用特定规则
  # avoid_print: false
  # prefer_single_quotes: true
```

## 跳过检查

在某些特殊情况下，你可能需要跳过预提交检查。有以下几种方法：

### 临时跳过单次提交

使用 Git 的 `--no-verify` 选项可以跳过预提交钩子：

```bash
git commit -m "紧急修复" --no-verify
```

**注意**：这种方式会完全跳过所有预提交检查，应谨慎使用。

### 跳过特定文件的检查

如果你只想跳过对特定文件的检查，可以在文件中添加特定的注释：

```dart
// ignore_for_file: avoid_print, prefer_const_constructors
```

这样可以针对该文件忽略特定的 lint 规则。

### 跳过特定代码行的检查

对于特定的代码行，可以使用行内注释跳过检查：

```dart
print('调试信息'); // ignore: avoid_print
```

## 故障排除

### 钩子未执行

如果预提交钩子未执行，请检查以下几点：

1. 确保钩子文件具有执行权限：

```bash
chmod +x .git/hooks/pre-commit
```

2. 确认钩子文件存在：

```bash
ls -la .git/hooks/
```

### 检查失败但需要强制提交

如果检查失败但你确实需要提交代码（例如临时保存工作进度），可以使用 `--no-verify` 选项：

```bash
git commit -m "WIP: 临时保存进度" --no-verify
```

### 更新钩子

如果你更新了 flutter_pre_commit 包，钩子会在下次提交时自动更新。如果想手动更新，可以重新运行安装命令：

```bash
flutter pub run flutter_pre_commit --force
```

## 技术细节

### 文件结构

```
flutter_pre_commit/
├── bin/
│   └── flutter_pre_commit.dart  # 命令行入口
├── lib/
│   ├── flutter_pre_commit.dart  # 主库文件
│   └── src/
│       ├── config_manager.dart  # 配置管理
│       └── hook_installer.dart  # 钩子安装
└── templates/
    ├── analysis_options.yaml    # 分析配置模板
    └── pre-commit              # 预提交钩子模板
```

### 钩子脚本工作流程

1. **自动更新检查**：比较源文件和目标文件，如有不同则更新
2. **获取暂存文件**：使用 `git diff --cached` 获取暂存区中的 Dart 文件
3. **静态分析**：运行 `flutter analyze` 检查代码
4. **格式检查**：运行 `dart format --output=none --set-exit-if-changed` 检查格式
5. **自动修复**：如有格式问题，运行 `dart format` 修复并重新暂存文件

## 最佳实践

1. 在团队项目中统一使用 flutter_pre_commit，确保所有开发者遵循相同的代码规范
2. 定期更新 flutter_pre_commit 包，以获取最新的功能和改进
3. 避免频繁使用 `--no-verify` 选项跳过检查
4. 考虑在 CI/CD 流程中也添加类似的检查，作为双重保障

## 贡献

欢迎通过 GitHub Issues 和 Pull Requests 贡献代码和提出建议。

## 许可证

本项目采用 MIT 许可证。详见 LICENSE 文件。
