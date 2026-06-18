import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/subscription_cancel_preview_model.dart';

/// Fetches the refund preview for cancelling a subscription.
///
/// Family-keyed by `subscriptionId` and auto-disposed, so a fresh preview is
/// loaded every time the cancel sheet opens (and discarded when it closes).
/// The sheet watches the returned [AsyncValue] for loading / error / data.
final subscriptionCancelPreviewProvider = FutureProvider.autoDispose
    .family<SubscriptionCancelPreview, String>((ref, subscriptionId) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  final res = await repo.getCancellationPreview(subscriptionId);
  if (!res.success || res.data == null) {
    throw Exception(res.message.isNotEmpty
        ? res.message
        : 'Could not load cancellation details. Please try again.');
  }
  return res.data!;
});
