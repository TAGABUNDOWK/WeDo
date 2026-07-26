/// Firestore document reference structure for the `choices` collection.
///
/// Collection: choices
/// Document ID: same as [id] (e.g. "static_choice_0001")
///
/// Firestore field layout:
/// {
///   "id": String,        // static_choice_0001, static_choice_0002, ...
///   "topicId": String,   // filter key -> matches a Topic's id
///   "title": String,     // display title (emoji included)
///   "imageUrl": String?, // required field, nullable value (filled later)
///   "isActive": bool,
/// }
class ChoiceEntity {
  final String id;
  final String topicId;
  final String title;
  final String? imageUrl;
  final bool isActive;

  const ChoiceEntity({
    required this.id,
    required this.topicId,
    required this.title,
    required this.imageUrl,
    required this.isActive,
  });

  /// Converts this entity into a Firestore-writable map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topicId': topicId,
      'title': title,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }

  /// Builds an entity from a Firestore document snapshot's data map.
  factory ChoiceEntity.fromMap(Map<String, dynamic> map) {
    return ChoiceEntity(
      id: map['id'] as String,
      topicId: map['topicId'] as String,
      title: map['title'] as String,
      imageUrl: map['imageUrl'] as String?,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  ChoiceEntity copyWith({
    String? id,
    String? topicId,
    String? title,
    String? imageUrl,
    bool? isActive,
  }) {
    return ChoiceEntity(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() =>
      'ChoiceEntity(id: $id, topicId: $topicId, title: $title, '
      'imageUrl: $imageUrl, isActive: $isActive)';
}
