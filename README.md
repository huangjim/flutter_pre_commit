<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# Flutter Pre-Commit

A unified pre-commit hook tool for Flutter projects that automatically runs code formatting and static analysis checks before committing code.

[![pub package](https://img.shields.io/pub/v/flutter_pre_commit.svg)](https://pub.dev/packages/flutter_pre_commit)

## Features

- Automatically installs Git pre-commit hook
- Runs `dart format` to check code formatting before commit
- Runs `flutter analyze` for static code analysis before commit
- Only checks Dart files in the staging area
- Provides friendly error messages
- Easy to install and configure

## Installation

### Add Dependency

Add flutter_pre_commit to the dev_dependencies section of your `pubspec.yaml` file:

```yaml
dev_dependencies:
  flutter_pre_commit: ^0.2.1
```

Then run:

```bash
flutter pub get
```

### Install Pre-commit Hook

Run the following command to install the pre-commit hook:

```bash
flutter pub run flutter_pre_commit
```

This will install the pre-commit hook in your Git repository and create necessary configuration files.

## Usage

Once installed, the pre-commit hook will run automatically. When you try to commit code, the hook will:

1. Check Dart files in the staging area
2. Run `dart format` to check code formatting
3. Run `flutter analyze` for static analysis
4. Block the commit and display error messages if checks fail

### Example Output

Success:
```
🚀 Running Flutter pre-commit checks...
✅ All checks passed!
```

Failure:
```
🚀 Running Flutter pre-commit checks...
❌ Dart format check failed. Please run 'dart format .' to fix formatting issues.
[Error details]
```

## Configuration

### Analysis Options

flutter_pre_commit will create or update the `analysis_options.yaml` file in your project root. The default configuration includes:

```yaml
# Include flutter_pre_commit default rules
include: package:flutter_pre_commit/analysis_options.yaml

# You can add or override rules here
linter:
  rules:
    # Custom rules
```

You can modify this file to customize analysis rules.

### Force Update

To force update an existing pre-commit hook, use the `--force` option:

```bash
flutter pub run flutter_pre_commit --force
```

## Troubleshooting

### Hook Not Running

Ensure the Git hook has execute permissions:

```bash
chmod +x .git/hooks/pre-commit
```

### Skipping the Hook

In special cases, if you need to skip pre-commit checks, you can use the `--no-verify` option:

```bash
git commit -m "Your commit message" --no-verify
```

However, this is not recommended as it bypasses code quality checks.

## Contributing

Contributions via Pull Requests or Issues are welcome.

## License

[MIT License](LICENSE)
