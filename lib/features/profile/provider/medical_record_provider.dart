import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers/providers.dart';
import '../models/medical_record_model.dart';
import '../repository/medical_record_repository.dart';

final medicalRecordRepositoryProvider =
    Provider<MedicalRecordRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }
  return MedicalRecordRepository(
      apiClient: apiClient, localStorage: localStorage);
});

/// The user's own medical records, newest first.
///
/// Awaits local storage before touching the repository so it can be watched
/// during the first frame without tripping the "not initialized" guard.
/// `invalidate` after a successful upload to refresh.
final medicalRecordsProvider =
    FutureProvider.autoDispose<List<MedicalRecord>>((ref) async {
  await ref.watch(localStorageProvider.future);
  final res =
      await ref.read(medicalRecordRepositoryProvider).getMedicalRecords();
  final records = [...res.records]..sort((a, b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad); // newest first
    });
  return records;
});

/// State of an in-flight prescription upload.
class MedicalRecordUploadState {
  final bool isUploading;
  final String? error;

  const MedicalRecordUploadState({this.isUploading = false, this.error});
}

class MedicalRecordUploadNotifier
    extends StateNotifier<MedicalRecordUploadState> {
  MedicalRecordUploadNotifier(this._ref)
      : super(const MedicalRecordUploadState());

  final Ref _ref;

  /// Uploads [documents] and refreshes the list on success.
  /// Returns `true` when the server accepted the upload.
  Future<bool> upload({
    required List<File> documents,
    MedicalRecordType recordType = MedicalRecordType.prescription,
    String? notes,
    String? consultationId,
  }) async {
    if (state.isUploading) return false; // guard double taps
    state = const MedicalRecordUploadState(isUploading: true);
    try {
      final res =
          await _ref.read(medicalRecordRepositoryProvider).uploadMedicalRecords(
                documents: documents,
                recordType: recordType,
                notes: notes,
                consultationId: consultationId,
              );
      if (!res.success) {
        state = MedicalRecordUploadState(
          error: res.message.isNotEmpty
              ? res.message
              : 'Upload failed. Please try again.',
        );
        return false;
      }
      state = const MedicalRecordUploadState();
      _ref.invalidate(medicalRecordsProvider);
      return true;
    } on AppException catch (e) {
      state = MedicalRecordUploadState(error: e.message);
      return false;
    } catch (_) {
      state = const MedicalRecordUploadState(
          error: 'Upload failed. Please try again.');
      return false;
    }
  }
}

final medicalRecordUploadProvider = StateNotifierProvider.autoDispose<
    MedicalRecordUploadNotifier,
    MedicalRecordUploadState>((ref) => MedicalRecordUploadNotifier(ref));
