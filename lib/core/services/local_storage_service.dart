import 'package:shared_preferences/shared_preferences.dart';
import '../errors/app_exception.dart';

/// Local storage service for persisting data using SharedPreferences
class LocalStorageService {
  static LocalStorageService? _instance;
  static SharedPreferences? _preferences;

  // Private constructor
  LocalStorageService._();

  /// Get singleton instance
  static Future<LocalStorageService> getInstance() async {
    _instance ??= LocalStorageService._();
    _preferences ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Storage keys
  static const String _keyAuthToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserPhone = 'user_phone';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyOnboardingComplete = 'onboarding_complete';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLanguage = 'language';

  /// Save auth token
  Future<bool> saveAuthToken(String token) async {
    try {
      return await _preferences!.setString(_keyAuthToken, token);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save auth token',
        originalError: e,
      );
    }
  }

  /// Get auth token
  String? getAuthToken() {
    try {
      return _preferences!.getString(_keyAuthToken);
    } catch (e) {
      return null;
    }
  }

  /// Save refresh token
  Future<bool> saveRefreshToken(String token) async {
    try {
      return await _preferences!.setString(_keyRefreshToken, token);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save refresh token',
        originalError: e,
      );
    }
  }

  /// Get refresh token
  String? getRefreshToken() {
    try {
      return _preferences!.getString(_keyRefreshToken);
    } catch (e) {
      return null;
    }
  }

  /// Save user ID
  Future<bool> saveUserId(String userId) async {
    try {
      return await _preferences!.setString(_keyUserId, userId);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save user ID',
        originalError: e,
      );
    }
  }

  /// Get user ID
  String? getUserId() {
    try {
      return _preferences!.getString(_keyUserId);
    } catch (e) {
      return null;
    }
  }

  /// Save user phone
  Future<bool> saveUserPhone(String phone) async {
    try {
      return await _preferences!.setString(_keyUserPhone, phone);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save user phone',
        originalError: e,
      );
    }
  }

  /// Get user phone
  String? getUserPhone() {
    try {
      return _preferences!.getString(_keyUserPhone);
    } catch (e) {
      return null;
    }
  }

  /// Save user name
  Future<bool> saveUserName(String name) async {
    try {
      return await _preferences!.setString(_keyUserName, name);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save user name',
        originalError: e,
      );
    }
  }

  /// Get user name
  String? getUserName() {
    try {
      return _preferences!.getString(_keyUserName);
    } catch (e) {
      return null;
    }
  }

  /// Save user email
  Future<bool> saveUserEmail(String email) async {
    try {
      return await _preferences!.setString(_keyUserEmail, email);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save user email',
        originalError: e,
      );
    }
  }

  /// Get user email
  String? getUserEmail() {
    try {
      return _preferences!.getString(_keyUserEmail);
    } catch (e) {
      return null;
    }
  }

  /// Set logged in status
  Future<bool> setLoggedIn(bool value) async {
    try {
      return await _preferences!.setBool(_keyIsLoggedIn, value);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save login status',
        originalError: e,
      );
    }
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    try {
      return _preferences!.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Set onboarding complete status
  Future<bool> setOnboardingComplete(bool value) async {
    try {
      return await _preferences!.setBool(_keyOnboardingComplete, value);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save onboarding status',
        originalError: e,
      );
    }
  }

  /// Check if onboarding is complete
  bool isOnboardingComplete() {
    try {
      return _preferences!.getBool(_keyOnboardingComplete) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Save theme mode
  Future<bool> saveThemeMode(String mode) async {
    try {
      return await _preferences!.setString(_keyThemeMode, mode);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save theme mode',
        originalError: e,
      );
    }
  }

  /// Get theme mode
  String? getThemeMode() {
    try {
      return _preferences!.getString(_keyThemeMode);
    } catch (e) {
      return null;
    }
  }

  /// Save language
  Future<bool> saveLanguage(String language) async {
    try {
      return await _preferences!.setString(_keyLanguage, language);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save language',
        originalError: e,
      );
    }
  }

  /// Get language
  String? getLanguage() {
    try {
      return _preferences!.getString(_keyLanguage);
    } catch (e) {
      return null;
    }
  }

  /// Clear all user data (on logout)
  Future<bool> clearUserData() async {
    try {
      await _preferences!.remove(_keyAuthToken);
      await _preferences!.remove(_keyRefreshToken);
      await _preferences!.remove(_keyUserId);
      await _preferences!.remove(_keyUserPhone);
      await _preferences!.remove(_keyUserName);
      await _preferences!.remove(_keyUserEmail);
      await _preferences!.setBool(_keyIsLoggedIn, false);
      return true;
    } catch (e) {
      throw CacheException(
        message: 'Failed to clear user data',
        originalError: e,
      );
    }
  }

  /// Clear all data
  Future<bool> clearAll() async {
    try {
      return await _preferences!.clear();
    } catch (e) {
      throw CacheException(
        message: 'Failed to clear all data',
        originalError: e,
      );
    }
  }

  /// Save generic string value
  Future<bool> saveString(String key, String value) async {
    try {
      return await _preferences!.setString(key, value);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save string value',
        originalError: e,
      );
    }
  }

  /// Get generic string value
  String? getString(String key) {
    try {
      return _preferences!.getString(key);
    } catch (e) {
      return null;
    }
  }

  /// Save generic bool value
  Future<bool> saveBool(String key, bool value) async {
    try {
      return await _preferences!.setBool(key, value);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save bool value',
        originalError: e,
      );
    }
  }

  /// Get generic bool value
  bool? getBool(String key) {
    try {
      return _preferences!.getBool(key);
    } catch (e) {
      return null;
    }
  }

  /// Save generic int value
  Future<bool> saveInt(String key, int value) async {
    try {
      return await _preferences!.setInt(key, value);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save int value',
        originalError: e,
      );
    }
  }

  /// Get generic int value
  int? getInt(String key) {
    try {
      return _preferences!.getInt(key);
    } catch (e) {
      return null;
    }
  }
}
