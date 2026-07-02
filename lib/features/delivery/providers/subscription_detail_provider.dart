import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/subscription_timeline_model.dart';

/// The current user's subscription journey timeline (steps + daily meals).
/// Token-scoped, so no id is needed. `invalidate` to refresh.
final subscriptionTimelineProvider =
    FutureProvider.autoDispose<SubscriptionTimeline>((ref) async {
  // The Journey tab is the first tab and can build during the first frame —
  // before LocalStorageService has initialised. Awaiting it here guarantees
  // the auth token is ready, otherwise the repository would throw before any
  // request is even sent.
  await ref.watch(localStorageProvider.future);
  final res =
      await ref.read(subscriptionRepositoryProvider).getSubscriptionTimeline();
  if (!res.success || res.data == null) {
    throw Exception(
        res.message.isNotEmpty ? res.message : 'Could not load your journey.');
  }
  return res.data!;
});

/// Event history for a subscription (auto-disposed, keyed by subscriptionId).
/// Returns the raw event maps; the UI renders them defensively since the
/// backend schema is open-ended.
final subscriptionHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, subscriptionId) {
  return ref
      .watch(subscriptionRepositoryProvider)
      .getEventHistory(subscriptionId);
});

/// Invoice payload for a subscription (auto-disposed, keyed by subscriptionId).
final subscriptionInvoiceProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, subscriptionId) {
  return ref.watch(subscriptionRepositoryProvider).getInvoice(subscriptionId);
});
