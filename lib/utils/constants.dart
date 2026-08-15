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
  static const String participantsSubcollection = 'participants';
  static const String notificationsCollection = 'notifications';

  // TMDB API (proxied through Vercel)
  static const String tmdbProxyUrl = 'https://wedo-api.vercel.app/tmdb';
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/w500';
}
