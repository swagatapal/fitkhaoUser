import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/config/app_config.dart';
import '../models/order_placement_model.dart';
import '../models/wallet_payment_model.dart';

/// Repository for order related operations
class OrderRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  OrderRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Place an order
  Future<OrderPlacementResponse> placeOrder({
    required String kitchenId,
    required String deliveryDate,
    required String deliverySlot,
    required List<OrderItem> items,
    required DeliveryAddress deliveryAddress,
    required String paymentMethod,
    String? specialInstructions,
  }) async {
    debugPrint('[OrderRepository] Placing order via API...');

    try {
      // Get auth token
      final token = _localStorage.getAuthToken();
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

      // Prepare request body
      final request = OrderPlacementRequest(
        kitchenId: kitchenId,
        deliveryDate: deliveryDate,
        deliverySlot: deliverySlot,
        items: items,
        deliveryAddress: deliveryAddress,
        paymentMethod: paymentMethod,
        specialInstructions: specialInstructions,
      );

      // Make POST request
      final json = await _apiClient.postJson(
        AppConfig.placeOrderPath,
        body: request.toJson(),
        headers: headers,
      );

      debugPrint('[OrderRepository] Place order response: $json');

      return OrderPlacementResponse.fromJson(json);
    } catch (e) {
      debugPrint('[OrderRepository] Place order error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Process wallet payment for order
  Future<WalletPaymentResponse> processWalletPayment({
    required String orderId,
    required double amount,
    required String paymentMethod,
  }) async {
    debugPrint('[OrderRepository] Processing wallet payment via API...');

    try {
      // Get auth token
      final token = _localStorage.getAuthToken();
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

      // Prepare request body
      final request = WalletPaymentRequest(
        orderId: orderId,
        amount: amount,
        paymentMethod: paymentMethod,
      );

      // Make POST request
      final json = await _apiClient.postJson(
        AppConfig.walletOrderPaymentPath,
        body: request.toJson(),
        headers: headers,
      );

      debugPrint('[OrderRepository] Wallet payment response: $json');

      return WalletPaymentResponse.fromJson(json);
    } catch (e) {
      debugPrint('[OrderRepository] Wallet payment error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Cancel an order
  Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    debugPrint('[OrderRepository] Cancelling order $orderId via API...');

    try {
      // Get auth token
      final token = _localStorage.getAuthToken();
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

      // Prepare request body
      final body = {
        'reason': reason,
      };

      // Make POST request
      final json = await _apiClient.postJson(
        '${AppConfig.cancelOrderPath}/$orderId',
        body: body,
        headers: headers,
      );

      debugPrint('[OrderRepository] Cancel order response: $json');

      return json;
    } catch (e) {
      debugPrint('[OrderRepository] Cancel order error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }
}
