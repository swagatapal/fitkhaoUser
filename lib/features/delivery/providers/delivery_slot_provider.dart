import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/delivery_slot_model.dart';

export '../models/delivery_slot_model.dart' show SelectionWindow;

class DeliverySlotState {
  final List<DeliverySlotApiModel> slots;
  final bool isLoading;
  final String? error;
  final bool alreadyConfirmed;
  final List<PreviousSlotSelection> previousSelection;
  final List<AvailableMealCategory> availableMeals;
  final bool isWithinWindow;
  final String deliveryDate;
  final List<SlotHistoryEntry> history;
  final SelectionWindow selectionWindow;

  const DeliverySlotState({
    this.slots = const [],
    this.isLoading = false,
    this.error,
    this.alreadyConfirmed = false,
    this.previousSelection = const [],
    this.availableMeals = const [],
    this.isWithinWindow = false,
    this.deliveryDate = '',
    this.history = const [],
    this.selectionWindow = const SelectionWindow(start: '18:00', end: '23:59'),
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
    List<SlotHistoryEntry>? history,
    SelectionWindow? selectionWindow,
  }) {
    return DeliverySlotState(
      slots: slots ?? this.slots,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      alreadyConfirmed: alreadyConfirmed ?? this.alreadyConfirmed,
      previousSelection: previousSelection ?? this.previousSelection,
      availableMeals: availableMeals ?? this.availableMeals,
      isWithinWindow: isWithinWindow ?? this.isWithinWindow,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      history: history ?? this.history,
      selectionWindow: selectionWindow ?? this.selectionWindow,
    );
  }
}

class DeliverySlotNotifier extends StateNotifier<DeliverySlotState> {
  final Ref _ref;

  DeliverySlotNotifier(this._ref) : super(const DeliverySlotState());

  /// Load delivery slots for tomorrow (the standard target delivery date)
  Future<void> loadDeliverySlots() async {
    if (state.isLoading) return;
    debugPrint('[DeliverySlotNotifier] Loading delivery slots...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repository = _ref.read(deliverySlotRepositoryProvider);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final date =
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

      final response =
          await repository.getDeliverySlotsWithSelections(date: date);

      if (response.success && response.data != null) {
        final data = response.data!;
        final sortedSlots = List<DeliverySlotApiModel>.from(data.slots)
          ..sort((a, b) =>
              _parseHour(a.slotStartTime).compareTo(_parseHour(b.slotStartTime)));

        state = DeliverySlotState(
          slots: sortedSlots,
          isLoading: false,
          alreadyConfirmed: data.alreadyConfirmed,
          previousSelection: data.previousSelection,
          availableMeals: data.availableMeals,
          isWithinWindow: data.isWithinWindow,
          deliveryDate: data.deliveryDate,
          history: data.history,
          selectionWindow: data.selectionWindow,
        );
        debugPrint(
            '[DeliverySlotNotifier] Loaded ${sortedSlots.length} slots. '
            'alreadyConfirmed=${data.alreadyConfirmed} '
            'isWithinWindow=${data.isWithinWindow} '
            'meals=${data.availableMeals.length}');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty
              ? response.message
              : 'Failed to load delivery slots',
        );
      }
    } catch (e) {
      debugPrint('[DeliverySlotNotifier] Error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load delivery slots. Please try again.',
      );
    }
  }

  Future<void> refresh() => loadDeliverySlots();

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
}

final deliverySlotApiProvider =
    StateNotifierProvider<DeliverySlotNotifier, DeliverySlotState>((ref) {
  return DeliverySlotNotifier(ref);
});
