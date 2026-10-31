import 'dart:convert';

const maxTextLength = 32000;
const maxRevisionCount = 10000;
final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
String checkedId(dynamic value) {
  if (value is! String || !_uuidPattern.hasMatch(value)) {
    throw const FormatException('无效的记录标识');
  }
  return value;
}

class Revision {
  final String id, ideaId, deviceId, text;
  final List<String> parents;
  final bool archived, deleted;
  final DateTime createdAt, editedAt;
  Revision({
    required this.id,
    required this.ideaId,
    required this.deviceId,
    required List<String> parents,
    required this.text,
    required this.archived,
    required this.deleted,
    required this.createdAt,
    required this.editedAt,
  }) : parents = List.unmodifiable(parents);

  factory Revision.fromJson(Map<String, dynamic> json) {
    final parents = (json['parents'] as List).map(checkedId).toList()..sort();
    final text = json['text'] as String;
    if (text.length > maxTextLength ||
        parents.length > maxRevisionCount ||
        parents.toSet().length != parents.length ||
        text.trim().isEmpty) {
      throw const FormatException('记录内容或版本关系无效');
    }
    return Revision(
      id: checkedId(json['id']),
      ideaId: checkedId(json['ideaId']),
      deviceId: checkedId(json['deviceId']),
      parents: parents,
      text: text,
      archived: json['archived'] as bool,
      deleted: json['deleted'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      editedAt: DateTime.parse(json['editedAt'] as String).toUtc(),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'ideaId': ideaId,
    'deviceId': deviceId,
    'parents': [...parents]..sort(),
    'text': text,
    'archived': archived,
    'deleted': deleted,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'editedAt': editedAt.toUtc().toIso8601String(),
  };
  String get canonical => jsonEncode(toJson());
}

class Idea {
  final String id;
  final List<Revision> heads;
  Idea(this.id, this.heads);
  bool get conflicted => heads.length > 1;
  Revision get display => heads.first;
}
