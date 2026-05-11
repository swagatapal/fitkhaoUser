import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/config/app_config.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  NotificationRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  Map<String, String> _authHeaders() {
    final token = _localStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      throw const AuthException(
          message: 'Authentication required. Please login again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all non-deleted notifications
  Future<List<AppNotification>> getNotifications() async {
    debugPrint('[NotificationRepository] Fetching notifications...');
    try {
      final json = await _apiClient.getJson(
        '${AppConfig.notificationsPath}?isDeleted=false',
        headers: _authHeaders(),
      );
      debugPrint('[NotificationRepository] Response: $json');
      return NotificationResponse.fromJson(json).notifications;
    } catch (e) {
      debugPrint('[NotificationRepository] Fetch error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// Mark notifications as read and/or deleted.
  /// Both lists are optional — only non-empty lists are sent.
  Future<void> updateNotifications({
    List<String>? readNotiList,
    List<String>? deleteNotiList,
  }) async {
    debugPrint(
        '[NotificationRepository] Updating — read:${readNotiList?.length}, delete:${deleteNotiList?.length}');
    try {
      final body = <String, dynamic>{};
      if (readNotiList != null && readNotiList.isNotEmpty) {
        body['readNotiList'] = readNotiList;
      }
      if (deleteNotiList != null && deleteNotiList.isNotEmpty) {
        body['deleteNotiList'] = deleteNotiList;
      }
      if (body.isEmpty) return;

      await _apiClient.patchJson(
        AppConfig.notificationsPath,
        body: body,
        headers: _authHeaders(),
      );
      debugPrint('[NotificationRepository] Update success');
    } catch (e) {
      debugPrint('[NotificationRepository] Update error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }
}
