import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/config/app_config.dart';
import '../models/coupon_model.dart';

class CouponRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  CouponRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Fetches the coupons the current user is eligible for.
  ///
  /// [ruleTypes] narrows the result to a comma-separated set of rule types
  /// (e.g. `subscription`), matching the backend's `?ruleTypes=` filter. When
  /// empty every eligible coupon is returned.
  Future<CouponListResponse> fetchEligibleCoupons(
      {String ruleTypes = ''}) async {
    debugPrint('[CouponRepository] Fetching eligible coupons '
        '(ruleTypes=${ruleTypes.isEmpty ? 'all' : ruleTypes})...');

    try {
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
            message: 'Authentication required. Please login again.');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final path = ruleTypes.isEmpty
          ? AppConfig.eligibleCouponsPath
          : '${AppConfig.eligibleCouponsPath}'
              '?ruleTypes=${Uri.encodeQueryComponent(ruleTypes)}';

      final json = await _apiClient.getJson(path, headers: headers);

      debugPrint('[CouponRepository] Eligible coupons response: $json');
      return CouponListResponse.fromJson(json);
    } catch (e) {
      debugPrint('[CouponRepository] Error fetching coupons: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }
}
