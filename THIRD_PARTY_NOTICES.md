# Third-party notices

The project MIT license applies to original project code only. Third-party components retain their original copyright and license terms. The files below are copied verbatim from the local dependency versions resolved in pubspec.lock; they include development dependencies and platform packages, not just components used at runtime on Android/Windows.

- Flutter 3.47.5 framework, SDK packages and generated platform scaffolding: [original license](third_party/licenses/flutter/LICENSE).
- Gradle 9.3.1 wrapper/build tooling: [distribution license](third_party/licenses/gradle/LICENSE). Build tooling is not an app runtime dependency.
- Dart/Pub package licenses are listed below. Read each original text; the project's MIT license does not relicense them. In particular, dbus carries MPL-2.0 terms and is a transitive Linux-platform dependency, not a supported application target.

This is a source-release dependency notice inventory, not a complete binary-distribution audit. Before publishing installers, include the Flutter engine's bundled notices and the notices/terms required by bundled native components such as SQLite, Google ML Kit, Android/Maven dependencies and Windows runtime components. Dependencies downloaded during a build are not all vendored into this repository. Application builds also generate Flutter license assets; retain them with the distribution.

Regenerate this inventory when updating pubspec.lock. SDK packages flutter_localizations, flutter_test and flutter_web_plugins are covered by the Flutter SDK license above.

| Package | Resolved version | Original notices |
| --- | --- | --- |
| archive | 4.5.2 | [LICENSE](third_party/licenses/archive/LICENSE), [LICENSE-other.md](third_party/licenses/archive/LICENSE-other.md) |
| args | 2.7.0 | [LICENSE](third_party/licenses/args/LICENSE) |
| async | 2.13.1 | [LICENSE](third_party/licenses/async/LICENSE) |
| basic_utils | 5.8.2 | [LICENSE](third_party/licenses/basic_utils/LICENSE) |
| boolean_selector | 2.1.2 | [LICENSE](third_party/licenses/boolean_selector/LICENSE) |
| characters | 1.4.1 | [LICENSE](third_party/licenses/characters/LICENSE) |
| clock | 1.1.3 | [LICENSE](third_party/licenses/clock/LICENSE) |
| code_assets | 2.1.0 | [LICENSE](third_party/licenses/code_assets/LICENSE) |
| collection | 1.19.1 | [LICENSE](third_party/licenses/collection/LICENSE) |
| convert | 3.1.2 | [LICENSE](third_party/licenses/convert/LICENSE) |
| cross_file | 0.3.5+5 | [LICENSE](third_party/licenses/cross_file/LICENSE) |
| crypto | 3.0.8 | [LICENSE](third_party/licenses/crypto/LICENSE) |
| dbus | 0.7.15 | [LICENSE](third_party/licenses/dbus/LICENSE) |
| fake_async | 1.3.3 | [LICENSE](third_party/licenses/fake_async/LICENSE) |
| ffi | 2.2.0 | [LICENSE](third_party/licenses/ffi/LICENSE) |
| file | 7.0.1 | [LICENSE](third_party/licenses/file/LICENSE) |
| file_picker | 10.3.10 | [LICENSE](third_party/licenses/file_picker/LICENSE) |
| fixnum | 1.1.1 | [LICENSE](third_party/licenses/fixnum/LICENSE) |
| flutter_lints | 6.0.0 | [LICENSE](third_party/licenses/flutter_lints/LICENSE) |
| flutter_plugin_android_lifecycle | 2.0.35 | [LICENSE](third_party/licenses/flutter_plugin_android_lifecycle/LICENSE) |
| flutter_secure_storage | 10.3.4 | [LICENSE](third_party/licenses/flutter_secure_storage/LICENSE) |
| flutter_secure_storage_darwin | 0.3.2 | [LICENSE](third_party/licenses/flutter_secure_storage_darwin/LICENSE) |
| flutter_secure_storage_linux | 3.0.3 | [LICENSE](third_party/licenses/flutter_secure_storage_linux/LICENSE) |
| flutter_secure_storage_platform_interface | 2.1.1 | [LICENSE](third_party/licenses/flutter_secure_storage_platform_interface/LICENSE) |
| flutter_secure_storage_web | 2.1.1 | [LICENSE](third_party/licenses/flutter_secure_storage_web/LICENSE) |
| flutter_secure_storage_windows | 4.1.0 | [LICENSE](third_party/licenses/flutter_secure_storage_windows/LICENSE) |
| glob | 2.2.0 | [LICENSE](third_party/licenses/glob/LICENSE) |
| hooks | 2.2.0 | [LICENSE](third_party/licenses/hooks/LICENSE) |
| http | 1.6.0 | [LICENSE](third_party/licenses/http/LICENSE) |
| http_parser | 4.1.2 | [LICENSE](third_party/licenses/http_parser/LICENSE) |
| intl | 0.20.3 | [LICENSE](third_party/licenses/intl/LICENSE) |
| jni | 1.1.1 | [LICENSE](third_party/licenses/jni/LICENSE) |
| jni_flutter | 1.0.4+1 | [LICENSE](third_party/licenses/jni_flutter/LICENSE) |
| jni_util | 1.0.0 | [LICENSE](third_party/licenses/jni_util/LICENSE) |
| json_annotation | 4.12.0 | [LICENSE](third_party/licenses/json_annotation/LICENSE) |
| leak_tracker | 11.0.2 | [LICENSE](third_party/licenses/leak_tracker/LICENSE) |
| leak_tracker_flutter_testing | 3.0.10 | [LICENSE](third_party/licenses/leak_tracker_flutter_testing/LICENSE) |
| leak_tracker_testing | 3.0.2 | [LICENSE](third_party/licenses/leak_tracker_testing/LICENSE) |
| lints | 6.1.0 | [LICENSE](third_party/licenses/lints/LICENSE) |
| logging | 1.3.0 | [LICENSE](third_party/licenses/logging/LICENSE) |
| matcher | 0.12.20 | [LICENSE](third_party/licenses/matcher/LICENSE) |
| material_color_utilities | 0.13.0 | [LICENSE](third_party/licenses/material_color_utilities/LICENSE) |
| meta | 1.19.0 | [LICENSE](third_party/licenses/meta/LICENSE) |
| mobile_scanner | 7.4.2 | [LICENSE](third_party/licenses/mobile_scanner/LICENSE) |
| native_toolchain_c | 0.19.5 | [LICENSE](third_party/licenses/native_toolchain_c/LICENSE) |
| objective_c | 9.6.2 | [LICENSE](third_party/licenses/objective_c/LICENSE) |
| package_config | 3.0.0 | [LICENSE](third_party/licenses/package_config/LICENSE) |
| path | 1.9.1 | [LICENSE](third_party/licenses/path/LICENSE) |
| path_provider | 2.1.6 | [LICENSE](third_party/licenses/path_provider/LICENSE) |
| path_provider_android | 2.3.1 | [LICENSE](third_party/licenses/path_provider_android/LICENSE) |
| path_provider_foundation | 2.6.0 | [LICENSE](third_party/licenses/path_provider_foundation/LICENSE) |
| path_provider_linux | 2.2.2 | [LICENSE](third_party/licenses/path_provider_linux/LICENSE) |
| path_provider_platform_interface | 2.1.3 | [LICENSE](third_party/licenses/path_provider_platform_interface/LICENSE) |
| path_provider_windows | 2.3.0 | [LICENSE](third_party/licenses/path_provider_windows/LICENSE) |
| petitparser | 7.1.0 | [LICENSE](third_party/licenses/petitparser/LICENSE) |
| platform | 3.2.0 | [LICENSE](third_party/licenses/platform/LICENSE) |
| plugin_platform_interface | 2.1.8 | [LICENSE](third_party/licenses/plugin_platform_interface/LICENSE) |
| pointycastle | 4.0.0 | [LICENSE](third_party/licenses/pointycastle/LICENSE) |
| posix | 6.5.4 | [LICENSE](third_party/licenses/posix/LICENSE) |
| process | 5.0.6 | [LICENSE](third_party/licenses/process/LICENSE) |
| pub_semver | 2.2.1 | [LICENSE](third_party/licenses/pub_semver/LICENSE) |
| qr | 3.0.3 | [LICENSE](third_party/licenses/qr/LICENSE) |
| qr_flutter | 4.1.0 | [LICENSE](third_party/licenses/qr_flutter/LICENSE) |
| record_use | 1.1.1 | [LICENSE](third_party/licenses/record_use/LICENSE) |
| sky_engine | sky_engine | [LICENSE](third_party/licenses/sky_engine/LICENSE) |
| source_span | 1.10.2 | [LICENSE](third_party/licenses/source_span/LICENSE) |
| sqlite3 | 3.8.0 | [LICENSE](third_party/licenses/sqlite3/LICENSE) |
| stack_trace | 1.12.2 | [LICENSE](third_party/licenses/stack_trace/LICENSE) |
| stream_channel | 2.1.4 | [LICENSE](third_party/licenses/stream_channel/LICENSE) |
| string_scanner | 1.4.1 | [LICENSE](third_party/licenses/string_scanner/LICENSE) |
| term_glyph | 1.2.2 | [LICENSE](third_party/licenses/term_glyph/LICENSE) |
| test_api | 0.7.12 | [LICENSE](third_party/licenses/test_api/LICENSE) |
| typed_data | 1.4.0 | [LICENSE](third_party/licenses/typed_data/LICENSE) |
| uuid | 4.6.0 | [LICENSE](third_party/licenses/uuid/LICENSE) |
| vector_math | 2.4.0 | [LICENSE](third_party/licenses/vector_math/LICENSE) |
| vm_service | 15.4.0 | [LICENSE](third_party/licenses/vm_service/LICENSE) |
| web | 1.1.2 | [LICENSE](third_party/licenses/web/LICENSE) |
| win32 | 5.15.0 | [LICENSE](third_party/licenses/win32/LICENSE) |
| xdg_directories | 1.1.0 | [LICENSE](third_party/licenses/xdg_directories/LICENSE) |
| xml | 7.1.0 | [LICENSE](third_party/licenses/xml/LICENSE) |
| yaml | 3.1.4 | [LICENSE](third_party/licenses/yaml/LICENSE) |

## v0.1.0 binary distribution notices

- Flutter engine: [Windows](third_party/licenses/runtime/Flutter-Windows-LICENSE.md) and [Android](third_party/licenses/runtime/Flutter-Android-LICENSE.md). The distributions retain Flutter's generated NOTICES.Z assets.
- Bundled ML Kit barcode scanner 17.3.0: [upstream third-party license text](third_party/licenses/runtime/MLKit-third_party_licenses.txt) and [index](third_party/licenses/runtime/MLKit-third_party_licenses.json), extracted unchanged from the upstream AAR. ML Kit itself is provided under [ML Kit Terms of Service](https://developers.google.com/ml-kit/terms), as identified by its Maven POM, and is not relicensed under this project's MIT license.
- SQLite native library: [SQLite copyright / public-domain statement](https://www.sqlite.org/copyright.html); the Dart wrapper retains [its original license](third_party/licenses/sqlite3/LICENSE).
- AndroidX and Kotlin components retain their upstream notices; APK META-INF and packaged license assets are preserved. The license companion archive includes notices extracted from the packaged APK and upstream scanner AAR.
- Windows runtime prerequisites supplied by Microsoft remain under Microsoft's terms; no Microsoft redistributable installer is included in this release.

The companion notices archive is part of the binary release. Keep its notices when redistributing the APK, and retain the licenses directory included in the Windows ZIP. No independent legal or security audit is claimed.
