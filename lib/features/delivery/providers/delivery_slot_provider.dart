import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/delivery_slot_model.dart';
import '../repository/delivery_slot_repository.dart';

/// State for delivery slot data from API
class DeliverySlotState {
  final List<DeliverySlotApiModel> slots;
  final bool isLoading;
  final String? error;

  const DeliverySlotState({
    this.slots = const [],
    this.isLoading = false,
    this.error,
  });

  DeliverySlotState copyWith({
    List<DeliverySlotApiModel>? slots,
    bool? isLoading,
    String? error,
  }) {
    return DeliverySlotState(
      slots: slots ?? this.slots,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Notifier for delivery slot state
class DeliverySlotNotifier extends StateNotifier<DeliverySlotState> {
  final DeliverySlotRepository _repository;

  DeliverySlotNotifier(this._repository) : super(const DeliverySlotState());

  /// Load delivery slots from API
  Future<void> loadDeliverySlots() async {
    debugPrint('[DeliverySlotNotifier] Loading delivery slots...');

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.getDeliverySlots();

      if (response.success && response.data != null) {
        // Only keep active slots and sort by time
        final activeSlots = response.data!.slots
            .where((slot) => slot.isActive)
            .toList();

        // Sort: morning first, afternoon second, night last
        activeSlots.sort((a, b) {
          const order = {'morning': 0, 'afternoon': 1, 'night': 2};
          return (order[a.slotType] ?? 3).compareTo(order[b.slotType] ?? 3);
        });

        state = DeliverySlotState(
          slots: activeSlots,
          isLoading: false,
          error: null,
        );
        debugPrint('[DeliverySlotNotifier] Loaded ${activeSlots.length} active slots');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty
              ? response.message
              : 'Failed to load delivery slots',
        );
      }
    } catch (e) {
      debugPrint('[DeliverySlotNotifier] Error loading slots: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load delivery slots',
      );
    }
  }

  /// Refresh delivery slots
  Future<void> refresh() async {
    await loadDeliverySlots();
  }
}

/// Provider for delivery slot state (API data)
final deliverySlotApiProvider =
    StateNotifierProvider<DeliverySlotNotifier, DeliverySlotState>((ref) {
  final repo = ref.watch(deliverySlotRepositoryProvider);
  return DeliverySlotNotifier(repo);
});
