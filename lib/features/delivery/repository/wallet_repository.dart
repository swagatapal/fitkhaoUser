import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/config/app_config.dart';
import '../models/wallet_balance_model.dart';
import '../models/wallet_topup_model.dart';
import '../models/transaction_model.dart';

/// Repository for wallet related operations
class WalletRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  WalletRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Get wallet balance and subscription info
  Future<WalletBalanceResponse> getWalletBalance() async {
    debugPrint('[WalletRepository] Fetching wallet balance via API...');

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

      // Make GET request
      final json = await _apiClient.getJson(
        '/api/wallet/balance',
        headers: headers,
      );

      debugPrint('[WalletRepository] Wallet balance response: $json');

      return WalletBalanceResponse.fromJson(json);
    } catch (e) {
      debugPrint('[WalletRepository] Wallet balance error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Top-up wallet balance
  Future<WalletTopupResponse> topupWallet({
    required int amount,
    required String paymentMethod,
    required String transactionId,
    String? description,
  }) async {
    debugPrint('[WalletRepository] Topping up wallet with amount: $amount via API...');

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
      final request = WalletTopupRequest(
        amount: amount,
        paymentMethod: paymentMethod,
        transactionId: transactionId,
        description: description,
      );

      // Make POST request
      final json = await _apiClient.postJson(
        AppConfig.walletTopupPath,
        body: request.toJson(),
        headers: headers,
      );

      debugPrint('[WalletRepository] Wallet topup response: $json');

      return WalletTopupResponse.fromJson(json);
    } catch (e) {
      debugPrint('[WalletRepository] Wallet topup error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Get wallet transaction history (paginated).
  Future<TransactionResponse> getTransactionHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    debugPrint('[WalletRepository] Fetching transaction history '
        '(limit: $limit, offset: $offset)...');

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

      // Make GET request
      final json = await _apiClient.getJson(
        '${AppConfig.walletTransactionsPath}?limit=$limit&offset=$offset',
        headers: headers,
      );

      debugPrint('[WalletRepository] Transaction history response: $json');

      return TransactionResponse.fromJson(json);
    } catch (e) {
      debugPrint('[WalletRepository] Transaction history error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }
}
