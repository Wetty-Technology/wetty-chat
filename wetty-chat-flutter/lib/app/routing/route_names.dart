abstract final class AppRoutes {
  static const chats = '/chats';
  static const newChat = '/chats/new';
  static String chatDetail(String chatId) => '/chats/$chatId';
  static String chatMembers(String chatId) => '/chats/$chatId/members';
  static String chatSettings(String chatId) => '/chats/$chatId/settings';
  static const settings = '/settings';
  static const language = '/settings/language';
  static const fontSize = '/settings/font-size';
  static const profile = '/settings/profile';
  static const devSession = '/settings/dev-session';
  static const notifications = '/settings/notifications';
  static const attachmentViewer = '/attachment-viewer';
}
