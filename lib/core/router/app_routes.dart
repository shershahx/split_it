// Route names for easy access
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String groups = '/groups';
  static const String createGroup = '/groups/create';
  static const String friends = '/friends';
  static const String addFriend = '/friends/add';
  static const String activity = '/activity';
  static const String account = '/account';
  static const String profile = '/account/profile';
  static const String settings = '/account/settings';
  static const String scanReceipt = '/scan-receipt';

  static String groupDetail(String groupId) => '/groups/$groupId';
  static String groupAddExpense(String groupId) => '/groups/$groupId/add-expense';
  static String groupSettle(String groupId) => '/groups/$groupId/settle';
  static String friendDetail(String friendId) => '/friends/$friendId';
  static String expenseDetail(String expenseId) => '/expense/$expenseId';
}
