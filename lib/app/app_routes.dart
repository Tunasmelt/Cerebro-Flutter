// Route paths live apart from router.dart so screens can navigate by path
// without importing the router (which imports every screen).
abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const documents = '/documents';
  static const chat = '/chat';
  static const chatHistory = '/chat/history';
  static const graph = '/graph';
  static const board = '/board';
  static const playground = '/settings/token-inspector';
  static const settings = '/settings';

  static String documentPreview(String documentId) => '$documents/$documentId';

  static String documentDetail(String documentId) =>
      '$documents/$documentId/details';
}
