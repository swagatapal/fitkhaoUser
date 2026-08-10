import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/consultation_models.dart';

/// Nutritionist listing, slot availability and consultation booking.
class ConsultationRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  ConsultationRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// GET /api/user/nutritionists
  Future<NutritionistsResponse> getNutritionists() async {
    debugPrint('[ConsultationRepository] Fetching nutritionists...');
    try {
      final json = await _apiClient.getJson(
        AppConfig.nutritionistsPath,
        headers: _authHeaders(),
      );
      return NutritionistsResponse.fromJson(json);
    } catch (e) {
      throw _wrap(e, 'nutritionists');
    }
  }

  /// GET /api/adm/nutritionist/{id}/slots?date=YYYY-MM-DD
  Future<NutritionistSlotsResponse> getSlots({
    required String nutritionistId,
    required String date,
  }) async {
    debugPrint('[ConsultationRepository] Fetching slots for $nutritionistId '
        'on $date...');
    try {
      final json = await _apiClient.getJson(
        '${AppConfig.nutritionistSlotsPath(nutritionistId)}?date=$date',
        headers: _authHeaders(),
      );
      return NutritionistSlotsResponse.fromJson(json);
    } catch (e) {
      throw _wrap(e, 'slots');
    }
  }

  /// POST /api/user/consultations/book-slot
  Future<BookSlotResponse> bookSlot({
    required String availabilityId,
    required String consultationTimeId,
  }) async {
    debugPrint('[ConsultationRepository] Booking slot '
        '($availabilityId / $consultationTimeId)...');
    try {
      final json = await _apiClient.postJson(
        AppConfig.consultationBookSlotPath,
        headers: _authHeaders(),
        body: {
          'availabilityId': availabilityId,
          'consultationTimeId': consultationTimeId,
        },
      );
      return BookSlotResponse.fromJson(json);
    } catch (e) {
      throw _wrap(e, 'book');
    }
  }

  /// GET /api/user/consultations/active-subscription — the current
  /// consultation for the user's active subscription (token-scoped).
  Future<ActiveConsultationResponse> getActiveSubscriptionConsultation() async {
    try {
      final json = await _apiClient.getJson(
        AppConfig.consultationActiveSubscriptionPath,
        headers: _authHeaders(),
      );
      return ActiveConsultationResponse.fromJson(json);
    } catch (e) {
      throw _wrap(e, 'active-subscription');
    }
  }

  /// POST /api/user/consultations/cancel-slot
  Future<Map<String, dynamic>> cancelSlot({
    required String consultationId,
    String? reason,
  }) async {
    try {
      return await _apiClient.postJson(
        AppConfig.consultationCancelSlotPath,
        headers: _authHeaders(),
        body: {
          'consultationId': consultationId,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      );
    } catch (e) {
      throw _wrap(e, 'cancel');
    }
  }

  /// GET /api/consultations?subscriptionId={id} — every consultation booked
  /// under the subscription. Returns the raw records (each carries
  /// `consultationNumber` and `_id`).
  Future<List<Map<String, dynamic>>> getSubscriptionConsultations(
      String subscriptionId) async {
    try {
      final json = await _apiClient.getJson(
        '${AppConfig.consultationsPath}?subscriptionId=$subscriptionId',
        headers: _authHeaders(),
      );
      final data = json['data'];
      List<dynamic> raw;
      if (data is List) {
        raw = data;
      } else if (data is Map<String, dynamic>) {
        raw = (data['consultations'] ??
            data['items'] ??
            data['docs'] ??
            const <dynamic>[]) as List<dynamic>;
      } else {
        raw = const <dynamic>[];
      }
      return raw.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      throw _wrap(e, 'consultations');
    }
  }

  /// PATCH /api/consultations/{id}/status — updates the status (e.g. "missed").
  Future<Map<String, dynamic>> updateConsultationStatus({
    required String consultationId,
    required String status,
    String? notes,
  }) async {
    try {
      return await _apiClient.patchJson(
        AppConfig.consultationStatusPath(consultationId),
        headers: _authHeaders(),
        body: {
          'status': status,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
    } catch (e) {
      throw _wrap(e, 'consultation-status');
    }
  }

  /// Marks the consultation with [consultationNumber] under [subscriptionId] as
  /// "missed" (skipped): resolves its id via the list endpoint, then PATCHes.
  Future<void> skipConsultation({
    required String subscriptionId,
    required int consultationNumber,
    String? notes,
  }) async {
    final list = await getSubscriptionConsultations(subscriptionId);
    final match = list.firstWhere(
      (c) => (c['consultationNumber'] as num?)?.toInt() == consultationNumber,
      orElse: () => const <String, dynamic>{},
    );
    final id = (match['_id'] ?? match['id']) as String?;
    if (id == null || id.isEmpty) {
      throw NetworkException(
          message: 'Consultation not found.', originalError: null);
    }
    await updateConsultationStatus(
      consultationId: id,
      status: 'missed',
      notes: notes,
    );
  }

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

  NetworkException _wrap(Object e, String label) {
    debugPrint('[ConsultationRepository] $label error: $e');
    return NetworkException(
        message: ExceptionHandler.getErrorMessage(e), originalError: e);
  }
}
