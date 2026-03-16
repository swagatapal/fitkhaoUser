import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/subscription_plan_model.dart';
import '../repository/subscription_repository.dart';

/// State for subscription plans
class SubscriptionPlanState {
  final List<SubscriptionPlan> plans;
  final bool isLoading;
  final String? error;

  const SubscriptionPlanState({
    this.plans = const [],
    this.isLoading = false,
    this.error,
  });

  SubscriptionPlanState copyWith({
    List<SubscriptionPlan>? plans,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionPlanState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for subscription plans
class SubscriptionPlanNotifier extends StateNotifier<SubscriptionPlanState> {
  final SubscriptionRepository _repository;

  SubscriptionPlanNotifier(this._repository)
      : super(const SubscriptionPlanState());

  Future<void> loadPlans() async {
    debugPrint('[SubscriptionPlanNotifier] Loading subscription plans...');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repository.getSubscriptionPlans();
      if (response.success && response.data != null) {
        state = state.copyWith(
          plans: response.data!.plans,
          isLoading: false,
        );
        debugPrint(
            '[SubscriptionPlanNotifier] Loaded ${response.data!.plans.length} plans');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty
              ? response.message
              : 'Failed to load subscription plans',
        );
      }
    } catch (e) {
      debugPrint('[SubscriptionPlanNotifier] Error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load subscription plans',
      );
    }
  }
}

/// Provider for subscription plans
final subscriptionPlanProvider =
    StateNotifierProvider<SubscriptionPlanNotifier, SubscriptionPlanState>(
        (ref) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return SubscriptionPlanNotifier(repo);
});
