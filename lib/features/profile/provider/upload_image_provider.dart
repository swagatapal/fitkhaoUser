import '../../../core/providers/providers.dart';
import '../repository/upload_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for UploadRepository
/// Handles image uploads with remote API
final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return UploadRepository(apiClient: apiClient, localStorage: localStorage);
});
