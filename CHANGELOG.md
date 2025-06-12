## 0.2.4

* fix bug


## 0.2.3

* Improved template file lookup mechanism
* Better handling of package path resolution
* Enhanced error handling with fallback to embedded templates
* Streamlined installation process
* Fixed script execution issues in the pre-commit hook
* Added more comprehensive template search strategies

## 0.2.2

* 全面重构模板文件查找机制，支持各种引用方式（本地路径、pub.dev、Git依赖）
* 增加多层次的模板文件查找策略，提高跨环境兼容性
* 添加内置模板作为备选方案，确保即使找不到模板文件也能成功安装
* 增强错误处理，确保安装过程更加健壮
* 优化日志输出，方便诊断问题
* 标准化包结构，将模板文件统一放置在 lib/templates 目录

## 0.2.1

* 修复模板文件路径解析问题，支持在不同仓库中使用
* 将模板文件添加到包资源中，确保在发布包中可用
* 增强路径查找策略，提高安装成功率

## 0.2.0

* 使用模板配置直接覆盖目标工程的 analysis_options.yaml
* 简化命令行调用方式

## 0.1.0

* Initial release of flutter_pre_commit
* Automatic installation of Git pre-commit hook
* Code formatting check with dart format
* Static analysis with flutter analyze
* Support for custom analysis options
* Path resolution fixes for template files

## 0.0.1

* TODO: Describe initial release.
