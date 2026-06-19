import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';

/// Event history for a subscription (auto-disposed, keyed by subscriptionId).
/// Returns the raw event maps; the UI renders them defensively since the
/// backend schema is open-ended.
final subscriptionHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, subscriptionId) {
  return ref.watch(subscriptionRepositoryProvider).getEventHistory(subscriptionId);
});

/// Invoice payload for a subscription (auto-disposed, keyed by subscriptionId).
final subscriptionInvoiceProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, subscriptionId) {
  return ref.watch(subscriptionRepositoryProvider).getInvoice(subscriptionId);
});
