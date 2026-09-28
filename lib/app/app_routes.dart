// Route paths live apart from router.dart so screens can navigate by path
// without importing the router (which imports every screen).
abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const documents = '/documents';
  static const chat = '/chat';
  static const graph = '/graph';
  static const board = '/board';
  static const playground = '/playground';
  static const settings = '/settings';
}
