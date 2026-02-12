import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'firebase_notification_service.dart';

/// Service for getting device information
class DeviceInfoService {
  static DeviceInfoService? _instance;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Private constructor
  DeviceInfoService._();

  /// Get singleton instance
  static DeviceInfoService getInstance() {
    _instance ??= DeviceInfoService._();
    return _instance!;
  }

  /// Get device type (android or ios)
  Future<String> getDeviceType() async {
    try {
      if (Platform.isAndroid) {
        return 'android';
      } else if (Platform.isIOS) {
        return 'ios';
      }
      return 'unknown';
    } catch (e) {
      debugPrint('[DeviceInfoService] Error getting device type: $e');
      return 'unknown';
    }
  }

  /// Get unique device ID
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use androidId as unique identifier
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Use identifierForVendor as unique identifier
        return iosInfo.identifierForVendor ?? 'unknown';
      }
      return 'unknown';
    } catch (e) {
      debugPrint('[DeviceInfoService] Error getting device ID: $e');
      return 'unknown';
    }
  }

  /// Get app version
  Future<String> getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      debugPrint('[DeviceInfoService] Error getting app version: $e');
      return '1.0.0';
    }
  }

  /// Get device token (FCM token)
  Future<String> getDeviceToken() async {
    try {
      debugPrint('[DeviceInfoService] Getting FCM token...');

      // Get Firebase notification service instance
      final firebaseService = FirebaseNotificationService.getInstance();
      final token = await firebaseService.getToken();

      debugPrint('[DeviceInfoService] FCM token obtained: $token');
      return token;
    } catch (e) {
      debugPrint('[DeviceInfoService] Error getting device token: $e');
      // Return empty string if Firebase is not initialized or error occurs
      return '';
    }
  }

  /// Get device model
  Future<String> getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.utsname.machine;
      }
      return 'unknown';
    } catch (e) {
      debugPrint('[DeviceInfoService] Error getting device model: $e');
      return 'unknown';
    }
  }

  /// Get OS version
  Future<String> getOsVersion() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion}';
      }
      return 'unknown';
    } catch (e) {
      debugPrint('[DeviceInfoService] Error getting OS version: $e');
      return 'unknown';
    }
  }

  /// Get all device information as a map
  Future<Map<String, String>> getAllDeviceInfo() async {
    final deviceType = await getDeviceType();
    final deviceId = await getDeviceId();
    final deviceToken = await getDeviceToken();
    final appVersion = await getAppVersion();
    final deviceModel = await getDeviceModel();
    final osVersion = await getOsVersion();

    return {
      'deviceType': deviceType,
      'deviceId': deviceId,
      'deviceToken': deviceToken,
      'appVersion': appVersion,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
    };
  }
}
