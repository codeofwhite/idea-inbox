# Idea Inbox

Capture ideas on Android. Organize them on Windows. An offline-first plain-text inbox with paired LAN HTTPS sync, no accounts and no cloud backend.

[中文](README.md) · [Protocol (Chinese)](docs/sync-protocol.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

## Status

Version 0.1.0 is a development build. Windows release and Android debug builds succeeded; static analysis and 14 automated tests passed. The project author reports normal operation on a real Android phone and Windows PC. This is personal testing, not a documented exhaustive acceptance matrix or an independent security audit.

This source release does not include downloadable installers or an Android release signing configuration.

## Features

- Offline plain-text capture, editing and search without mandatory titles.
- Inbox, archive and recoverable trash.
- Manual foreground sync between one Android phone and one Windows PC.
- QR pairing with confirmation on the PC, pinned TLS certificate fingerprint and pairing token authentication.
- Immutable revisions, deduplication, preserved concurrent edits and manual conflict resolution.
- JSON backup and merge restore; Markdown export.
- No accounts, telemetry, cloud or AI services.

## Use

1. Build and install both applications.
2. Connect both devices to a reachable LAN. Ethernet on the PC is fine; guest Wi-Fi or client isolation can block access.
3. On Windows, open Devices, select the private IPv4 address and start sync. If prompted by Windows Firewall, allow only a trusted private network.
4. Scan the PC's QR code on Android and confirm the phone on the PC. Codes expire after two minutes and are single-use.
5. Tap sync on the phone while both applications remain open.
6. Resolve conflicts in the inbox and keep independent JSON backups.

Changing the PC's address does not disable certificate pinning. Revoking pairing blocks subsequent connections without remotely erasing saved notes. Sync propagates deletion revisions and is not a backup.

## Build

Verified baseline: Flutter 3.47.5 / Dart 3.13.4, JDK 21, Windows C++ desktop build tools and Windows SDK. Android supports API 24+ and targets API 36.

Install Android SDK platforms 35 and 36, build-tools 36.0.0, platform-tools, NDK 28.2.13676358 and CMake 3.22.1, and accept SDK licenses. API 35 and the specific CMake version are required by JNI. Set JAVA_HOME to a full JDK and ANDROID_HOME to the SDK. Windows must permit Flutter plugin symlinks.

```powershell
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --release --no-pub
flutter build apk --debug --no-pub
```

Windows output: `build/windows/x64/runner/Release/`. Keep the entire folder, including DLLs and data.
Android output: `build/app/outputs/flutter-apk/app-debug.apk`. The current universal debug build is approximately 180 MiB and includes three ABIs and an offline scanner model; release size has not been measured. Configure a dedicated signing key before distributing an Android release. Never commit signing material.

Initial builds download dependencies and native assets; the application does not need these services at runtime. Keep pubspec.lock committed.

On Windows, Kotlin incremental compilation may fail when the Pub cache and project are on different drives. A process-local workaround is:

```powershell
$env:GRADLE_OPTS = "$env:GRADLE_OPTS -Dorg.gradle.project.kotlin.incremental=false"
```

For Java NIO `Invalid argument: connect` with a long TEMP path, set `-Djdk.net.unixdomain.tmpdir=<existing short directory>` in the current session's JAVA_TOOL_OPTIONS. Use your own network/proxy settings; never disable TLS verification or the firewall.

## Validation and limits

Tests cover storage, conflicting edits/deletions, merge validation, stale drafts, backup restore, real loopback TLS pairing and two-way sync, retry after lost acknowledgements, certificate mismatch, revocation and UI behavior. Real hardware is still required to validate camera access, secure storage and network/firewall variations.

Only plain text, one phone and one PC, private IPv4 LANs and foreground manual sync are supported. No attachments, USB, automatic discovery or background service.

Each note is limited to 32000 UTF-16 code units, the database to 10000 revisions, sync requests/responses to 16 MiB and JSON restore to 64 MiB. Limits cause explicit errors; paging is not implemented. History and deletion markers are retained. Pending counts represent revisions, not notes.

## Data and security

Notes and exported files are not encrypted at rest by the app. Device identity, TLS private keys and pairing credentials use platform secure storage. Android system app-data backup is disabled. The service does not configure public exposure, routers or firewall rules. System keyboard networking is controlled by the keyboard's own settings.

See [SECURITY.md](SECURITY.md). Do not attach notes, backups, tokens or pairing QR codes to public issues.

## License

Original project code is licensed under [MIT](LICENSE), Copyright (c) 2026 codeofwhite.
Third-party code and Flutter templates retain their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
