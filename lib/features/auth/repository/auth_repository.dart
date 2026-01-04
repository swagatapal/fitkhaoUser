import 'package:flutter/material.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../models/otp_request_model.dart';
import '../models/verify_otp_model.dart';
import '../models/profile_update_model.dart';

/// Repository for authentication related operations
/// Uses local storage and simulated data - no network calls required
class AuthRepository {
  final LocalStorageService _localStorage;
  final ApiClient _apiClient;

  AuthRepository({
    required LocalStorageService localStorage,
    required ApiClient apiClient,
  })  : _localStorage = localStorage,
        _apiClient = apiClient;

  /// Send OTP to phone number
  Future<OtpResponseModel> sendOTP({
    required String phoneNumber,
  }) async {
    debugPrint('[AuthRepository] Sending OTP via API...');
    debugPrint('[AuthRepository] Phone: $phoneNumber');

    try {
      // API currently expects only `mobileNumber` in body
      final payload = {
        'mobileNumber': phoneNumber,
      };

      final json = await _apiClient.postJson(
        AppConfig.sendOtpPath,
        headers: const {'Content-Type': 'application/json'},
        body: payload,
      );

      return OtpResponseModel.fromJson(json);
    } catch (e) {
      // Map exceptions to user-friendly messages
      final message = ExceptionHandler.getErrorMessage(e);
      throw AuthException(message: message, originalError: e);
    }
  }

  /// Verify OTP via API
  Future<VerifyOtpResponseModel> verifyOTP({
    required String phoneNumber,
    required String countryCode,
    required String otp,
    String? otpId,
  }) async {
    debugPrint('[AuthRepository] Verifying OTP via API...');

    try {
      final payload = {
        'mobileNumber': phoneNumber,
        'otp': otp,
      };

      final json = await _apiClient.postJson(
        '/api/auth/verify-otp',
        headers: const {'Content-Type': 'application/json'},
        body: payload,
      );

      final success = json['success'] == true;
      final message = (json['message'] as String?) ?? '';
      final data = json['data'] as Map<String, dynamic>?;
      final token = data != null ? data['token'] as String? : null;
      final user = data != null ? data['user'] as Map<String, dynamic>? : null;
      final userId = user != null ? (user['id'] as String?) : null;
      final userMobile = user != null ? (user['mobileNumber'] as String?) : null;

      // Extract profile name if exists
      final profile = user != null ? user['profile'] as Map<String, dynamic>? : null;
      final profileName = profile != null ? (profile['name'] as String?) : null;

      if (success) {
        // Persist
        if (token != null) {
          await _localStorage.saveAuthToken(token);
        }
        if (userId != null) {
          await _localStorage.saveUserId(userId);
        }
        if (userMobile != null) {
          await _localStorage.saveUserPhone(userMobile);
        }
        await _localStorage.setLoggedIn(true);
      }

      // Map to existing model shape for app usage
      return VerifyOtpResponseModel(
        success: success,
        message: message,
        authToken: token,
        refreshToken: null,
        user: user != null
            ? UserData(
                id: userId ?? '',
                phoneNumber: userMobile ?? phoneNumber,
                name: profileName,
                email: null,
                isNewUser: !(user['isVerified'] as bool? ?? true),
              )
            : null,
      );
    } catch (e) {
      final message = ExceptionHandler.getErrorMessage(e);
      throw AuthException(message: message, originalError: e);
    }
  }

  /// Resend OTP
  Future<OtpResponseModel> resendOTP({
    required String phoneNumber,
    required String countryCode,
  }) async {
    debugPrint('[AuthRepository] Resending OTP via API...');

    try {
      final payload = {
        'mobileNumber': phoneNumber,
      };
      final json = await _apiClient.postJson(
        AppConfig.sendOtpPath,
        headers: const {'Content-Type': 'application/json'},
        body: payload,
      );
      return OtpResponseModel.fromJson(json);
    } catch (e) {
      final message = ExceptionHandler.getErrorMessage(e);
      throw AuthException(message: message, originalError: e);
    }
  }

  /// Logout user
  Future<void> logout() async {
    debugPrint('[AuthRepository] Logging out...');
    await _localStorage.clearUserData();
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _localStorage.isLoggedIn();
  }

  /// Get stored auth token
  String? getAuthToken() {
    return _localStorage.getAuthToken();
  }

  /// Get stored user phone
  String? getUserPhone() {
    return _localStorage.getUserPhone();
  }

  /// Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    debugPrint('[AuthRepository] Fetching user profile via API...');

    try {
      // Get auth token
      final token = getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }

      // Prepare headers with Bearer token
      final headers = {
        'Authorization': 'Bearer $token',
      };

      // Make GET request
      final json = await _apiClient.getJson(
        AppConfig.updateProfilePath,
        headers: headers,
      );

      debugPrint('[AuthRepository] Profile fetch response: $json');

      return json;
    } catch (e) {
      debugPrint('[AuthRepository] Profile fetch error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw AuthException(message: message, originalError: e);
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required ProfileUpdateRequest profileData,
  }) async {
    debugPrint('[AuthRepository] Updating user profile via API...');

    try {
      // Get auth token
      final token = getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }

      // Prepare headers with Bearer token
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Convert profile data to JSON
      final payload = profileData.toFullJson();

      debugPrint('[AuthRepository] Profile payload: $payload');

      // Make PUT request
      final json = await _apiClient.putJson(
        AppConfig.updateProfilePath,
        headers: headers,
        body: payload,
      );

      debugPrint('[AuthRepository] Profile update response: $json');

      return json;
    } catch (e) {
      debugPrint('[AuthRepository] Profile update error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw AuthException(message: message, originalError: e);
    }
  }

  /// Register device for push notifications
  Future<Map<String, dynamic>> registerDevice({
    required String deviceToken,
    required String deviceType,
    required String deviceId,
    required String appVersion,
  }) async {
    debugPrint('[AuthRepository] Registering device...');

    try {
      // Get auth token
      final token = getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }

      // Prepare headers with Bearer token
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Prepare payload
      final payload = {
        'deviceToken': deviceToken,
        'deviceType': deviceType,
        'deviceId': deviceId,
        'appVersion': appVersion,
        'userType': 'user',
      };

      debugPrint('[AuthRepository] Device registration payload: $payload');

      // Make POST request
      final json = await _apiClient.postJson(
        '/api/device/register',
        headers: headers,
        body: payload,
      );

      debugPrint('[AuthRepository] Device registration response: $json');

      return json;
    } catch (e) {
      debugPrint('[AuthRepository] Device registration error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw AuthException(message: message, originalError: e);
    }
  }
}
