import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static String? userId;
  static String? username;
  static String? role;

  static const String _keyUserId = 'user_id';
  static const String _keyUsername = 'username';
  static const String _keyRole = 'role';

  /// Load saved session from disk. Call once at app startup (e.g. in main()).
  static Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString(_keyUserId);
      username = prefs.getString(_keyUsername);
      role = prefs.getString(_keyRole);
    } catch (_) {
      userId = null;
      username = null;
      role = null;
    }
  }

  static bool get isLoggedIn => userId != null && userId!.isNotEmpty;

  static void setCurrentUser(String id, String name, [String? userRole]) {
    userId = id;
    username = name;
    role = userRole;
    _persist();
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserId, userId ?? '');
      await prefs.setString(_keyUsername, username ?? '');
      await prefs.setString(_keyRole, role ?? '');
    } catch (_) {}
  }

  static Future<void> clear() async {
    userId = null;
    username = null;
    role = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyRole);
    } catch (_) {}
  }
}
