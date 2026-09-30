/// Entities for the `/topics/{topicId}` and
/// `/topics/{topicId}/cards/{cardId}` Firestore structure.
library;

/// Document at `/topics/{topicId}`.
class TopicEntity {
  final String id;
  final String title;
  final String? description;

  const TopicEntity({
    required this.id,
    required this.title,
    this.description,
  });

  factory TopicEntity.fromMap(String id, Map<String, dynamic> map) {
    return TopicEntity(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        if (description != null) 'description': description,
      };

  TopicEntity copyWith({String? id, String? title, String? description}) {
    return TopicEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }

  @override
  String toString() =>
      'TopicEntity(id: $id, title: $title, description: $description)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicEntity &&
          other.id == id &&
          other.title == title &&
          other.description == description;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ description.hashCode;
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
