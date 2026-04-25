import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/meal_plan_model.dart';

class MealPlanState {
  final MealPlan? mealPlan;
  final bool isLoading;
  final String? error;

  const MealPlanState({
    this.mealPlan,
    this.isLoading = false,
    this.error,
  });

  MealPlanState copyWith({
    MealPlan? mealPlan,
    bool? isLoading,
    String? error,
  }) {
    return MealPlanState(
      mealPlan: mealPlan ?? this.mealPlan,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MealPlanNotifier extends StateNotifier<MealPlanState> {
  final Ref _ref;

  MealPlanNotifier(this._ref) : super(const MealPlanState());

  Future<void> loadMealPlan() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repository = _ref.read(mealPlanRepositoryProvider);
      final response = await repository.getMealPlanDetails();

      if (response.success && response.mealPlan != null) {
        state = state.copyWith(
          mealPlan: response.mealPlan,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty
              ? response.message
              : 'Failed to load meal plan',
        );
      }
    } catch (e) {
      debugPrint('[MealPlanNotifier] Error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load meal plan. Please try again.',
      );
    }
  }

  Future<void> refresh() => loadMealPlan();
}

final mealPlanProvider =
    StateNotifierProvider<MealPlanNotifier, MealPlanState>((ref) {
  return MealPlanNotifier(ref);
});
