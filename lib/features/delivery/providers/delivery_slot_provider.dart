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
  final bool alreadyConfirmed;
  final List<PreviousSlotSelection> previousSelection;
  final List<AvailableMealCategory> availableMeals;
  final bool isWithinWindow;
  final String deliveryDate;

  const DeliverySlotState({
    this.slots = const [],
    this.isLoading = false,
    this.error,
    this.alreadyConfirmed = false,
    this.previousSelection = const [],
    this.availableMeals = const [],
    this.isWithinWindow = false,
    this.deliveryDate = '',
  });

  DeliverySlotState copyWith({
    List<DeliverySlotApiModel>? slots,
    bool? isLoading,
    String? error,
    bool? alreadyConfirmed,
    List<PreviousSlotSelection>? previousSelection,
    List<AvailableMealCategory>? availableMeals,
    bool? isWithinWindow,
    String? deliveryDate,
  }) {
    return DeliverySlotState(
      slots: slots ?? this.slots,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      alreadyConfirmed: alreadyConfirmed ?? this.alreadyConfirmed,
      previousSelection: previousSelection ?? this.previousSelection,
      availableMeals: availableMeals ?? this.availableMeals,
      isWithinWindow: isWithinWindow ?? this.isWithinWindow,
      deliveryDate: deliveryDate ?? this.deliveryDate,
    );
  }
}

/// Notifier for delivery slot state
class DeliverySlotNotifier extends StateNotifier<DeliverySlotState> {
  final DeliverySlotRepository _repository;

  DeliverySlotNotifier(this._repository) : super(const DeliverySlotState());

  /// Load delivery slots using the combined API with date parameter
  Future<void> loadDeliverySlots() async {
    debugPrint('[DeliverySlotNotifier] Loading delivery slots...');

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Calculate tomorrow's date
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final date =
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

      final response = await _repository.getDeliverySlotsWithSelections(date: date);

      if (response.success && response.data != null) {
        final data = response.data!;

        // Sort slots by time
        final sortedSlots = List<DeliverySlotApiModel>.from(data.slots);
        sortedSlots.sort((a, b) {
          final hourA = _parseHour(a.slotStartTime);
          final hourB = _parseHour(b.slotStartTime);
          return hourA.compareTo(hourB);
        });

        state = DeliverySlotState(
          slots: sortedSlots,
          isLoading: false,
          error: null,
          alreadyConfirmed: data.alreadyConfirmed,
          previousSelection: data.previousSelection,
          availableMeals: data.availableMeals,
          isWithinWindow: data.isWithinWindow,
          deliveryDate: data.deliveryDate,
        );
        debugPrint(
            '[DeliverySlotNotifier] Loaded ${sortedSlots.length} slots, alreadyConfirmed: ${data.alreadyConfirmed}');
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

  /// Parse hour from time string like "8:00 AM" or "12:00 PM"
  int _parseHour(String time) {
    try {
      final parts = time.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final period = parts.length > 1 ? parts[1].toUpperCase() : '';
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return hour;
    } catch (_) {
      return 0;
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
