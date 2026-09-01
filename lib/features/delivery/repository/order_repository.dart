import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/config/app_config.dart';
import '../models/order_placement_model.dart';
import '../models/order_preview_model.dart';
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
    required List<OrderItem> items,
    required DeliveryAddress deliveryAddress,
    required String paymentMethod,
    String? specialInstructions,
    List<String> couponIds = const [],
  }) async {
    debugPrint('[OrderRepository] Placing order via API...');

    try {
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final request = OrderPlacementRequest(
        kitchenId: kitchenId,
        items: items,
        deliveryAddress: deliveryAddress,
        paymentMethod: paymentMethod,
        specialInstructions: specialInstructions,
        couponIds: couponIds,
      );

      debugPrint('[OrderRepository] Payload: ${request.toJson()}');

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

  /// Server-authoritative pricing preview for the current cart.
  /// POST /api/orders/preview — body `{ kitchenId, items, couponIds }`.
  Future<OrderPreviewResponse> previewOrder({
    required String kitchenId,
    required List<OrderItem> items,
    List<String> couponIds = const [],
  }) async {
    debugPrint('[OrderRepository] Order preview — kitchenId=$kitchenId '
        'items=${items.length} coupons=${couponIds.length}');
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

      final body = <String, dynamic>{
        'kitchenId': kitchenId,
        'items': items.map((e) => e.toJson()).toList(),
        if (couponIds.isNotEmpty) 'couponIds': couponIds,
      };

      final json = await _apiClient.postJson(
        AppConfig.orderPreviewPath,
        body: body,
        headers: headers,
      );
      return OrderPreviewResponse.fromJson(json);
    } catch (e) {
      debugPrint('[OrderRepository] Order preview error: $e');
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
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final request = WalletPaymentRequest(
        orderId: orderId,
        amount: amount,
        paymentMethod: paymentMethod,
      );

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

  /// Create a Razorpay order for wallet top-up.
  /// Sends `{ purpose: "wallet_topup", amount: <rupees> }` to the backend.
  Future<RazorpayCreateOrderResponse> createRazorpayWalletTopup({
    required int amountInRupees,
  }) async {
    debugPrint('[OrderRepository] Creating Razorpay wallet topup order...');

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

      final request = RazorpayWalletTopupRequest(amount: amountInRupees);

      debugPrint(
          '[OrderRepository] createRazorpayWalletTopup payload: ${request.toJson()}');

      final json = await _apiClient.postJson(
        AppConfig.razorpayCreateOrderPath,
        body: request.toJson(),
        headers: headers,
      );

      debugPrint('[OrderRepository] createRazorpayWalletTopup response: $json');
      return RazorpayCreateOrderResponse.fromJson(json);
    } catch (e) {
      debugPrint('[OrderRepository] createRazorpayWalletTopup error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Create a Razorpay order for a subscription purchase.
  /// Sends `{ purpose: "subscription", planId, cancelAnytimeSelected }`.
  Future<RazorpayCreateOrderResponse> createRazorpaySubscriptionOrder({
    required String planId,
    required bool cancelAnytimeSelected,
    List<String> couponIds = const [],
  }) async {
    debugPrint('[OrderRepository] Creating Razorpay subscription order — '
        'planId=$planId cancelAnytime=$cancelAnytimeSelected '
        'coupons=$couponIds');

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

      final request = RazorpaySubscriptionOrderRequest(
        planId: planId,
        cancelAnytimeSelected: cancelAnytimeSelected,
        couponIds: couponIds,
      );

      debugPrint(
          '[OrderRepository] createRazorpaySubscriptionOrder payload: ${request.toJson()}');

      final json = await _apiClient.postJson(
        AppConfig.razorpayCreateOrderPath,
        body: request.toJson(),
        headers: headers,
      );

      debugPrint(
          '[OrderRepository] createRazorpaySubscriptionOrder response: $json');
      return RazorpayCreateOrderResponse.fromJson(json);
    } catch (e) {
      debugPrint('[OrderRepository] createRazorpaySubscriptionOrder error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Create a Razorpay order on the backend.
  /// Returns a [RazorpayCreateOrderResponse] containing the Razorpay order ID
  /// and amount that should be passed to the Razorpay SDK.
  Future<RazorpayCreateOrderResponse> createRazorpayOrder({
    required RazorpayPendingOrderData pendingOrderData,
    String purpose = 'order_food',
  }) async {
    debugPrint('[OrderRepository] Creating Razorpay order...');

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

      final request = RazorpayCreateOrderRequest(
        purpose: purpose,
        pendingOrderData: pendingOrderData,
      );

      debugPrint(
          '[OrderRepository] createRazorpayOrder payload: ${request.toJson()}');

      final json = await _apiClient.postJson(
        AppConfig.razorpayCreateOrderPath,
        body: request.toJson(),
        headers: headers,
      );

      debugPrint('[OrderRepository] createRazorpayOrder response: $json');
      return RazorpayCreateOrderResponse.fromJson(json);
    } catch (e) {
      debugPrint('[OrderRepository] createRazorpayOrder error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Verify a Razorpay payment after the SDK reports success.
  /// Returns a [RazorpayVerifyPaymentResponse] with the confirmed order number.
  Future<RazorpayVerifyPaymentResponse> verifyRazorpayPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    String purpose = 'order_food',
    int? amount,
    String? planCode,
  }) async {
    debugPrint(
        '[OrderRepository] Verifying Razorpay payment — orderId=$razorpayOrderId purpose=$purpose');

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

      final request = RazorpayVerifyPaymentRequest(
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
        purpose: purpose,
        amount: amount,
        planCode: planCode,
      );

      debugPrint(
          '[OrderRepository] verifyRazorpayPayment payload: ${request.toJson()}');

      final json = await _apiClient.postJson(
        AppConfig.razorpayVerifyPaymentPath,
        body: request.toJson(),
        headers: headers,
      );

      debugPrint('[OrderRepository] verifyRazorpayPayment response: $json');
      return RazorpayVerifyPaymentResponse.fromJson(json);
    } catch (e) {
      debugPrint('[OrderRepository] verifyRazorpayPayment error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// PUT /api/orders/{orderId}/subscription-slot — change a subscription
  /// order's delivery slot and/or address (before 6 AM IST on delivery date).
  /// At least one of [slotId] / [deliveryAddressId] must be provided.
  Future<Map<String, dynamic>> updateSubscriptionOrderSlot({
    required String orderId,
    String? slotId,
    String? deliveryAddressId,
  }) async {
    debugPrint('[OrderRepository] Updating subscription slot for $orderId...');
    try {
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }
      final json = await _apiClient.putJson(
        AppConfig.orderSubscriptionSlotPath(orderId),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: {
          if (slotId != null && slotId.isNotEmpty) 'slotId': slotId,
          if (deliveryAddressId != null && deliveryAddressId.isNotEmpty)
            'deliveryAddressId': deliveryAddressId,
        },
      );
      debugPrint('[OrderRepository] Subscription slot update response: $json');
      return json;
    } catch (e) {
      debugPrint('[OrderRepository] Subscription slot update error: $e');
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
      final token = _localStorage.getAuthToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Authentication required. Please login again.',
        );
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final json = await _apiClient.postJson(
        '${AppConfig.cancelOrderPath}/$orderId',
        body: {'reason': reason},
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
