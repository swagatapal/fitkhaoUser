import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/cart_model.dart';

/// Repository for the server-backed cart.
///
/// The cart is keyed on `outletDishId`. A POST upserts a line to an absolute
/// quantity — `quantity: 0` removes it. There is no bulk-clear endpoint, so a
/// full clear is performed by removing each line.
class CartRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  CartRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  Map<String, String> _authHeaders() {
    final token = _localStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      throw AuthException(
        message: 'Authentication required. Please login again.',
      );
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// GET /cart — the authoritative, fully-populated cart.
  Future<CartResponse> getCart() async {
    try {
      final json = await _apiClient.getJson(
        AppConfig.cartPath,
        headers: _authHeaders(),
      );
      return CartResponse.fromJson(json);
    } catch (e) {
      debugPrint('[CartRepository] getCart error: $e');
      if (e is AuthException) rethrow;
      throw NetworkException(
        message: ExceptionHandler.getErrorMessage(e),
        originalError: e,
      );
    }
  }

  /// POST /cart — set [outletDishId] to an absolute [quantity].
  /// Pass `quantity: 0` to remove the line.
  Future<CartResponse> setItemQuantity({
    required String outletDishId,
    required int quantity,
    int dishServing = 1,
    String? specialInstructions,
  }) async {
    try {
      final body = <String, dynamic>{
        'outletDishId': outletDishId,
        'quantity': quantity,
        if (quantity > 0) 'dishServing': dishServing,
        if (specialInstructions != null && specialInstructions.isNotEmpty)
          'specialInstructions': specialInstructions,
      };
      final json = await _apiClient.postJson(
        AppConfig.cartPath,
        headers: _authHeaders(),
        body: body,
      );
      return CartResponse.fromJson(json);
    } catch (e) {
      debugPrint('[CartRepository] setItemQuantity error: $e');
      if (e is AuthException) rethrow;
      throw NetworkException(
        message: ExceptionHandler.getErrorMessage(e),
        originalError: e,
      );
    }
  }
}
