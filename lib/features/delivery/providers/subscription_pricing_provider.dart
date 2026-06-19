import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/subscription_pricing_preview_model.dart';

/// Family argument for [subscriptionPricingPreviewProvider]. A record so it has
/// value equality (same planId + flag ⇒ same cached request).
typedef PricingPreviewArgs = ({String planId, bool cancelAnytimeSelected});

/// Fetches the server-authoritative pricing preview for a plan.
///
/// Auto-disposed + family-keyed: re-fetched whenever the checkout opens with a
/// different plan or a toggled "cancel anytime", and discarded on close. The
/// checkout screen consumes the resulting [AsyncValue] for loading/error/data.
final subscriptionPricingPreviewProvider = FutureProvider.autoDispose
    .family<SubscriptionPricingPreview, PricingPreviewArgs>((ref, args) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  final res = await repo.getPricingPreview(
    planId: args.planId,
    cancelAnytimeSelected: args.cancelAnytimeSelected,
  );
  if (!res.success || res.data == null) {
    throw Exception(res.message.isNotEmpty
        ? res.message
        : 'Could not load pricing. Please try again.');
  }
  return res.data!;
});
