# WeDo — Entity Relationship Diagrams (Detailed)

> **Notation Legend**
> - `||` = mandatory one
> - `o|` = optional one
> - `|{` = mandatory many
> - `o{` = optional many
> - Each relationship line: **cardinality | FK field | constraint**

---

## 1. Overview — All Entities

```mermaid
erDiagram
    UserEntity ||--o{ SessionEntity : "1:N | hostId"
    UserEntity ||--o{ ParticipantEntity : "1:N | userId"
    UserEntity ||--o{ TriRace : "1:N | hostId"
    UserEntity ||--o{ TriRaceParticipant : "1:N | userId"
    UserEntity ||--o{ NotificationEntity : "1:N | senderId"
    UserEntity ||--o| UserStatsEntity : "1:1 | userId"
    UserEntity }o--o{ FriendEntity : "M:N | userIds array"
    UserEntity }o--o{ GroupChat : "M:N | members array"
    UserEntity }o--o{ DirectChat : "M:N | members array"
    UserEntity ||--o{ Call : "1:N | createdBy"

    SessionEntity ||--o{ ParticipantEntity : "1:N | sessionId subcollection"
    SessionEntity }o--|| TopicEntity : "N:1 | topic FK"
    TopicEntity ||--o{ CardEntity : "1:N | topicId subcollection"

    GroupChat ||--o{ ChatMessage : "1:N | messages subcollection"
    GroupChat ||--o{ ChatEvent : "1:N | events subcollection"
    GroupChat ||--o{ ChatPoll : "1:N | polls subcollection"
    GroupChat ||--o{ MemberRole : "1:N | members subcollection"

    DirectChat ||--o{ ChatMessage : "1:N | messages subcollection"
    DirectChat ||--o{ ChatEvent : "1:N | events subcollection"
    DirectChat ||--o{ ChatPoll : "1:N | polls subcollection"

    ChatPoll ||--o{ Vote : "1:N | votes subcollection"
    ChatMessage ||--o{ ChatMessage : "1:N | replyTo self-ref"

    Call ||--o{ CallParticipant : "1:N | participants subcollection"
    Call ||--o{ Signal : "1:N | signals subcollection"
    Call }o--o| GroupChat : "N:1 | optional groupId"
    Call }o--o| DirectChat : "N:1 | optional chatId"

    UserStatsEntity ||--|| Leaderboard : "1:1 | denormalized"
```

---

## 2. User & Identity

```mermaid
erDiagram
    UserEntity ||--o{ NotificationEntity : "1:N | senderId FK"
    UserEntity ||--o| UserStatsEntity : "1:1 | userId PK"
    UserEntity }o--o{ FriendEntity : "M:N | userIds array (exactly 2)"

    UserEntity {
        string userId PK
        string displayName
        string username UK "lowercase unique"
        string usernameLower UK
        string email
        string photoUrl
        string avatarAsset
        string frameAsset
        string authProvider "email|google|guest"
        bool isPremium
        bool isGuest
        bool isEmailVerified
        double latitude
        double longitude
        string geohash
        datetime lastLocationAt
        datetime createdAt
        datetime lastActiveAt
        datetime deletionRequestedAt
        datetime scheduledDeletionAt
    }

    FriendEntity {
        string friendshipId PK "deterministic: sorted(uidA,uidB)"
        list userIds "exactly 2 user UIDs"
        enum status "pending|friends"
        string requestedBy FK "userId of requester"
        datetime updatedAt
    }

    NotificationEntity {
        string notificationId PK
        enum type "friendRequest|friendRequestAccepted|eventCreated|pollCreated"
        string title
        string message
        string senderId FK "userId of sender"
        string relatedId "entity ID (friendship, event, poll)"
        string groupId FK "group context if applicable"
        string chatId FK "direct chat context if applicable"
        string otherUid FK "other user in the notification"
        bool isRead
        enum status "pending|accepted|declined"
        datetime createdAt
    }

    UserStatsEntity {
        string userId PK "same as UserEntity.userId"
        string displayName "denormalized from UserEntity"
        string avatarAsset "denormalized from UserEntity"
        int totalMatchesPlayed
        int pickFightWins
        int triRaceWins
    }
```

**Relationship Notes:**
- `FriendEntity.userIds` is a **deterministic ID**: `sorted([uidA, uidB]).join('_')` — guarantees one friendship doc per pair
- `FriendEntity.requestedBy` references the user who sent the request
- `NotificationEntity` is a **subcollection** under `users/{userId}/notifications/`
- `NotificationEntity.relatedId` polymorphically points to different entity types depending on `type`
- `UserStatsEntity` is at Firestore path `userStats/{userId}` (separate from `users/{uid}`)

---

## 3. Session (PickFight) & Gameplay

```mermaid
erDiagram
    UserEntity ||--o{ SessionEntity : "1:N | hostId FK"
    UserEntity ||--o{ ParticipantEntity : "1:N | userId PK (same as user)"
    SessionEntity ||--o{ ParticipantEntity : "1:N | participants subcollection"
    SessionEntity }o--|| TopicEntity : "N:1 | topic FK (string name)"
    TopicEntity ||--o{ CardEntity : "1:N | topicId subcollection"

    SessionEntity {
        string id PK "Firestore doc ID"
        string sessionId UK "6-char alphanumeric join code"
        string hostId FK "userId of session host"
        string topic "topic name (denormalized string, not FK ref)"
        enum status "lobby|active|completed|cancelled"
        json cards "array of card maps (denormalized from topic)"
        string speedShieldWinnerId FK "first to finish (userId)"
        json aggregatedResults "cardTally, winnerCard, standings"
        list invitedUserIds FK "array of userIds invited"
        list participantUids FK "array of userIds currently in session"
        datetime createdAt
        datetime expiresAt "24h TTL"
        datetime hostLastSeen "host heartbeat"
    }

    ParticipantEntity {
        string id PK "same as userId"
        string userName "denormalized from UserEntity"
        enum status "active|finished"
        string chosenWinnerCardId "user's final pick"
        int elapsedTimeMs "time to complete"
        list eliminatedCardIds "cards swiped away"
        int timeoutCount "auto-elimination count"
    }

    TopicEntity {
        string id PK
        string title "topic display name"
    }

    CardEntity {
        string id PK
        string topicId FK "parent topic"
        string name "card display name"
    }
```

**Relationship Notes:**
- `SessionEntity.topic` is a **string name** (not a Firestore FK reference) — denormalized for display
- `SessionEntity.cards` are **denormalized** from `TopicEntity` → `CardEntity` at session creation time
- `ParticipantEntity` lives in a **subcollection**: `sessions/{sessionId}/participants/{userId}`
- `SessionEntity.participantUids` is a **denormalized array** for `arrayContains` queries
- `SessionEntity.aggregatedResults` is written by `SessionService.aggregateResults()` and contains:
  - `cardTally`: map of card → count
  - `winnerCard`: the card with highest votes
  - `speedShieldWinnerId`: userId of first to finish
  - `standings`: ordered list of participants
- `SessionService.aggregateResults()` calls `LeaderboardService.recordPickFightResult()` to update `UserStatsEntity`

---

## 4. TriRace

```mermaid
erDiagram
    UserEntity ||--o{ TriRace : "1:N | hostId FK"
    UserEntity ||--o{ TriRaceParticipant : "1:N | userId FK"
    TriRace ||--o{ TriRaceParticipant : "1:N | participants subcollection"
    TriRace }o--|| UserEntity : "N:1 | winnerId FK (optional)"

    TriRace {
        string id PK "Firestore doc ID"
        string joinCode UK "6-char alphanumeric join code"
        string hostId FK "userId of race host"
        enum status "lobby|started|finished|cancelled"
        int maxPlayers "default 4"
        string colorTheme "default 'solid'"
        datetime raceStartedAt
        int raceDurationMs "time limit in milliseconds"
        datetime createdAt
        string deletedBy FK "userId who deleted"
        list invitedUserIds FK "array of userIds invited"
        list participantUids FK "array of userIds currently in race"
        string winnerId FK "userId of winner (nullable)"
    }

    TriRaceParticipant {
        string id PK "same as userId"
        string userId FK "reference to UserEntity"
        string username "denormalized from UserEntity"
        datetime joinedAt
        string avatarColor "randomized color"
        string avatarColorEnd "gradient end color"
        double speedSeed "random speed multiplier"
        int finishTimeMs "time to finish"
        int placement "1st, 2nd, 3rd, etc."
    }
```

**Relationship Notes:**
- `TriRace` lives at Firestore path `triRaces/{raceId}`
- `TriRaceParticipant` lives in subcollection: `triRaces/{raceId}/participants/{userId}`
- `TriRaceParticipant.userId` is **always the same as** the document ID (`id`)
- `TriRace.winnerId` is set by `TriRaceService.markTriRaceFinished()` after race completion
- `TriRaceService.markTriRaceFinished()` calls `LeaderboardService.recordTriRaceResult()` to update `UserStatsEntity.triRaceWins`
- `TriRaceParticipant.speedSeed` is a random multiplier that determines race speed
- `TriRaceParticipant.placement` is determined by `finishTimeMs` (lowest wins)

---

## 5. Group Chat

```mermaid
erDiagram
    UserEntity }o--o{ GroupChat : "M:N | members array + MemberRole subcollection"
    GroupChat ||--o{ MemberRole : "1:N | members subcollection"
    GroupChat ||--o{ ChatMessage : "1:N | messages subcollection"
    GroupChat ||--o{ ChatEvent : "1:N | events subcollection"
    GroupChat ||--o{ ChatPoll : "1:N | polls subcollection"
    ChatPoll ||--o{ Vote : "1:N | votes subcollection"
    ChatMessage ||--o{ ChatMessage : "1:N | replyTo self-reference"

    GroupChat {
        string id PK "Firestore doc ID"
        string name "group display name"
        string photoUrl "group avatar URL"
        string createdBy FK "userId of creator"
        list members "array of userIds"
        int memberCount "denormalized count"
        string lastMessage "preview text"
        string lastMessageSenderId FK "userId of last sender"
        datetime lastMessageAt
        list lastMessageReadBy "userIds who read last msg"
        list mutedBy "userIds with muted notifications"
        datetime createdAt
    }

    MemberRole {
        string id PK "same as userId"
        string role "admin|member"
        string displayName "denormalized from UserEntity"
        datetime joinedAt
    }

    ChatMessage {
        string id PK "Firestore doc ID"
        string senderId FK "userId of sender"
        string senderName "denormalized display name"
        string content "message text"
        enum type "text|image|audio|call|system|invite|event|poll"
        string imageUrl "for type=image"
        string audioUrl "for type=audio"
        int durationSeconds "for type=audio"
        string activityId "FK to session/triRace (for invite type)"
        string activityType "session|triRace (for invite type)"
        string refId "FK to event/poll (for event/poll types)"
        string callType "audio|video (for call type)"
        string callStatus "ringing|active|ended (for call type)"
        string replyTo FK "self-reference to ChatMessage.id"
        string replyToContent "denormalized reply preview"
        string replyToSender "denormalized reply sender name"
        list readBy "userIds who read this message"
        map reactions "emoji -> [userId, ...]"
        bool edited
        datetime createdAt
        map groupInviteData "invite metadata"
        list deletedFor "userIds who deleted for themselves"
    }

    ChatEvent {
        string id PK "Firestore doc ID"
        string createdBy FK "userId of creator"
        string title "event title"
        string description "event description"
        datetime date "event start"
        datetime endDate "event end (optional)"
        string location "event location"
        string dressCode "dress code (optional)"
        map rsvps "userId -> response string"
        bool showRsvpMessages "show RSVP in chat"
        string groupId FK "parent group"
        string chatId FK "parent direct chat (if applicable)"
        datetime createdAt
    }

    ChatPoll {
        string id PK "Firestore doc ID"
        string createdBy FK "userId of creator"
        enum type "public|secret"
        string question "poll question"
        list options "array of option strings"
        bool anonymous "hide voter identities"
        bool closed "poll is closed"
        map results "option -> vote count"
        datetime closesAt "auto-close time (optional)"
        string groupId FK "parent group"
        string chatId FK "parent direct chat (if applicable)"
    }

    Vote {
        string id PK "same as userId (public) or hash (secret)"
        string option "selected option text"
        string uid FK "userId of voter (null if secret)"
        string voterHash "SHA-256(uid:pollId) for secret polls"
        datetime createdAt
    }
```

**Relationship Notes:**
- `GroupChat` lives at Firestore path `groups/{groupId}`
- `ChatMessage`, `ChatEvent`, `ChatPoll` are all **subcollections** under the group
- `Vote` is a **nested subcollection**: `groups/{groupId}/polls/{pollId}/votes/`
- `ChatMessage.replyTo` is a **self-reference** for threaded replies
- `ChatMessage.activityId` polymorphically references:
  - `SessionEntity.sessionId` when `type = 'invite'` and `activityType = 'session'`
  - `TriRace.id` when `type = 'invite'` and `activityType = 'triRace'`
- `ChatMessage.refId` polymorphically references:
  - `ChatEvent.id` when `type = 'event'`
  - `ChatPoll.id` when `type = 'poll'`
- `Vote.id` is:
  - The user's `uid` for **public** polls
  - A `SHA-256(uid:pollId)` hash for **secret** polls (anonymous)
- `MemberRole` is at subcollection path `groups/{groupId}/members/{userId}`
- `GroupService.addMember()` atomically: adds to `members` array + creates `MemberRole` doc + increments `memberCount`

---

## 6. Direct Chat

```mermaid
erDiagram
    UserEntity }o--o{ DirectChat : "M:N | members array (exactly 2)"
    DirectChat ||--o{ ChatMessage : "1:N | messages subcollection"
    DirectChat ||--o{ ChatEvent : "1:N | events subcollection"
    DirectChat ||--o{ ChatPoll : "1:N | polls subcollection"
    ChatPoll ||--o{ Vote : "1:N | votes subcollection"

    DirectChat {
        string id PK "deterministic: sorted(uidA_uidB)"
        list members "exactly 2 userIds"
        string lastMessage "preview text"
        string lastMessageSenderId FK "userId of last sender"
        datetime lastMessageAt
        list lastMessageReadBy "userIds who read last msg"
        list mutedBy "userIds with muted notifications"
        datetime createdAt
    }

    ChatMessage {
        string id PK "Firestore doc ID"
        string senderId FK "userId of sender"
        string senderName "denormalized display name"
        string content "message text"
        enum type "text|image|audio|call|system|invite|event|poll"
        string imageUrl
        string audioUrl
        int durationSeconds
        string activityId FK "session/triRace ID (for invite type)"
        string activityType "session|triRace (for invite type)"
        string refId FK "event/poll ID (for event/poll types)"
        string callType "audio|video"
        string callStatus "ringing|active|ended"
        string replyTo FK "self-reference to ChatMessage.id"
        string replyToContent
        string replyToSender
        list readBy
        map reactions
        bool edited
        datetime createdAt
        map groupInviteData
        list deletedFor
    }

    ChatEvent {
        string id PK
        string createdBy FK
        string title
        string description
        datetime date
        datetime endDate
        string location
        string dressCode
        map rsvps "userId -> response"
        bool showRsvpMessages
        string chatId FK "parent direct chat"
        string groupId FK "null for direct chats"
        datetime createdAt
    }

    ChatPoll {
        string id PK
        string createdBy FK
        enum type "public|secret"
        string question
        list options
        bool anonymous
        bool closed
        map results
        datetime closesAt
        string chatId FK "parent direct chat"
        string groupId FK "null for direct chats"
    }

    Vote {
        string id PK "uid (public) or hash (secret)"
        string option
        string uid FK
        string voterHash "SHA-256(uid:pollId)"
        datetime createdAt
    }
```

**Relationship Notes:**
- `DirectChat` lives at Firestore path `directChats/{chatId}`
- **Deterministic ID**: `chatId = sorted([uidA, uidB]).join('_')` — guarantees one chat per user pair
- `DirectChat.members` always contains **exactly 2** user IDs
- Subcollection structure mirrors Group Chat: `messages/`, `events/`, `polls/`, `polls/{pollId}/votes/`
- `ChatMessage`, `ChatEvent`, `ChatPoll` schemas are **shared** between Group and Direct chats
- The `groupId` field on `ChatEvent`/`ChatPoll` is `null` for direct chats, populated for group chats
- `DirectService.getOrCreateChat()` uses the deterministic ID to prevent duplicate chats

---

## 7. Calls & WebRTC

```mermaid
erDiagram
    UserEntity ||--o{ Call : "1:N | createdBy FK"
    UserEntity ||--o{ CallParticipant : "1:N | userId FK"
    Call ||--o{ CallParticipant : "1:N | participants subcollection"
    Call ||--o{ Signal : "1:N | signals subcollection"
    Call }o--o| GroupChat : "N:1 | optional groupId FK"
    Call }o--o| DirectChat : "N:1 | optional chatId FK"

    Call {
        string id PK "Firestore doc ID"
        string groupId FK "FK to GroupChat (null for 1:1 calls)"
        string chatId FK "FK to DirectChat (null for group calls)"
        enum type "audio|video"
        enum status "ringing|active|ended|missed|declined|cancelled"
        string createdBy FK "userId of call initiator"
        list members "array of userIds"
        datetime createdAt
        datetime startedAt "when call became active"
        datetime endedAt "when call ended"
    }

    CallParticipant {
        string id PK "same as userId"
        string userId FK "reference to UserEntity"
        enum status "ringing|active|left"
        datetime joinedAt
    }

    Signal {
        string id PK "Firestore auto-ID"
        string type "offer|answer|ice-candidate"
        string senderId FK "userId who created signal"
        json data "SDP or ICE candidate payload"
        datetime createdAt
    }
```

**Relationship Notes:**
- `Call` lives at Firestore path `calls/{callId}`
- `Call` references **either** `GroupChat` (via `groupId`) **or** `DirectChat` (via `chatId`) — never both
- `CallParticipant` lives in subcollection: `calls/{callId}/participants/{userId}`
- `Signal` lives in subcollection: `calls/{callId}/signals/`
- `Signal` is **ephemeral** — `CallService.cleanupCallData()` batch-deletes all signals and participants when call ends
- `WebRTCService` manages peer connections; `CallService` handles Firestore signaling
- `CallManager` orchestrates the lifecycle and routes call messages to the appropriate chat via `DirectService.sendCallMessage()` or `GroupService.sendCallMessage()`

---

## 8. Leaderboard & Stats

```mermaid
erDiagram
    UserEntity ||--|| UserStatsEntity : "1:1 | userId PK"
    UserStatsEntity ||--|| Leaderboard : "1:1 | userId PK (denormalized)"

    UserStatsEntity {
        string userId PK "same as UserEntity.userId"
        string displayName "denormalized"
        string avatarAsset "denormalized"
        int totalMatchesPlayed "incremented on session completion"
        int pickFightWins "incremented when user wins PickFight"
        int triRaceWins "incremented when user wins TriRace"
    }

    Leaderboard {
        string userId PK "same as UserStatsEntity.userId"
        string displayName "denormalized for fast reads"
        string avatarAsset "denormalized for fast reads"
        int totalMatchesPlayed "snapshot from UserStatsEntity"
        int pickFightWins "snapshot from UserStatsEntity"
        int triRaceWins "snapshot from UserStatsEntity"
        datetime updatedAt "last update timestamp"
    }
```

**Relationship Notes:**
- `UserStatsEntity` lives at Firestore path `userStats/{userId}` (source of truth)
- `Leaderboard` lives at Firestore path `leaderboards/{userId}` (denormalized snapshot)
- `LeaderboardService.ensureUserStats()` creates both documents atomically on first write
- `LeaderboardService.recordPickFightResult()`:
  1. Increments `totalMatchesPlayed` for all participants
  2. Increments `pickFightWins` for the winner
  3. Backfills `Leaderboard` doc for immediate visibility
- `LeaderboardService.recordTriRaceResult()`: same pattern for tri-race stats
- `Leaderboard` is denormalized so ranking queries don't need to aggregate `UserStatsEntity` docs

---

## Cross-Entity Reference Summary

| Source Entity | Field | Target Entity | Reference Type |
|---------------|-------|---------------|----------------|
| `SessionEntity` | `hostId` | `UserEntity` | FK (userId) |
| `SessionEntity` | `participantUids[]` | `UserEntity` | Denormalized array |
| `SessionEntity` | `invitedUserIds[]` | `UserEntity` | Denormalized array |
| `SessionEntity` | `speedShieldWinnerId` | `UserEntity` | FK (userId) |
| `ParticipantEntity` | `id` | `UserEntity` | Same as userId |
| `ParticipantEntity` | `chosenWinnerCardId` | `CardEntity` | FK (card ID) |
| `TriRace` | `hostId` | `UserEntity` | FK (userId) |
| `TriRace` | `winnerId` | `UserEntity` | FK (userId) |
| `TriRaceParticipant` | `userId` | `UserEntity` | FK (userId) |
| `FriendEntity` | `userIds[]` | `UserEntity` | Array of 2 userIds |
| `FriendEntity` | `requestedBy` | `UserEntity` | FK (userId) |
| `NotificationEntity` | `senderId` | `UserEntity` | FK (userId) |
| `NotificationEntity` | `relatedId` | Polymorphic | Friendship/Event/Poll ID |
| `NotificationEntity` | `groupId` | `GroupChat` | FK (groupId) |
| `NotificationEntity` | `chatId` | `DirectChat` | FK (chatId) |
| `GroupChat` | `createdBy` | `UserEntity` | FK (userId) |
| `GroupChat` | `members[]` | `UserEntity` | Denormalized array |
| `ChatMessage` | `senderId` | `UserEntity` | FK (userId) |
| `ChatMessage` | `replyTo` | `ChatMessage` | Self-reference (message ID) |
| `ChatMessage` | `activityId` | `SessionEntity` or `TriRace` | Polymorphic FK |
| `ChatMessage` | `refId` | `ChatEvent` or `ChatPoll` | Polymorphic FK |
| `ChatEvent` | `createdBy` | `UserEntity` | FK (userId) |
| `ChatEvent` | `groupId` | `GroupChat` | FK (groupId, nullable) |
| `ChatEvent` | `chatId` | `DirectChat` | FK (chatId, nullable) |
| `ChatPoll` | `createdBy` | `UserEntity` | FK (userId) |
| `ChatPoll` | `groupId` | `GroupChat` | FK (groupId, nullable) |
| `ChatPoll` | `chatId` | `DirectChat` | FK (chatId, nullable) |
| `Vote` | `uid` | `UserEntity` | FK (userId, null for secret) |
| `Call` | `createdBy` | `UserEntity` | FK (userId) |
| `Call` | `groupId` | `GroupChat` | FK (nullable) |
| `Call` | `chatId` | `DirectChat` | FK (nullable) |
| `CallParticipant` | `userId` | `UserEntity` | FK (userId) |
| `Signal` | `senderId` | `UserEntity` | FK (userId) |
| `UserStatsEntity` | `userId` | `UserEntity` | FK (userId) |
| `Leaderboard` | `userId` | `UserEntity` | FK (userId) |
