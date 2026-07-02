import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/delivery_slot_model.dart';

/// Slots already confirmed for the active subscription, keyed by date-only
/// [DateTime] for O(1) calendar lookups (GET /api/delivery-slots/confirm).
///
/// `invalidate` this after a confirm or a slot cancellation to re-sync.
final confirmedSlotsProvider =
    FutureProvider.autoDispose<Map<DateTime, ConfirmedSlotDay>>((ref) async {
  final repo = ref.watch(deliverySlotRepositoryProvider);
  final res = await repo.getConfirmedSlots();
  if (!res.success || res.data == null) {
    throw Exception(res.message.isNotEmpty
        ? res.message
        : 'Could not load confirmed slots.');
  }
  // Keep a date only while it still has at least one live slot. Once every
  // slot is cancelled (orderId == null) the date frees up for re-booking.
  final map = <DateTime, ConfirmedSlotDay>{};
  for (final day in res.data!.confirmedSlots) {
    final d = day.date;
    if (d != null && day.hasActiveSlots) map[d] = day;
  }
  return map;
});
