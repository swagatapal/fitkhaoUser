import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/app_constants_model.dart';

/// Global provider for runtime app constants fetched from the backend.
///
/// - Loaded once and cached for the lifetime of the ProviderContainer.
/// - Never emits an error state — falls back to [AppConstants.defaults]
///   so widgets can always use `.value ?? AppConstants.defaults` safely.
final appConstantsProvider = FutureProvider<AppConstants>((ref) async {
  final repo = ref.read(appContentRepositoryProvider);
  return repo.getAppConstants();
});
