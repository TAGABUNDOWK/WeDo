# WeDo Chat Architecture & Firebase Planning

## 1. Testing Group Chat with Firebase

### Option A: Firebase Emulator Suite (Recommended for Development)

Run a full Firebase server locally — no cost, no internet needed.

```bash
npm install -g firebase-tools
firebase init emulators  # select Firestore, Auth, Storage
firebase emulators:start
```

In Flutter, point to the emulator during development:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

void useEmulator() {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
}
```

**Pros:**
- Free, instant, no daily quota limits
- Seeded data resets cleanly
- UI dashboard at `http://localhost:4000`

### Option B: Firebase Spark (Free) Plan — Production Testing

Use your real Firebase project on the free tier. Data persists, testers can use the real app.

**Cost:** $0 — limits: 50K reads/day, 20K writes/day, 20K deletes/day.

### Seeding Test Data (for both options)

Create a helper script to populate test groups and messages:

```dart
Future<void> seedTestData() async {
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();

  // Create 3 test groups
  for (int i = 0; i < 3; i++) {
    final groupRef = firestore.collection('groups').doc();
    batch.set(groupRef, {
      'name': 'Test Group $i',
      'photo_url': null,
      'created_by': 'test_user_$i',
      'member_ids': ['test_user_$i', 'test_user_${i + 1}'],
      'created_at': FieldValue.serverTimestamp(),
      'last_message_at': FieldValue.serverTimestamp(),
    });

    // Add 5 messages per group
    for (int j = 0; j < 5; j++) {
      final msgRef = groupRef.collection('messages').doc();
      batch.set(msgRef, {
        'sender_id': 'test_user_$i',
        'sender_name': 'User $i',
        'type': 'text',
        'content': 'Hello from Group $i, message $j',
        'reactions': {},
        'read_by': ['test_user_$i'],
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  await batch.commit();
}
```

### Setting Up Code Lab Testing Instructions

| Step | Action |
|------|--------|
| 1 | Open project in Android Studio / VS Code |
| 2 | Run `flutter pub get` |
| 3 | Start Firebase Emulator (or use production) |
| 4 | Run `flutter run` on physical device or emulator |
| 5 | Login with any email (mock auth accepts all) |
| 6 | Tap "New Group" FAB to create a group |
| 7 | Enter group name, tap Create |
| 8 | Tap group card on home page to enter chat |
| 9 | Type a message and send |
| 10 | Verify data in Firebase Console > Firestore > groups |

---

## 2. Firebase Free Tier (Spark Plan) Limits

### Daily Quotas (reset at midnight Pacific time)

| Resource | Spark Free Limit | What It Means |
|----------|-----------------|---------------|
| **Document reads** | 50,000/day | Loading group list, chat history, user profiles |
| **Document writes** | 20,000/day | Sending messages, creating groups, updating profiles |
| **Document deletes** | 20,000/day | Deleting messages, groups |
| **Stored data** | 1 GiB total | All chats, images (metadata), users |
| **Network egress** | 10 GiB/month | Data downloaded to users' devices |
| **Storage (files)** | 5 GB | Images, avatars (requires Blaze after Feb 2026) |
| **Auth** | Unlimited | Email/password authentication is free |
| **FCM (notifications)** | Unlimited | Push notifications are free |
| **Cloud Functions** | 2M/month | Backend logic (delete group cleanup, etc.) |

### Cost Estimates Per User Action

| Action | Reads | Writes | Deletes | Daily Budget (20K writes) |
|--------|-------|--------|---------|---------------------------|
| Load home page (20 groups) | ~20 | 0 | 0 | — |
| Open a chat (50 messages) | ~50 | 0 | 0 | — |
| Send 1 text message | 0 | 1 | 0 | ~20,000 messages/day |
| Send 1 image | 0 | 2 (msg + storage) | 0 | ~10,000 images/day |
| Create a group | 0 | 1 | 0 | ~20,000 groups/day |
| Add reaction to message | 1 (read) + 1 (write) | 1 | 0 | ~10,000 reactions/day |

### Real-World Capacity Estimate (Spark Plan)

| User Base | Expected Daily Writes | Feasible? |
|-----------|----------------------|-----------|
| 10 testers, ~50 msgs/day each | 500 writes/day | **Yes** — only 2.5% of limit |
| 100 users, ~50 msgs/day each | 5,000 writes/day | **Yes** — 25% of limit |
| 500 users, ~50 msgs/day each | 25,000 writes/day | **No** — exceeds limit |
| 1,000 users, ~20 msgs/day each | 20,000 writes/day | **Edge case** — will hit limit |

**Verdict:** Spark plan is viable for prototyping and small launches (up to ~200-300 active daily users). Beyond that, upgrade to Blaze ($0.18 per 100K extra writes ≈ ~$0.04/day for 5K extra writes).

### What Happens When You Hit the Limit

- On **Spark**: operations return a `resource-exhausted` error. App features stop working until the next day.
- On **Blaze**: you get billed for overage ($0.06/100K reads, $0.18/100K writes).

---

## 3. Production Firestore Structure

### 3.1 Complete Data Model

```
users/{uid}
  displayName: "Jay"
  email: "jay@example.com"
  photoUrl: null | "https://..."
  createdAt: Timestamp
  lastActiveAt: Timestamp

groups/{groupId}
  name: "Project Team"
  photoUrl: null | "https://..."
  createdBy: "uid_abc"          // the creator's UID
  members: ["uid_abc", "uid_xyz", ...]   // array of UIDs
  memberCount: 3
  createdAt: Timestamp
  lastMessageAt: Timestamp
  lastMessage: "See you tomorrow"         // denormalized preview

groups/{groupId}/members/{uid}
  role: "admin" | "member"
  joinedAt: Timestamp
  invitedBy: "uid_abc"          // who invited this person
  displayName: "Jay"            // denormalized for fast display

groups/{groupId}/messages/{messageId}
  senderId: "uid_abc"
  senderName: "Jay"             // denormalized snapshot
  type: "text" | "image"
  content: "Hello everyone"     // text content or image caption
  imageUrl: null | "https://..." // Firebase Storage URL (if image)
  createdAt: Timestamp
  createdAtLocal: "2026-08-01T14:30:00.000"
  reactions: { "uid_abc": "👍", "uid_xyz": "❤️" }
  readBy: ["uid_abc", "uid_xyz"]
  edited: false
```

**Why this structure:**
- `groups/{groupId}/members/{uid}` subcollection lets you check membership, roles, and who invited whom without reading the entire group doc
- `lastMessage` + `lastMessageAt` denormalized on group doc = fast home page list without querying messages
- `senderName` denormalized on messages = no extra lookups when rendering chat
- `members` array on group doc = fast `arrayContains` queries for "show me my groups"
- `edited` flag = support for message editing indicator

### 3.2 Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isGroupMember(groupId) {
      return isSignedIn()
        && request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
    }

    function isGroupAdmin(groupId) {
      return isSignedIn()
        && exists(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid))
        && get(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid)).data.role == 'admin';
    }

    // ── USERS ──
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.auth.uid == userId;
      allow update: if isSignedIn() && request.auth.uid == userId;
      allow delete: if isSignedIn() && request.auth.uid == userId;
    }

    // ── GROUPS ──
    match /groups/{groupId} {
      allow create: if isSignedIn()
        && request.resource.data.members is list
        && request.resource.data.members.hasAny([request.auth.uid]);

      allow read: if isSignedIn()
        && request.auth.uid in resource.data.members;

      allow update: if isSignedIn()
        && request.auth.uid in resource.data.members
        && request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['lastMessage', 'lastMessageAt', 'memberCount', 'name', 'photoUrl']);

      allow delete: if isSignedIn()
        && request.auth.uid == resource.data.createdBy;

      // ── MEMBERS subcollection ──
      match /members/{memberUid} {
        allow read: if isGroupMember(groupId);
        allow write: if isGroupAdmin(groupId);
      }

      // ── MESSAGES subcollection ──
      match /messages/{messageId} {
        allow read: if isGroupMember(groupId);

        allow create: if isGroupMember(groupId)
          && request.resource.data.senderId == request.auth.uid;

        allow update: if isGroupMember(groupId)
          && (request.auth.uid == resource.data.senderId
              || request.resource.data.diff(resource.data).affectedKeys().hasOnly(['readBy', 'reactions']));

        allow delete: if isGroupMember(groupId)
          && request.auth.uid == resource.data.senderId;
      }
    }
  }
}
```

**Key rule features:**
- **Invite system**: Admins can write to `members/{uid}` subcollection to invite anyone (even non-members of the group). The invitee must already have a `users/{uid}` doc.
- **Image sending**: Only group members can create messages, and `senderId` must match auth UID.
- **Message search**: Reads are scoped to group members only.
- **Edit reactions/readBy**: Any member can update `readBy` and `reactions` on any message, but only the sender can edit `content`.

### 3.3 Discord-Like Search System

Firestore doesn't support full-text search natively. Here's the approach:

#### Search Types

| Search Type | Method | Implementation |
|-------------|--------|----------------|
| **By user** | Firestore query | `.where('senderId', isEqualTo: uid)` + `.orderBy('createdAt')` |
| **By date range** | Firestore query | `.where('createdAt', isGreaterThanOrEqualTo: start)` + `.where('createdAt', isLessThanOrEqualTo: end)` |
| **By content** | Client-side filter | Fetch messages, filter with `String.contains(query, caseSensitive: false)` |
| **Combined** | Composite query | Filter by user + date range via Firestore, then content filter client-side |

#### Search Query Examples

```dart
// Search by user in a group
FirebaseFirestore.instance
  .collection('groups/{groupId}/messages')
  .where('senderId', isEqualTo: targetUserId)
  .orderBy('createdAt', descending: true)
  .limit(50)
  .get();

// Search by date range
FirebaseFirestore.instance
  .collection('groups/{groupId}/messages')
  .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
  .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
  .orderBy('createdAt', descending: true)
  .limit(50)
  .get();

// Search by user + date range (composite)
FirebaseFirestore.instance
  .collection('groups/{groupId}/messages')
  .where('senderId', isEqualTo: targetUserId)
  .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
  .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
  .orderBy('createdAt', descending: true)
  .limit(50)
  .get();

// Content search (client-side after fetching)
final results = await query.get();
final matched = results.docs.where((doc) {
  final content = doc.data()['content'] as String? ?? '';
  return content.toLowerCase().contains(searchQuery.toLowerCase());
}).toList();
```

#### Search UI Flow (like Discord)

```
┌─────────────────────────┐
│ 🔍 Search messages...   │  ← tap search icon in app bar
├─────────────────────────┤
│ Filter: [User ▾] [Date ▾]│  ← dropdown chips
├─────────────────────────┤
│ From: Jay • Aug 1, 2026  │  ← active filters shown
│ "meeting tomorrow"       │
├─────────────────────────┤
│ Result 1: "Let's meet..."│  ← tappable, scrolls to message
│ Jay • 2:30 PM            │
├─────────────────────────┤
│ Result 2: "Meeting at..."│
│ Alex • 3:15 PM           │
└─────────────────────────┘
```

**Firestore composite indexes needed** (for combined user + date queries):
```json
{
  "indexes": [
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "senderId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

### 3.4 Image Sending Flow

```
User taps 📎 → image_picker → compress → upload to Storage → get URL → create message doc

Storage path: groups/{groupId}/images/{timestamp}_{uid}.jpg
```

**Message doc for image:**
```dart
{
  'senderId': uid,
  'senderName': displayName,
  'type': 'image',
  'content': 'optional caption',
  'imageUrl': 'https://firebasestorage...',
  'createdAt': FieldValue.serverTimestamp(),
  'createdAtLocal': DateTime.now().toIso8601String(),
  'reactions': {},
  'readBy': [uid],
  'edited': false,
}
```

### 3.5 Invite Flow

```
Group Admin → tap "Add Member" → search users/{uid} by displayName → send invite

Firestore writes (batch):
1. Set groups/{groupId}/members/{newUid} with role: 'member'
2. Update groups/{groupId}.members array (arrayUnion)
3. Update groups/{groupId}.memberCount (increment)
```

### 3.6 Performance Optimizations

| Optimization | How | Impact |
|-------------|-----|--------|
| Paginate messages | `limit(30)` + `startAfter(lastDoc)` | Reduces reads by 90% |
| Scope groups to user | `.where('members', arrayContains: uid)` | Only loads user's groups |
| Denormalize lastMessage | Write preview on group doc when sending | No query needed for home list |
| Batch writes for invites | `batch.commit()` for member + group update | 1 round trip |
| Compress images | Resize to 720p, JPEG 80% quality | Less storage + bandwidth |
| Cache non-critical data | `get(GetOptions(source: Source.cache))` | 0 quota reads |
| Disable network on background | `FirebaseFirestore.instance.disableNetwork()` | Prevents quota drain |

### 3.7 Dependencies to Add

```yaml
dependencies:
  firebase_auth: ^5.5.1       # Real authentication (UID-based)
  image_picker: ^1.1.2        # Pick images from gallery/camera
  firebase_storage: ^12.4.1   # Upload images to Storage
  intl: ^0.20.1               # Date formatting
  flutter_image_compress: ^2.1.0  # Compress before upload
```

### 3.8 Development Roadmap

| Phase | Task | Done? |
|-------|------|-------|
| 1 | Add `firebase_auth`, implement real login/signup | |
| 2 | Create `users/{uid}` doc on signup with displayName | |
| 3 | Replace all `'user1'` with `auth.currentUser!.uid` | |
| 4 | Fetch `senderName` from `users/{uid}.displayName` | |
| 5 | Scope home page: `.where('members', arrayContains: uid)` | |
| 6 | Add `groups/{groupId}/members/{uid}` subcollection on create | |
| 7 | Deploy new security rules | |
| 8 | Add invite member flow (admin search + add) | |
| 9 | Add image sending (image_picker + Storage + message doc) | |
| 10 | Add message search screen (by user, date, content) | |
| 11 | Add emoji reactions | |
| 12 | Add typing indicators (FCM or polling) | |
| 13 | Add read receipts | |
| 14 | Add push notifications (FCM) | |
| 15 | Implement individual chats | |

---

## 4. Firebase Console Setup Checklist

- [ ] Firebase project created (`wedo-8c865`)
- [ ] Authentication > Sign-in method > Email/Password enabled
- [ ] Firestore database created
- [ ] Firestore rules updated (see section 3.2)
- [ ] Storage bucket created (if using image upload — requires Blaze)
- [ ] Test user accounts added manually for testing
