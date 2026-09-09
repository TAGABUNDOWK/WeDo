import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/direct_chat.dart';
import '../../models/group_chat.dart';
import '../../models/user_entity.dart';
import '../../services/group/group_service.dart';
import '../../services/direct/direct_service.dart';
import '../../utils/time_format.dart';
import '../../utils/responsive.dart';
import 'group/group_chat_screen.dart';
import 'group/create_group_screen.dart';
import 'direct/direct_chat_screen.dart';
import 'direct/new_direct_chat.dart';

enum _ChatFilter { all, fresh, unread }

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _groupService = GroupService();
  final _directService = DirectService();
  final Map<String, UserEntity?> _userCache = {};
  final _searchCtrl = TextEditingController();

  _ChatFilter _filter = _ChatFilter.all;
  String _query = '';
  bool _showDirects = true;
  bool _showGroups = true;
  bool _recentOnly = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<UserEntity?> _getCachedUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    final user = await _directService.getUser(uid);
    if (mounted) {
      _userCache[uid] = user;
      // Refresh search filtering once names resolve.
      if (_query.isNotEmpty) setState(() {});
    } else {
      _userCache[uid] = user;
    }
    return user;
  }

  void _showNewChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        final w = MediaQuery.of(context).size.width;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: Responsive.sheetMaxWidth(w)),
                child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1045),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const _GlassIconCircle(
                iconPath: 'assets/icons/add-chat.png',
                fallback: Icons.group_add,
              ),
              title: const Text(
                'Create group chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Chat with multiple people',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
              },
            ),
            ListTile(
              leading: const _GlassIconCircle(
                iconPath: 'assets/icons/message.png',
                fallback: Icons.chat_bubble_outline,
              ),
              title: const Text(
                'New message',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Start a direct conversation',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewDirectChatScreen()),
                );
              },
            ),
          ],
        ),
              ),
            ),
          ),
        ),
        );
      },
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: Responsive.sheetMaxWidth(w)),
                child: StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1045),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter conversations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Applies to recent contacts, messages and groups.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FilterChip(
                    label: 'Recent',
                    selected: _recentOnly,
                    onTap: () {
                      setSheetState(() => _recentOnly = !_recentOnly);
                      setState(() {});
                    },
                  ),
                  _FilterChip(
                    label: 'Messages',
                    selected: _showDirects,
                    onTap: () {
                      setSheetState(() => _showDirects = !_showDirects);
                      setState(() {});
                    },
                  ),
                  _FilterChip(
                    label: 'Groups',
                    selected: _showGroups,
                    onTap: () {
                      setSheetState(() => _showGroups = !_showGroups);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    setSheetState(() {
                      _recentOnly = false;
                      _showDirects = true;
                      _showGroups = true;
                    });
                    setState(() {});
                  },
                  child: const Text(
                    'Reset filters',
                    style: TextStyle(color: Color(0xFFFE4EF0), fontFamily: 'Poppins'),
                  ),
                ),
              ),
            ],
          ),
              ),
            ),
          ),
        ),
        ),
        );
      },
    );
  }

  void _openGroupChat(String groupId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => GroupChatScreen(groupId: groupId),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ).then((_) {
      if (uid != null) _groupService.markMessagesAsRead(groupId, uid);
    });
  }

  void _openDirectChat(String chatId, String otherUid) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => DirectChatScreen(chatId: chatId, otherUid: otherUid),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ).then((_) {
      if (uid != null) _directService.markMessagesAsRead(chatId, uid);
    });
  }

  bool _isNew(DateTime? lastAt, String? senderId, String currentUid) {
    if (lastAt == null || senderId == null || senderId == currentUid) return false;
    return DateTime.now().difference(lastAt) <= const Duration(hours: 24);
  }

  bool _isRecent(DateTime? lastAt) {
    if (lastAt == null) return false;
    return DateTime.now().difference(lastAt) <= const Duration(days: 7);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final screenH = MediaQuery.of(context).size.height;
    final fabSize = Responsive.fabSize(
      MediaQuery.of(context).size.width,
      screenH,
    );
    // Transparent so the shared HomePage AnimatedBackground
    // (gradient + animated circles + dots) shows through.
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        // Clear the floating glass nav bar in HomePage.
        padding: EdgeInsets.only(bottom: Responsive.fabBottom(context)),
        child: Tooltip(
          message: 'New chat',
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: fabSize,
                height: fabSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showNewChatMenu,
                    customBorder: const CircleBorder(),
                    splashColor:
                        Colors.white.withValues(alpha: 0.08),
                    child: Center(
                      child: Image.asset(
                        'assets/icons/add-chat.png',
                        width: fabSize * 0.5,
                        height: fabSize * 0.5,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.add_comment_outlined,
                          color: const Color(0xFFFE4EF0),
                          size: fabSize * 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: currentUser == null
          ? const Center(
              child: Text(
                'Sign in to view your chats',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                final f = FocusScope.of(context);
                if (f.hasFocus) f.unfocus();
              },
              child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                // S <360, M 360-400, L 400-480, XL phone 480+.
                // Tablets/XL keep centered single column (max 720).
                final isSmall = Responsive.isSmallPhone(w);
                final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0
                    ? constraints.maxHeight
                    : MediaQuery.of(context).size.height;
                final hPad = Responsive.hPad(w);
                final contentMax = Responsive.contentMax(w);
                final logoSize = Responsive.chatLogoSize(w);
                final topVPad = Responsive.chatTopVPad(w, h);

                return SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMax),
                      child: Column(
                        children: [
                          // ── 1. Top bar ──
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              hPad,
                              topVPad,
                              hPad,
                              4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/images/WeDo-Logo.png',
                                      width: logoSize,
                                      height: logoSize,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.casino,
                                        color: Color(0xFFFE4EF0),
                                        size: 40,
                                      ),
                                    ),
                                    SizedBox(width: (w * 0.025).clamp(8.0, 12.0)),
                                    Flexible(
                                      child: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: ShaderMask(
                                        shaderCallback: (bounds) =>
                                            const LinearGradient(
                                          colors: [
                                            Color(0xFFFE4EF0),
                                            Color(0xFF800DD8)
                                          ],
                                        ).createShader(bounds),
                                        child: MediaQuery(
                                          data: MediaQuery.of(context).copyWith(
                                            textScaler: Responsive.cappedTextScaler(
                                                context),
                                          ),
                                          child: Text(
                                          'WeDo',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'PressStart2P',
                                            fontSize: Responsive.chatTitleSize(w),
                                            color: Colors.white,
                                          ),
                                        ),
                                        ),
                                      ),
                                    ),
                                    ),
                                  ],
                                ),
                                ),
                              ],
                            ),
                          ),
                          // ── 2. Search bar ──
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              hPad,
                              2,
                              hPad,
                              4,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: 48),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.14),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 16),
                                        child: Image.asset(
                                          'assets/icons/search.png',
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.search,
                                            size: 20,
                                            color: Color(0xFFFE4EF0),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _searchCtrl,
                                          textInputAction: TextInputAction.search,
                                          onSubmitted: (_) =>
                                              FocusScope.of(context).unfocus(),
                                          onTapOutside: (_) =>
                                              FocusScope.of(context).unfocus(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Search friends and groups',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.45),
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 14,
                                            ),
                                            suffixIcon: _query.isNotEmpty
                                                ? IconButton(
                                                    onPressed: () => _searchCtrl.clear(),
                                                    icon: Icon(
                                                      Icons.close,
                                                      size: 18,
                                                      color: Colors.white.withValues(alpha: 0.6),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _showFilterOptions,
                                        child: Builder(
                                          builder: (context) {
                                            final filtersActive =
                                                _recentOnly ||
                                                    !_showDirects ||
                                                    !_showGroups;
                                            return Container(
                                              margin: const EdgeInsets.only(
                                                  right: 8),
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: filtersActive
                                                    ? Colors.white.withValues(
                                                        alpha: 0.12)
                                                    : Colors.transparent,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: filtersActive
                                                      ? const Color(0xFFFE4EF0)
                                                      : Colors.white.withValues(
                                                          alpha: 0.12),
                                                  width:
                                                      filtersActive ? 1.5 : 1,
                                                ),
                                                boxShadow: filtersActive
                                                    ? [
                                                        BoxShadow(
                                                          color: const Color(
                                                                  0xFFFE4EF0)
                                                              .withValues(
                                                                  alpha: 0.3),
                                                          blurRadius: 10,
                                                          offset:
                                                              const Offset(
                                                                  0, 2),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: Center(
                                                child: Image.asset(
                                                  'assets/icons/filter.png',
                                                  width: 18,
                                                  height: 18,
                                                  fit: BoxFit.contain,
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                          const Icon(
                                                    Icons.tune,
                                                    size: 18,
                                                    color: Color(0xFFFE4EF0),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // ── 3. Filter tabs ──
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              hPad,
                              isSmall ? 8 : 10,
                              hPad,
                              6,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _TabPill(
                                      label: 'All Messages',
                                      selected: _filter == _ChatFilter.all,
                                      compact: isSmall,
                                      onTap: () =>
                                          setState(() => _filter = _ChatFilter.all),
                                    ),
                                    SizedBox(
                                        width: (w * 0.02).clamp(6.0, 10.0)),
                                    _TabPill(
                                      label: 'New',
                                      selected: _filter == _ChatFilter.fresh,
                                      compact: isSmall,
                                      onTap: () => setState(
                                          () => _filter = _ChatFilter.fresh),
                                    ),
                                    SizedBox(
                                        width: (w * 0.02).clamp(6.0, 10.0)),
                                    _TabPill(
                                      label: 'Unread',
                                      selected: _filter == _ChatFilter.unread,
                                      compact: isSmall,
                                      onTap: () => setState(
                                          () => _filter = _ChatFilter.unread),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // ── 4. Chat list ──
                          Expanded(
                            child: StreamBuilder<List<GroupChat>>(
                              stream: _groupService.getUserGroupsStream(currentUser.uid),
                              builder: (context, groupSnap) {
                                if (groupSnap.hasError) {
                                  return Center(
                                      child: Text('Error: ${groupSnap.error}',
                                          style: const TextStyle(
                                              color: Colors.white54)));
                                }
                                if (groupSnap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator(
                                          color: Color(0xFFFE4EF0)));
                                }
                                final groups = groupSnap.data ?? [];
                                return StreamBuilder<List<DirectChat>>(
                                  stream: _directService
                                      .getUserChatsStream(currentUser.uid),
                                  builder: (context, dmSnap) {
                                    if (dmSnap.hasError) {
                                      return Center(
                                          child: Text('Error: ${dmSnap.error}',
                                              style: const TextStyle(
                                                  color: Colors.white54)));
                                    }
                                    if (dmSnap.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator(
                                              color: Color(0xFFFE4EF0)));
                                    }
                                    final directChats = dmSnap.data ?? [];

                                    if (groups.isEmpty && directChats.isEmpty) {
                                      return _EmptyChats(onCreate: _showNewChatMenu);
                                    }

                                    final allChats = <_ChatItem>[];
                                    for (final g in groups) {
                                      allChats.add(_ChatItem.group(g));
                                    }
                                    for (final d in directChats) {
                                      allChats.add(_ChatItem.direct(d));
                                    }
                                    allChats.sort((a, b) {
                                      final aTime =
                                          a.lastMessageAt ?? DateTime(0);
                                      final bTime =
                                          b.lastMessageAt ?? DateTime(0);
                                      return bTime.compareTo(aTime);
                                    });

                                    // Pre-filter synchronously so hidden chats
                                    // never occupy a ListView slot. Returning
                                    // SizedBox.shrink() inside itemBuilder
                                    // still leaves separators behind, which
                                    // caused uneven/phantom gaps on larger
                                    // phones when many items were filtered.
                                    // Direct names use the cache (fallback to
                                    // uid); FutureBuilder below only fills in
                                    // avatar/name, it no longer decides
                                    // visibility for type/tab filters.
                                    final visibleChats = <_ChatItem>[];
                                    for (final item in allChats) {
                                      if (item.isGroup) {
                                        final group = item.group!;
                                        final hasUnread = group.lastMessage !=
                                                    null &&
                                                group.lastMessageSenderId !=
                                                    null &&
                                                group.lastMessageSenderId !=
                                                    currentUser.uid &&
                                                !group.lastMessageReadBy
                                                    .contains(currentUser.uid);
                                        final isNew = _isNew(
                                          group.lastMessageAt,
                                          group.lastMessageSenderId,
                                          currentUser.uid,
                                        );
                                        if (_passesFilters(
                                          isGroup: true,
                                          hasUnread: hasUnread,
                                          isNew: isNew,
                                          lastAt: group.lastMessageAt,
                                          name: group.name,
                                          lastMessage: group.lastMessage,
                                        )) {
                                          visibleChats.add(item);
                                        }
                                      } else {
                                        final chat = item.direct!;
                                        final otherUid = chat.otherUserId(
                                            currentUser.uid);
                                        final hasUnread =
                                            chat.lastMessage != null &&
                                                chat.lastMessageSenderId !=
                                                    null &&
                                                chat.lastMessageSenderId !=
                                                    currentUser.uid &&
                                                !chat.lastMessageReadBy
                                                    .contains(currentUser.uid);
                                        final isNew = _isNew(
                                          chat.lastMessageAt,
                                          chat.lastMessageSenderId,
                                          currentUser.uid,
                                        );
                                        if (!_passesTypeAndTabFilters(
                                          isGroup: false,
                                          hasUnread: hasUnread,
                                          isNew: isNew,
                                          lastAt: chat.lastMessageAt,
                                        )) {
                                          continue;
                                        }
                                        final cachedName =
                                            _userCache[otherUid]
                                                    ?.displayName ??
                                                otherUid;
                                        if (_passesSearch(
                                          cachedName,
                                          chat.lastMessage,
                                        )) {
                                          visibleChats.add(item);
                                        }
                                      }
                                    }

                                    if (visibleChats.isEmpty) {
                                      final filtering = _query.isNotEmpty ||
                                          _filter != _ChatFilter.all ||
                                          _recentOnly ||
                                          !_showDirects ||
                                          !_showGroups;
                                      if (!filtering) {
                                        return _EmptyChats(
                                            onCreate: _showNewChatMenu);
                                      }
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 32),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.search_off_outlined,
                                                size: 40,
                                                color: Colors.white.withValues(
                                                    alpha: 0.4),
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'No conversations match',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Try a different search or reset filters.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white.withValues(
                                                      alpha: 0.55),
                                                  fontSize: 12,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    // Fixed separator keeps rhythm identical on
                                    // small / medium / large / XL phones.
                                    // Spacing no longer depends on how many
                                    // items were filtered out.
                                    final separatorHeight =
                                        Responsive.chatSeparator(w);

                                    return ListView.separated(
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior.onDrag,
                                      padding: EdgeInsets.fromLTRB(
                                        hPad,
                                        6,
                                        hPad,
                                        Responsive.listBottom(context),
                                      ),
                                      itemCount: visibleChats.length,
                                      separatorBuilder: (_, __) =>
                                          SizedBox(
                                              height: separatorHeight),
                                      itemBuilder: (context, index) {
                                        final item = visibleChats[index];
                                        if (item.isGroup) {
                                          final group = item.group!;
                                          final hasUnread = group.lastMessage !=
                                                      null &&
                                                  group.lastMessageSenderId !=
                                                      null &&
                                                  group.lastMessageSenderId !=
                                                      currentUser.uid &&
                                                  !group.lastMessageReadBy
                                                      .contains(currentUser.uid);
                                          final isNew = _isNew(
                                            group.lastMessageAt,
                                            group.lastMessageSenderId,
                                            currentUser.uid,
                                          );
                                          // Already pre-filtered above.
                                          return _RedesignedChatRow(
                                            parentWidth: w,
                                            name: group.name,
                                            lastMessage: group.lastMessage,
                                            lastMessageAt:
                                                group.lastMessageAt,
                                            isGroup: true,
                                            hasUnread: hasUnread,
                                            isNew: isNew,
                                            avatarUrl: group.photoUrl,
                                            avatarAsset: null,
                                            onTap: () =>
                                                _openGroupChat(group.id),
                                          );
                                        } else {
                                          final chat = item.direct!;
                                          final otherUid = chat.otherUserId(
                                              currentUser.uid);
                                          final hasUnread =
                                              chat.lastMessage != null &&
                                                  chat.lastMessageSenderId !=
                                                      null &&
                                                  chat.lastMessageSenderId !=
                                                      currentUser.uid &&
                                                  !chat.lastMessageReadBy
                                                      .contains(
                                                          currentUser.uid);
                                          final isNew = _isNew(
                                            chat.lastMessageAt,
                                            chat.lastMessageSenderId,
                                            currentUser.uid,
                                          );
                                          // Type/tab already pre-filtered.
                                          // Search was pre-filtered with cached
                                          // name; re-check after load and hide
                                          // transiently if it now fails. The
                                          // next rebuild drops it from
                                          // visibleChats so no phantom gap
                                          // remains.
                                          return FutureBuilder<UserEntity?>(
                                            future:
                                                _getCachedUser(otherUid),
                                            builder:
                                                (context, userSnap) {
                                              final user = userSnap.data ??
                                                  _userCache[otherUid];
                                              final displayName =
                                                  user?.displayName ??
                                                      otherUid;
                                              if (!_passesSearch(
                                                displayName,
                                                chat.lastMessage,
                                              )) {
                                                return const SizedBox.shrink();
                                              }
                                              return _RedesignedChatRow(
                                                parentWidth: w,
                                                name: displayName,
                                                lastMessage:
                                                    chat.lastMessage,
                                                lastMessageAt:
                                                    chat.lastMessageAt,
                                                isGroup: false,
                                                hasUnread: hasUnread,
                                                isNew: isNew,
                                                avatarUrl:
                                                    user?.photoUrl,
                                                avatarAsset:
                                                    user?.avatarAsset,
                                                onTap: () => _openDirectChat(
                                                    chat.id, otherUid),
                                              );
                                            },
                                          );
                                        }
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }

  bool _passesSearch(String name, String? lastMessage) {
    if (_query.isEmpty) return true;
    return name.toLowerCase().contains(_query) ||
        (lastMessage?.toLowerCase().contains(_query) ?? false);
  }

  bool _passesTypeAndTabFilters({
    required bool isGroup,
    required bool hasUnread,
    required bool isNew,
    required DateTime? lastAt,
  }) {
    if (isGroup && !_showGroups) return false;
    if (!isGroup && !_showDirects) return false;
    if (_recentOnly && !_isRecent(lastAt)) return false;
    switch (_filter) {
      case _ChatFilter.all:
        return true;
      case _ChatFilter.fresh:
        return isNew;
      case _ChatFilter.unread:
        return hasUnread;
    }
  }

  bool _passesFilters({
    required bool isGroup,
    required bool hasUnread,
    required bool isNew,
    required DateTime? lastAt,
    required String name,
    required String? lastMessage,
  }) {
    if (!_passesTypeAndTabFilters(
      isGroup: isGroup,
      hasUnread: hasUnread,
      isNew: isNew,
      lastAt: lastAt,
    )) {
      return false;
    }
    return _passesSearch(name, lastMessage);
  }
}

class _ChatItem {
  final GroupChat? group;
  final DirectChat? direct;
  final bool isGroup;

  _ChatItem.group(this.group) : direct = null, isGroup = true;
  _ChatItem.direct(this.direct) : group = null, isGroup = false;

  DateTime? get lastMessageAt =>
      isGroup ? group?.lastMessageAt : direct?.lastMessageAt;
}

// ── Filter tabs ──

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFE4EF0)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFFE4EF0)
                : Colors.white.withValues(alpha: 0.12),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFE4EF0)
                        .withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 12 : 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFE4EF0)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFFE4EF0)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}

// ── Glassmorphism icon circle (bottom-sheet rows) ──

class _GlassIconCircle extends StatelessWidget {
  final String iconPath;
  final IconData fallback;

  const _GlassIconCircle({
    required this.iconPath,
    required this.fallback,
  });

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFE4EF0).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: ColorFiltered(
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              child: Image.asset(
                iconPath,
                width: _size * 0.5,
                height: _size * 0.5,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  fallback,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Redesigned chat row ──

class _RedesignedChatRow extends StatelessWidget {
  final double parentWidth;
  final String name;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool isGroup;
  final bool hasUnread;
  final bool isNew;
  final String? avatarUrl;
  final String? avatarAsset;
  final VoidCallback onTap;

  const _RedesignedChatRow({
    required this.parentWidth,
    required this.name,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.isGroup,
    required this.hasUnread,
    required this.isNew,
    required this.avatarUrl,
    required this.avatarAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Uses parent constraints width so split-screen / foldables match layout.
    final w = parentWidth;
    final avatarRadius = Responsive.chatAvatarRadius(w);
    final hasAsset = avatarAsset != null && avatarAsset!.isNotEmpty;
    final hasUrl = avatarUrl != null && avatarUrl!.isNotEmpty;
    final preview = (lastMessage?.isNotEmpty ?? false)
        ? lastMessage!
        : 'No messages yet';
    // #FE4EF0 at 100% while unread, 50% once read.
    final previewColor = hasUnread
        ? const Color(0xFFFE4EF0)
        : const Color(0xFFFE4EF0).withValues(alpha: 0.5);
    final timeText = formatListTime(lastMessageAt);
    // Single gate: fresh (<=24h, not mine) + unread. Covers text, event,
    // poll, invite, system. Otherwise fully hidden (zero size, no gap).
    final showNew = isNew && hasUnread;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 68),
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.chatRowHPad(w),
                vertical: Responsive.chatRowVPad(w),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: hasUnread
                      ? const Color(0xFFFE4EF0)
                          .withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: const Color(0xFFFE4EF0)
                        .withValues(alpha: 0.2),
                    backgroundImage: hasAsset
                        ? AssetImage(avatarAsset!)
                        : (hasUrl ? NetworkImage(avatarUrl!) : null)
                            as ImageProvider?,
                    child: (!hasAsset && !hasUrl)
                        ? Icon(
                            isGroup ? Icons.group : Icons.person,
                            color: const Color(0xFFFE4EF0),
                            size: avatarRadius,
                          )
                        : null,
                  ),
                  SizedBox(width: Responsive.chatRowGap(w)),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                  fontSize: Responsive.chatNameSize(w),
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: Responsive.chatPreviewSize(w),
                                  fontFamily: 'Poppins',
                                  color: previewColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (timeText.isEmpty)
                              const SizedBox.shrink()
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  timeText,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.clip,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: Responsive.chatTimeSize(w),
                                    fontFamily: 'Poppins',
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (showNew)
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _PulseDot(),
                                  SizedBox(width: 4),
                                  Text(
                                    'NEW',
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                      color: Color(0xFFFE4EF0),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              )
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pulsing NEW dot ──

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFFFE4EF0),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFE4EF0)
                    .withValues(alpha: 0.6),
                blurRadius: 8 * _scale.value,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyChats({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final iconSize = Responsive.emptyIconSize(w);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
                Icons.forum_outlined,
                size: iconSize * 0.45,
                color: const Color(0xFFFE4EF0)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No chats yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a conversation with friends',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFE4EF0),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.message),
            label: const Text('New chat'),
          ),
        ],
        ),
      ),
    );
  }
}
