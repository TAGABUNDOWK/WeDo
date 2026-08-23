  # Bottom Navigation Bar Redesign — Glassmorphism Pill Navigation

## Context

The current `HomePage` (`lib/screens/home/home_page.dart:51-86`) uses a neumorphic full-width bottom navigation bar with 4 icon+text items (Home, Chat, Friends, Session) using Material `Icon` widgets. The task is to replace this with a 5-icon, 3-capsule glassmorphic floating pill navigation bar, reassigning tab mappings and adding a new placeholder Account screen.

## Files to Modify

### 1. `lib/screens/home/home_page.dart` (major rewrite of nav section)
- **Remove:** `_NavItem` widget class (lines 89-131), `_PlaceholderTab` widget class (lines 298-324, dead code)
- **Rewrite:** `_HomePageState.build()` — replace `bottomNavigationBar` with a new floating glassmorphic nav bar
- **Update `_tabs`:** Change from 4 items `[Home, Chat, Friends, Session]` to 5 items `[Home, Chat, Friends, Session, Account]` — preserving IndexedStack architecture
- **Add imports:** `dart:ui` (for `ImageFilter`), new `AccountScreen`

### 2. `lib/screens/account/account_screen.dart` (new file)
- Simple placeholder screen with the same dark scaffold background (`Color(0xFF190831)`) and a centered "Account" label
- Functional route target for the Account nav tab

## Detailed Design

### Nav Bar Layout (3 capsules in a Row)

```
┌──────────────────────────────────────────────┐
│  ┌─────────────┐  ┌───┐  ┌─────────────┐    │
│  │ Home  Chat  │  │LOGO│  │Friends Account│   │
│  └─────────────┘  └───┘  └─────────────┘    │
│   Left capsule   Center   Right capsule      │
└──────────────────────────────────────────────┘
```

- **Left capsule:** indices 0 (Home) + 1 (Chat) — pill shape
- **Center capsule:** circular, slightly larger/elevated, uses `WeDo-Logo.png`, triggers index 3 (Session)
- **Right capsule:** indices 2 (Friends) + 4 (Account) — pill shape

### Index Mapping

| Visual Position | Icon Asset | Index | Screen |
|----------------|------------|-------|--------|
| Left 1 | `assets/icons/home.png` | 0 | `_HomeTab` |
| Left 2 | `assets/icons/message.png` | 1 | `ChatTab` |
| Center | `assets/images/WeDo-Logo.png` | 3 | `SessionEntryScreen` |
| Right 1 | `assets/icons/friends.png` | 2 | `FriendsPage` |
| Right 2 | `assets/icons/avatar.png` | 4 | `AccountScreen` |

Note: The prompt says `frineds.png` but the actual asset is `friends.png` — will use the correct filename.

### Glassmorphism Styling

```dart
// Per-capsule container:
ClipRRect(
  borderRadius: BorderRadius.circular(25), // pill shape
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
          width: 1,
        ),
      ),
    ),
  ),
)
```

- Center capsule: same but `BoxShape.circle`, size ~60x60 (larger than side items ~44x44)

### Active/Inactive Icon States

- **Active:** PNG icon tinted pink using `ColorFiltered(colorFilter: ColorFilter.mode(Color(0xFFFE4EF0), BlendMode.srcIn))`
- **Inactive:** PNG icon tinted muted gray using `ColorFiltered(colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.5), BlendMode.srcIn))`
- **Center logo:** Uses opacity (1.0 active, 0.5 inactive) instead of color filter since it has its own gradient colors
- Active item gets subtle scale animation (`AnimatedScale` with `scale: 1.1`)
- Tap feedback: scale-down to 0.95 on tap, matching existing `_GradientButton`/`_GlassButton` pattern

### Center Logo Elevated Effect

The center capsule sits in a `Stack` overlapping the row, translated upward slightly (~15px) with a glow shadow:
```dart
BoxShadow(
  color: Color(0xFFFE4EF0).withOpacity(0.4),
  blurRadius: 20,
  spreadRadius: 2,
)
```

### Positioning

- The entire nav bar is a `Positioned` widget near the bottom of a `Stack` that wraps the body content
- `bottom: MediaQuery.of(context).padding.bottom + 16` for safe area
- Horizontal margin: `EdgeInsets.symmetric(horizontal: 16)`
- The nav bar sits above animated background layers (high z-index via Stack ordering)

### Home Page Structure Change

The current structure is:
```dart
Scaffold(
  body: SafeArea(child: IndexedStack(...)),
  bottomNavigationBar: Container(...old nav...),
)
```

New structure:
```dart
Scaffold(
  backgroundColor: bg,
  body: Stack(
    children: [
      SafeArea(child: IndexedStack(...)),
      Positioned(
        left: 16, right: 16, bottom: ...,
        child: _GlassNavBar(...)
      ),
    ],
  ),
)
```

This ensures the nav bar floats above content and the animated background layers (from screens like Welcome/Login) can still show through.

## Verification

1. Run `flutter analyze` — no errors or warnings from changed files
2. Visual check: 3 glassmorphic capsules with correct icons visible
3. Tap each icon — correct screen appears in IndexedStack
4. Center logo tap — navigates to Session tab (index 3)
5. Active state: pink tint + scale on selected icon
6. Tap animation: brief scale-down feedback on all items
7. Safe area: nav bar doesn't overlap system gestures on iOS/Android
8. Account tab shows placeholder screen
