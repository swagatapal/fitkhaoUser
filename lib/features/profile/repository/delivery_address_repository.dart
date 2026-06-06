import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/delivery_address_model.dart';

/// Outcome of a write operation (create / update / delete).
class AddressMutationResult {
  final bool success;
  final String message;

  const AddressMutationResult({required this.success, this.message = ''});
}

/// Repository for user delivery-address CRUD.
class DeliveryAddressRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  DeliveryAddressRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  Map<String, String> _authHeaders() {
    final token = _localStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      throw AuthException(
          message: 'Authentication required. Please login again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// GET /api/user/delivery-addresses
  Future<List<DeliveryAddressModel>> getAddresses() async {
    try {
      final json = await _apiClient.getJson(
        AppConfig.deliveryAddressesPath,
        headers: _authHeaders(),
      );
      final data = json['data'] as Map<String, dynamic>?;
      final list = (data?['addresses'] as List<dynamic>?)
              ?.map((e) =>
                  DeliveryAddressModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [];
      return list;
    } catch (e) {
      debugPrint('[DeliveryAddressRepository] getAddresses error: $e');
      throw NetworkException(
          message: ExceptionHandler.getErrorMessage(e), originalError: e);
    }
  }

  /// POST /api/user/delivery-address
  Future<AddressMutationResult> addAddress(DeliveryAddressModel address) async {
    try {
      final json = await _apiClient.postJson(
        AppConfig.deliveryAddressPath,
        headers: _authHeaders(),
        body: address.toRequestBody(),
      );
      return AddressMutationResult(
        success: json['success'] as bool? ?? true,
        message: json['message'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[DeliveryAddressRepository] addAddress error: $e');
      return AddressMutationResult(
          success: false, message: ExceptionHandler.getErrorMessage(e));
    }
  }

  /// PUT /api/user/delivery-address/{id}
  Future<AddressMutationResult> updateAddress(
      String id, DeliveryAddressModel address) async {
    try {
      final json = await _apiClient.putJson(
        '${AppConfig.deliveryAddressPath}/$id',
        headers: _authHeaders(),
        body: address.toRequestBody(),
      );
      return AddressMutationResult(
        success: json['success'] as bool? ?? true,
        message: json['message'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[DeliveryAddressRepository] updateAddress error: $e');
      return AddressMutationResult(
          success: false, message: ExceptionHandler.getErrorMessage(e));
    }
  }

  /// DELETE /api/user/delivery-address/{id}
  Future<AddressMutationResult> deleteAddress(String id) async {
    try {
      final json = await _apiClient.deleteJson(
        '${AppConfig.deliveryAddressPath}/$id',
        headers: _authHeaders(),
      );
      return AddressMutationResult(
        success: json['success'] as bool? ?? true,
        message: json['message'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[DeliveryAddressRepository] deleteAddress error: $e');
      return AddressMutationResult(
          success: false, message: ExceptionHandler.getErrorMessage(e));
    }
  }
}
