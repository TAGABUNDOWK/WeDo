/// Entities for the `/topics/{topicId}` and
/// `/topics/{topicId}/cards/{cardId}` Firestore structure.
library;

/// Document at `/topics/{topicId}`.
class TopicEntity {
  final String id;
  final String title;

  const TopicEntity({required this.id, required this.title});

  factory TopicEntity.fromMap(String id, Map<String, dynamic> map) {
    return TopicEntity(id: id, title: map['title'] as String? ?? '');
  }

  Map<String, dynamic> toMap() => {'title': title};

  TopicEntity copyWith({String? id, String? title}) {
    return TopicEntity(id: id ?? this.id, title: title ?? this.title);
  }

  @override
  String toString() => 'TopicEntity(id: $id, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicEntity && other.id == id && other.title == title;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;
}

/// Document at `/topics/{topicId}/cards/{cardId}`.
class CardEntity {
  final String id;
  final String topicId;
  final String name;

  const CardEntity({
    required this.id,
    required this.topicId,
    required this.name,
  });

  factory CardEntity.fromMap(
    String id,
    String topicId,
    Map<String, dynamic> map,
  ) {
    return CardEntity(
      id: id,
      topicId: topicId,
      name: map['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'name': name};

  CardEntity copyWith({String? id, String? topicId, String? name}) {
    return CardEntity(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      name: name ?? this.name,
    );
  }

  @override
  String toString() => 'CardEntity(id: $id, topicId: $topicId, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardEntity &&
          other.id == id &&
          other.topicId == topicId &&
          other.name == name;

  @override
  int get hashCode => id.hashCode ^ topicId.hashCode ^ name.hashCode;
}
