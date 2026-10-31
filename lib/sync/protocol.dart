import 'dart:convert';
import 'dart:io';

import '../models/idea.dart';

const protocolVersion = 1;
const maxMessageBytes = 16 * 1024 * 1024;
const syncPort = 47381;
Future<Map<String, dynamic>> readMessage(Stream<List<int>> stream) async {
  final bytes = <int>[];
  await for (final chunk in stream.timeout(const Duration(seconds: 30))) {
    if (bytes.length + chunk.length > maxMessageBytes) {
      throw const FormatException('数据包超过 16 MiB');
    }
    bytes.addAll(chunk);
  }
  final value = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  if (value['version'] != protocolVersion) {
    throw const FormatException('同步协议版本不兼容，请更新两端应用');
  }
  return value;
}

List<Revision> parseRevisions(dynamic value) {
  final list = value as List;
  if (list.length > maxRevisionCount) throw const FormatException('修订过多');
  return list.map((r) => Revision.fromJson(r as Map<String, dynamic>)).toList();
}

Set<String> parseIds(dynamic value) {
  final list = value as List;
  if (list.length > maxRevisionCount) throw const FormatException('修订过多');
  return list.map(checkedId).toSet();
}

Map<String, dynamic> message(Map<String, dynamic> fields) => {
  'version': protocolVersion,
  ...fields,
};
Future<void> writeResponse(
  HttpResponse response,
  Map<String, dynamic> data, {
  int status = 200,
}) async {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(message(data)));
  await response.close();
}

String friendlyError(Object error) {
  if (error is HandshakeException) return '设备证书校验失败，请核对配对设备或重新配对';
  if (error is SocketException) return '无法连接电脑，请检查地址、局域网和 Windows 专用网络防火墙许可';
  if (error is FormatException) return error.message.toString();
  return error.toString().replaceFirst(RegExp(r'^(Exception|Bad state): '), '');
}

void ensureMessageSize(Map<String, dynamic> fields) {
  if (utf8.encode(jsonEncode(message(fields))).length > maxMessageBytes) {
    throw const FormatException('单次同步超过 16 MiB，请先导出备份；当前版本尚不支持分批传输');
  }
}
