# Idea Inbox

安卓随手记，Windows 接着整理。一个离线优先的纯文字灵感收件箱：记录保存在本机，通过配对后的局域网 HTTPS 连接同步，无需账号或云端。

[English](README.en.md) · [同步协议](docs/sync-protocol.md) · [参与贡献](CONTRIBUTING.md) · [安全说明](SECURITY.md)

## 状态

**0.1.0 开发版。** Windows release、Android debug 已成功构建；静态检查和 14 项自动测试通过。项目作者已反馈 Android + Windows 真机使用功能正常。这是个人使用验证，不代表下列所有异常场景均已验收，也不代表独立安全审计。

本轮开源提供源码；尚未发布安装包或配置正式 Android release 签名。

## 为什么做这个

在公交上、走路时，想到一点东西就先记下来，回到电脑再整理。
第一版只解决“手机离线记，电脑接着用”，保持前台、手动、可理解的同步流程。

## 功能

- 无需标题的纯文字记录，离线新增、编辑和检索。
- 待整理、已归档、回收站；支持恢复。
- 一部 Android 手机与一台 Windows 电脑，前台手动双向同步。
- 电脑显示二维码，手机扫码，电脑确认配对。
- TLS 传输、证书指纹固定、配对凭证认证。
- 不可变修订、重复传输去重、并发冲突保留及手动合并。
- JSON 完整备份与合并恢复；Markdown 导出。
- 无云端、账号、遥测或 AI 服务。可使用系统输入法的语音转文字，输入法的联网行为由其自身设置决定。

## 使用

1. 两端安装自行构建的应用；手机没有网络也能记录。
2. 两端连接可互通的局域网。电脑可以插网线；访客 Wi-Fi 或 AP 隔离可能阻断连接。
3. Windows 在“设备”选择对应的私有 IPv4 地址，开启同步服务。若出现防火墙提示，仅允许可信的专用网络，不要关闭防火墙。
4. 手机扫描电脑二维码，并在电脑确认手机标识。二维码两分钟有效且只能使用一次。
5. 手机点击“立即同步”；同步期间两端保持应用打开。
6. 遇到冲突，在“待整理”打开记录，阅读各版本后合并保存。
7. 定期导出 JSON 备份，存放到独立位置。同步会传播删除状态，不能替代备份。

电脑 IP 变化后，可在手机更新地址，仍校验原电脑证书。一端撤销配对后后续连接失败；已保存的记录不会远程擦除。

## 开发与构建

已验证基线：

| 工具 / 平台 | 版本 |
| --- | --- |
| Flutter / Dart | 3.47.5 / 3.13.4 |
| Windows | Windows 10/11，x64 |
| Visual Studio | Desktop development with C++、Windows SDK、CMake |
| JDK | 21（已使用 Temurin 21.0.13+9） |
| Android | minSdk 24（Android 7.0），targetSdk 36 |
| Android SDK | platforms;android-35、platforms;android-36、build-tools;36.0.0、platform-tools |
| Android 原生工具 | ndk;28.2.13676358、cmake;3.22.1 |
| Gradle wrapper | 9.3.1（随项目固定） |

API 35 和 CMake 3.22.1 是 JNI 依赖的构建要求。先通过 Android SDK Manager 安装组件并接受许可证；JAVA_HOME 指向完整 JDK，ANDROID_HOME 指向 SDK。Windows 构建需允许 Flutter 创建插件符号链接，例如在系统中启用开发者模式。

在项目根目录运行：

```powershell
flutter --version
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --release --no-pub
flutter build apk --debug --no-pub
```

- Windows：输出在 `build/windows/x64/runner/Release/`。运行或分发时保留整个目录，不能只复制 exe。
- Android：试装文件在 `build/app/outputs/flutter-apk/app-debug.apk`。当前通用 debug 包约 180 MiB，含三个架构与离线扫码模型；不代表正式 release 体积。
- Android release 未配置签名。公开分发正式 APK 前自行配置专用签名，密钥和口令不得提交。
- 首次构建会联网下载依赖、引擎和原生资源；运行应用不依赖这些下载服务。保留并提交 `pubspec.lock`。
- targetSdk 固定为 36；升级前需处理新平台局域网权限要求并真机验证。

### Windows 构建排障

Pub 缓存和项目位于不同盘符时，Kotlin 增量编译可能报 `this and base files have different roots`。可仅对本次会话禁用增量编译，再重跑构建：

```powershell
$env:GRADLE_OPTS = "$env:GRADLE_OPTS -Dorg.gradle.project.kotlin.incremental=false"
```

若 Java NIO 报 `Invalid argument: connect`，且 TEMP 路径很长，可将 `-Djdk.net.unixdomain.tmpdir=<已存在的短路径>` 加入本次会话的 JAVA_TOOL_OPTIONS。不要为解决构建问题关闭防火墙或 TLS 校验。代理配置应按自己的网络环境设置，应用同步直接连接配对设备。

## 验证

| 检查 | 当前结果 |
| --- | --- |
| flutter analyze --no-pub | 通过 |
| flutter test --no-pub | 14 项通过 |
| Windows release / Android debug 构建 | 均成功 |
| APK 签名与结构 | v2 签名有效，三个架构均含 SQLite/JNI 库 |
| Android + Windows 真机使用 | 作者反馈功能正常；未逐项记录完整验收矩阵 |

自动测试覆盖离线持久化、重复导入、并发编辑/删除冲突、合并、旧编辑框保护、时钟偏差、整批拒绝、备份恢复与确认计数；还包括回环地址上的真实 TLS 配对、双向同步、丢失确认重试、错误证书和撤销访问，以及手机键盘布局。

建议贡献者验收：手机离线记 10 条后完整同步；重复同步无重复；双向修改；两端离线编辑同一条后保留冲突；断线重试；撤销配对；在独立测试数据目录恢复备份。自动测试不能替代摄像头、安全存储、防火墙与双设备网络实测。

## 数据与安全边界

- SQLite 位于平台应用支持目录。启动失败不会自动清库或重建。
- SQLite、JSON 和 Markdown 没有应用层加密，请保护设备与备份。
- 设备身份、TLS 私钥和配对凭证通过 flutter_secure_storage 使用平台安全存储。
- 手机仅接受配对二维码中的证书 SHA-256 指纹，不依赖系统 CA 根。
- 不建立公网入口、不配置路由器、不添加防火墙规则；退出应用或关闭服务停止监听。
- Android 禁用系统应用数据备份。尚未经过独立安全审计。

## 第一版限制

- 仅纯文字；无附件、内置录音、微信读取、USB、自动发现或后台同步。
- 仅支持一部手机与一台电脑、私有 IPv4 局域网，暂不支持 IPv6、域名或公网地址。
- 每条内容最多 32000 个 UTF-16 code units；最多 10000 个修订。
- 同步单个请求/响应上限 16 MiB，超限明确报错；尚未实现分页。
- JSON 恢复上限 64 MiB，采用合并，不覆盖清空。
- 保留历史修订和删除标记；待同步数是未确认修订数，不是 idea 数。
- 最近成功同步时间仅保留在本次启动内；尚未针对大型记录库优化。

## 代码导航

| 位置 | 职责 |
| --- | --- |
| lib/main.dart、lib/app.dart | 初始化、界面外壳、状态与错误展示 |
| lib/models/、lib/storage/ | 不可变修订、SQLite 事务、图校验与冲突 |
| lib/security/ | 设备身份、证书与安全存储 |
| lib/sync/ | 配对、TLS 服务、客户端与同步协议 |
| lib/services/backup.dart | JSON 备份恢复、Markdown 导出 |
| lib/screens/ | 记录、设备、设置界面 |
| test/ | 仓储、TLS 同步和界面测试 |

## 许可

原创项目代码采用 [MIT](LICENSE)，Copyright (c) 2026 codeofwhite。
第三方组件和 Flutter 平台模板保留原许可，详见 [第三方说明](THIRD_PARTY_NOTICES.md)。项目 MIT 许可不替代第三方许可。
