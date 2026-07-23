import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers/providers.dart';
import '../models/dish_category_model.dart';
import '../models/weekly_delivery_slot_model.dart';

/// The user's saved weekly delivery-slot preference. Awaits local storage so it
/// is safe to watch on the first frame; `invalidate` after a save.
final weeklyDeliverySlotsProvider =
    FutureProvider.autoDispose<WeeklyDeliverySlotsResponse>((ref) async {
  await ref.watch(localStorageProvider.future);
  return ref.read(deliverySlotRepositoryProvider).getWeeklyDeliverySlots();
});

/// Active meal categories (Breakfast/Lunch/…) ordered by their server-side
/// sortOrder — each one gets a delivery-slot choice in the plan manager.
final dishCategoriesProvider =
    FutureProvider.autoDispose<List<DishCategory>>((ref) async {
  await ref.watch(localStorageProvider.future);
  final res =
      await ref.read(deliverySlotRepositoryProvider).getDishCategories();
  final list = res.categories
      .where((c) => c.isActive && c.id.isNotEmpty)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return list;
});

class WeeklySlotsSubmitState {
  final bool isSubmitting;
  final String? error;

  const WeeklySlotsSubmitState({this.isSubmitting = false, this.error});
}

class WeeklySlotsSubmitNotifier extends StateNotifier<WeeklySlotsSubmitState> {
  WeeklySlotsSubmitNotifier(this._ref) : super(const WeeklySlotsSubmitState());

  final Ref _ref;

  /// Saves the weekly preference. [days] is the `weeklyDeliverySlots` payload;
  /// [isUpdate] chooses PUT over POST. Refreshes the fetch on success.
  Future<bool> submit({
    required List<Map<String, dynamic>> days,
    required bool isUpdate,
  }) async {
    if (state.isSubmitting) return false;
    state = const WeeklySlotsSubmitState(isSubmitting: true);
    try {
      final res = await _ref
          .read(deliverySlotRepositoryProvider)
          .saveWeeklyDeliverySlots(days: days, isUpdate: isUpdate);
      if (res.success) {
        _ref.invalidate(weeklyDeliverySlotsProvider);
        state = const WeeklySlotsSubmitState();
        return true;
      }
      state = WeeklySlotsSubmitState(
        error: res.message.isNotEmpty
            ? res.message
            : 'Could not save your delivery plan. Please try again.',
      );
      return false;
    } on AppException catch (e) {
      state = WeeklySlotsSubmitState(error: e.message);
      return false;
    } catch (_) {
      state = const WeeklySlotsSubmitState(
          error: 'Could not save your delivery plan. Please try again.');
      return false;
    }
  }
}

final weeklySlotsSubmitProvider = StateNotifierProvider.autoDispose<
    WeeklySlotsSubmitNotifier,
    WeeklySlotsSubmitState>((ref) => WeeklySlotsSubmitNotifier(ref));
