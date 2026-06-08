import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/config/app_config.dart';
import '../models/order_history_model.dart';

/// Repository for order history operations
class OrderHistoryRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  OrderHistoryRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Generate and fetch the invoice URL for a given order.
  Future<String> getInvoiceUrl(String orderId) async {
    debugPrint('[OrderHistoryRepository] Generating invoice for order: $orderId');

    final token = _localStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      throw AuthException(message: 'Authentication required. Please login again.');
    }

    try {
      final json = await _apiClient.getJson(
        '${AppConfig.orderInvoicePath}/$orderId/invoice',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[OrderHistoryRepository] Invoice response: $json');

      final success = json['success'] as bool? ?? false;
      if (!success) {
        final msg = json['message'] as String? ?? 'Failed to generate invoice';
        throw NetworkException(message: msg, originalError: null);
      }

      final url = (json['data'] as Map<String, dynamic>?)?['invoiceUrl'] as String?;
      if (url == null || url.isEmpty) {
        throw NetworkException(message: 'Invoice URL not found', originalError: null);
      }

      return url;
    } catch (e) {
      debugPrint('[OrderHistoryRepository] Invoice error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Fetch the full, up-to-date details for a single order.
  ///
  /// GET /api/orders/:orderId/details — the payload is the order object, parsed
  /// with the same [OrderHistory.fromJson] used by the list. Handles both
  /// `data: {...}` and `data: { order: {...} }` envelope shapes.
  Future<OrderHistory> getOrderById(String orderId) async {
    debugPrint('[OrderHistoryRepository] Fetching order details: $orderId');

    if (orderId.isEmpty) {
      throw NetworkException(message: 'Invalid order id', originalError: null);
    }

    final token = _localStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      throw AuthException(
        message: 'Authentication required. Please login again.',
      );
    }

    try {
      final json = await _apiClient.getJson(
        '${AppConfig.orderInvoicePath}/$orderId/details',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Endpoints sometimes omit `success`; default to true when absent.
      final success = json['success'] as bool? ?? true;

      Map<String, dynamic>? orderJson;
      final data = json['data'];
      if (data is Map<String, dynamic>) {
        orderJson = data['order'] is Map<String, dynamic>
            ? data['order'] as Map<String, dynamic>
            : data;
      } else if (json['order'] is Map<String, dynamic>) {
        orderJson = json['order'] as Map<String, dynamic>;
      }

      if (!success || orderJson == null || orderJson.isEmpty) {
        throw NetworkException(
          message: json['message'] as String? ?? 'Order details not found',
          originalError: null,
        );
      }

      return OrderHistory.fromJson(orderJson);
    } catch (e) {
      debugPrint('[OrderHistoryRepository] Order details error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Fetch order history with pagination
  Future<OrderHistoryResponse> getOrderHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    debugPrint('[OrderHistoryRepository] Fetching order history via API...');

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

      // Build path with query parameters
      final path = '${AppConfig.orderHistoryPath}?limit=$limit&offset=$offset';

      // Make GET request
      final json = await _apiClient.getJson(
        path,
        headers: headers,
      );

      debugPrint('[OrderHistoryRepository] Order history response: $json');

      return OrderHistoryResponse.fromJson(json);
    } catch (e) {
      debugPrint('[OrderHistoryRepository] Order history error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }
}
