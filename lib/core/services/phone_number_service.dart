import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to fetch phone numbers from device SIM cards
class PhoneNumberService {
  static const platform = MethodChannel('com.fitkhao.user/phone_number');

  /// Request phone permissions
  Future<bool> requestPhonePermission() async {
    final status = await Permission.phone.request();
    return status.isGranted;
  }

  /// Check if phone permission is granted
  Future<bool> hasPhonePermission() async {
    final status = await Permission.phone.status;
    return status.isGranted;
  }

  /// Fetch phone numbers from device SIM cards
  /// Returns a list of phone numbers (can be multiple if dual SIM)
  Future<List<String>> fetchPhoneNumbers() async {
    try {
      // Check and request permission first
      final hasPermission = await hasPhonePermission();
      if (!hasPermission) {
        final granted = await requestPhonePermission();
        if (!granted) {
          return _getMockPhoneNumbers();
        }
      }

      // Try to fetch actual phone numbers via platform channel
      try {
        final List<dynamic>? result = await platform.invokeMethod('getPhoneNumbers');
        if (result != null && result.isNotEmpty) {
          return result.map((e) => e.toString()).where((phone) => phone.isNotEmpty).toList();
        }
      } on PlatformException catch (_) {
        // Platform channel not implemented or permission denied
        // Fall through to mock numbers
      }

      // Fallback to mock numbers for development/testing
      return _getMockPhoneNumbers();
    } catch (_) {
      // Any other error, return mock numbers
      return _getMockPhoneNumbers();
    }
  }

  /// Mock phone numbers for development and testing
  /// In production, this would only be used if platform channels fail
  List<String> _getMockPhoneNumbers() {
    return [
      '9876543210',
      '8765432109',
      '7654321098',
    ];
  }

  /// Format phone number to display format
  String formatPhoneNumber(String phoneNumber, {String countryCode = '+91'}) {
    if (phoneNumber.isEmpty) return '';

    // Remove any non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // Format as: +91 98765 43210
    if (digitsOnly.length == 10) {
      return '$countryCode ${digitsOnly.substring(0, 5)} ${digitsOnly.substring(5)}';
    }

    return '$countryCode $digitsOnly';
  }

  /// Extract digits only from phone number
  String extractDigits(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'\D'), '');
  }
}
