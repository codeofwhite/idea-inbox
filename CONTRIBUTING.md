# Contributing

欢迎围绕离线记录和可靠局域网同步提交问题与改进。较大功能请先讨论范围，避免直接引入云端、账号或后台常驻服务。English issues and pull requests are welcome.

## 开发

使用 README 指定的 Flutter 和平台工具链，执行 flutter pub get，保留 pubspec.lock。提交前运行：

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

涉及同步时保留真实 TLS 测试，不要通过跳过证书验证、时间戳覆盖冲突或吞掉数据库异常使测试通过。更改数据库结构时明确迁移与旧数据兼容策略；不要自动清库解决错误。

PR 说明触发场景、行为变化、验证方式和未验证项。避免无关格式化、重构或依赖升级。变更依赖时同步更新锁文件和第三方许可清单。

## 报告问题

提供版本、Android/Windows 版本、复现步骤、预期与实际结果、是否为访客 Wi-Fi，以及脱敏错误文本。最小复现使用虚构记录。

不要上传个人笔记、数据库、完整备份、配对二维码、token、私钥或安全存储文件。安全漏洞请遵循 [SECURITY.md](SECURITY.md)，不要公开可利用细节。

## 发布检查

- 按 README 的真机验收流程记录结果，区分用户反馈与逐项检查。
- 验证离线记录、双向同步、重复同步、并发冲突、断线重试、配对撤销和备份恢复。
- 安卓正式包使用专用 release 签名；密钥、口令不入库。Windows 分发完整构建目录。
- 更新版本、变更说明和依赖许可；安装包另附原生组件及平台 SDK 要求的许可说明。
- 只描述已验证行为，不将回环测试称为双设备验证，不声称通过独立安全审计。
