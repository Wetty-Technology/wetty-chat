abstract final class AppRoutes {
  static const bootstrap = '/bootstrap';
  static const login = '/login';
  static const chats = '/';
  static const archivedThreads = '/threads/archived';
  static String chatDetail(String chatId) => '/chat/$chatId';
  static String chatMembers(String chatId) => '/chat/$chatId/members';
  static String chatSettings(String chatId) => '/chat/$chatId/settings';
  static String nestedThreadDetail(String chatId, String threadRootId) =>
      '/chat/$chatId/thread/$threadRootId';
  static String nestedNewThread(String chatId, String threadRootId) =>
      '/chat/$chatId/thread/$threadRootId/new';
  static String threadDetail(String chatId, String threadRootId) =>
      '/thread/$chatId/$threadRootId';
  static const settings = '/settings';
  static const language = '/settings/language';
  static const fontSize = '/settings/font-size';
  static const profile = '/settings/profile';
  static const devSession = '/settings/dev-session';
  static const notifications = '/settings/notifications';
  static const cache = '/settings/cache';
  static const stickerPackDetailRoot = '/sticker-packs';
  static String stickerPackDetail(String packId) => '/sticker-packs/$packId';
  static const stickerPacks = '/settings/sticker-packs';
  static String settingsStickerPackDetail(String packId) =>
      '/settings/sticker-packs/$packId';
  static const attachmentViewer = '/attachment-viewer';
}
