import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/subscription_pricing_preview_model.dart';

/// Family argument for [subscriptionPricingPreviewProvider]. A record so it has
/// value equality (same planId + flag + coupons ⇒ same cached request).
///
/// [couponIds] is a comma-joined string rather than a `List<String>` on
/// purpose: records compare their fields with `==`, and two equal lists are not
/// `==`, so a list field would defeat the cache and refetch on every rebuild.
typedef PricingPreviewArgs = ({
  String planId,
  bool cancelAnytimeSelected,
  String couponIds,
});

/// Builds the family key, normalising the coupon ids so the same set always
/// produces the same key regardless of selection order.
PricingPreviewArgs pricingPreviewArgs({
  required String planId,
  required bool cancelAnytimeSelected,
  Iterable<String> couponIds = const [],
}) {
  final ids = couponIds.where((e) => e.isNotEmpty).toList()..sort();
  return (
    planId: planId,
    cancelAnytimeSelected: cancelAnytimeSelected,
    couponIds: ids.join(','),
  );
}

/// Fetches the server-authoritative pricing preview for a plan.
///
/// Auto-disposed + family-keyed: re-fetched whenever the checkout opens with a
/// different plan, a toggled "cancel anytime", or a changed coupon selection,
/// and discarded on close. The checkout screen consumes the resulting
/// [AsyncValue] for loading/error/data.
final subscriptionPricingPreviewProvider = FutureProvider.autoDispose
    .family<SubscriptionPricingPreview, PricingPreviewArgs>((ref, args) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  final res = await repo.getPricingPreview(
    planId: args.planId,
    cancelAnytimeSelected: args.cancelAnytimeSelected,
    couponIds: args.couponIds.isEmpty ? const [] : args.couponIds.split(','),
  );
  if (!res.success || res.data == null) {
    throw Exception(res.message.isNotEmpty
        ? res.message
        : 'Could not load pricing. Please try again.');
  }
  return res.data!;
});
