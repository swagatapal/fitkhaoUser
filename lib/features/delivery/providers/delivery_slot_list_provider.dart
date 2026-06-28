import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/delivery_slot_model.dart';

/// Catalogue of selectable delivery slots (GET /api/delivery-slot/list).
/// Cached for the session; the slot-picker sheet consumes the [AsyncValue].
final deliverySlotListProvider =
    FutureProvider<List<DeliverySlotApiModel>>((ref) async {
  final repo = ref.watch(deliverySlotRepositoryProvider);
  final res = await repo.getDeliverySlotList();
  if (!res.success || res.data == null) {
    throw Exception(res.message.isNotEmpty
        ? res.message
        : 'Could not load delivery slots.');
  }
  return res.data!.slots.where((s) => s.isActive).toList();
});
