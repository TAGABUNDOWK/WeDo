import 'package:cloud_firestore/cloud_firestore.dart';

class MigrationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<MigrationResult> migrateGroupsToGroupChats() async {
    int groupsMigrated = 0;
    int membersMigrated = 0;
    int messagesMigrated = 0;
    int oldGroupsDeleted = 0;

    final oldGroups = await _db.collection('groups').get();

    for (final oldDoc in oldGroups.docs) {
      final data = oldDoc.data();
      final newRef = _db.collection('group_chats').doc(oldDoc.id);

      // Copy group document
      await newRef.set(data);
      groupsMigrated++;

      // Copy members subcollection
      final oldMembers = await oldDoc.reference.collection('members').get();
      for (final memberDoc in oldMembers.docs) {
        await newRef.collection('members').doc(memberDoc.id).set(memberDoc.data());
        membersMigrated++;
      }

      // Copy messages subcollection
      final oldMessages = await oldDoc.reference.collection('messages').get();
      for (final msgDoc in oldMessages.docs) {
        final msgData = msgDoc.data();

        // Migrate camelCase fields to snake_case
        final migratedData = <String, dynamic>{
          'content': msgData['content'],
          'type': msgData['type'],
          'edited': msgData['edited'] ?? false,
          'reactions': msgData['reactions'] ?? {},
          'createdAtLocal': msgData['createdAtLocal'],
        };

        // sender_id
        if (msgData.containsKey('senderId')) {
          migratedData['sender_id'] = msgData['senderId'];
        } else if (msgData.containsKey('sender_id')) {
          migratedData['sender_id'] = msgData['sender_id'];
        }

        // sender_name
        if (msgData.containsKey('senderName')) {
          migratedData['sender_name'] = msgData['senderName'];
        } else if (msgData.containsKey('sender_name')) {
          migratedData['sender_name'] = msgData['sender_name'];
        }

        // created_at
        if (msgData.containsKey('createdAt')) {
          migratedData['created_at'] = msgData['createdAt'];
        } else if (msgData.containsKey('created_at')) {
          migratedData['created_at'] = msgData['created_at'];
        }

        // read_by
        if (msgData.containsKey('readBy')) {
          migratedData['read_by'] = msgData['readBy'];
        } else if (msgData.containsKey('read_by')) {
          migratedData['read_by'] = msgData['read_by'];
        }

        // image_url
        if (msgData.containsKey('imageUrl')) {
          migratedData['image_url'] = msgData['imageUrl'];
        } else if (msgData.containsKey('image_url')) {
          migratedData['image_url'] = msgData['image_url'];
        }

        await newRef.collection('messages').doc(msgDoc.id).set(migratedData);
        messagesMigrated++;
      }

      // Delete old group and its subcollections
      await _deleteSubcollections(oldDoc.reference);
      await oldDoc.reference.delete();
      oldGroupsDeleted++;
    }

    return MigrationResult(
      groupsMigrated: groupsMigrated,
      membersMigrated: membersMigrated,
      messagesMigrated: messagesMigrated,
      oldGroupsDeleted: oldGroupsDeleted,
    );
  }

  Future<void> _deleteSubcollections(DocumentReference doc) async {
    final subcollections = ['members', 'messages'];
    for (final sub in subcollections) {
      final snap = await doc.collection(sub).get();
      for (final d in snap.docs) {
        await d.reference.delete();
      }
    }
  }

  Future<bool> hasOldGroups() async {
    final snap = await _db.collection('groups').limit(1).get();
    return snap.docs.isNotEmpty;
  }
}

class MigrationResult {
  final int groupsMigrated;
  final int membersMigrated;
  final int messagesMigrated;
  final int oldGroupsDeleted;

  const MigrationResult({
    required this.groupsMigrated,
    required this.membersMigrated,
    required this.messagesMigrated,
    required this.oldGroupsDeleted,
  });

  @override
  String toString() {
    return 'Migrated $groupsMigrated groups, $membersMigrated members, '
        '$messagesMigrated messages. Deleted $oldGroupsDeleted old groups.';
  }
}
