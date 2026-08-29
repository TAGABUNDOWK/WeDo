import 'package:flutter/material.dart';

class AppColors {
  static const Color midnightBg = Color(0xFF180d2c);
  static const Color glassBg = Color(0x99211635);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color lavenderAccent = Color(0xFFd1bcff);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFb8a9d4);
  static const Color inputBorder = Color(0x33FFFFFF);
  static const Color divider = Color(0x1AFFFFFF);
  static const Color neonMagenta = Color(0xFFd100d1);
  static const Color eventCardBg = Color(0xCC211635);
}

class AppConstants {
  static const String usersCollection = 'users';
  static const String groupsCollection = 'group_chats';
  static const String groupMembersSubcollection = 'members';
  static const String groupMessagesSubcollection = 'messages';
  static const String directChatsCollection = 'direct_chats';
  static const String directChatMessagesSubcollection = 'messages';
  static const String friendsCollection = 'friends';
  static const String topicsCollection = 'topics';
  static const String cardsSubcollection = 'cards';
  static const String sessionsCollection = 'sessions';
  static const String triRacesCollection = 'triRaces';
  static const String participantsSubcollection = 'participants';
  static const String notificationsCollection = 'notifications';
  static const String callsCollection = 'calls';
  static const String callSignalsSubcollection = 'signals';
  static const String callParticipantsSubcollection = 'participants';
  static const String eventsSubcollection = 'events';
  static const String pollsSubcollection = 'polls';
  static const String votesSubcollection = 'votes';

  // TMDB API (proxied through Vercel)
  static const String tmdbProxyUrl = 'https://wedo-api.vercel.app/tmdb';
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/w500';
}
