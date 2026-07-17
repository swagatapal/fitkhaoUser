import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/medical_record_model.dart';

/// Medical records / prescriptions owned by the signed-in user.
class MedicalRecordRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  MedicalRecordRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Server-side cap on documents per upload.
  static const int maxDocuments = 10;

  /// POST /api/user/medical-records (multipart) — uploads up to
  /// [maxDocuments] files under the `documents` field.
  Future<MedicalRecordsResponse> uploadMedicalRecords({
    required List<File> documents,
    MedicalRecordType recordType = MedicalRecordType.prescription,
    String? notes,
    String? consultationId,
  }) async {
    if (documents.isEmpty) {
      throw ValidationException(message: 'Select at least one document.');
    }
    if (documents.length > maxDocuments) {
      throw ValidationException(
          message: 'You can upload up to $maxDocuments documents at a time.');
    }

    debugPrint(
        '[MedicalRecordRepository] Uploading ${documents.length} document(s)...');
    try {
      final json = await _apiClient.postMultipartFiles(
        AppConfig.medicalRecordsPath,
        headers: _authHeaders(),
        files: documents,
        fileFieldName: 'documents',
        fields: {
          'recordType': recordType.wire,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          if (consultationId != null && consultationId.isNotEmpty)
            'consultationId': consultationId,
        },
      );
      debugPrint('[MedicalRecordRepository] Upload response: $json');
      return MedicalRecordsResponse.fromJson(json);
    } catch (e) {
      debugPrint('[MedicalRecordRepository] Upload error: $e');
      if (e is ValidationException) rethrow;
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  /// GET /api/user/medical-records — the user's own records.
  Future<MedicalRecordsResponse> getMedicalRecords() async {
    debugPrint('[MedicalRecordRepository] Fetching medical records...');
    try {
      final json = await _apiClient.getJson(
        AppConfig.medicalRecordsPath,
        headers: _authHeaders(),
      );
      return MedicalRecordsResponse.fromJson(json);
    } catch (e) {
      debugPrint('[MedicalRecordRepository] Fetch error: $e');
      final message = ExceptionHandler.getErrorMessage(e);
      throw NetworkException(message: message, originalError: e);
    }
  }

  Map<String, String> _authHeaders() {
    final token = _localStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      throw AuthException(
          message: 'Authentication required. Please login again.');
    }
    return {'Authorization': 'Bearer $token'};
  }
}
