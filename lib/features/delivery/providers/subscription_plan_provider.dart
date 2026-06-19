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
        // Sort by plan amount, cheapest first, so the list reads low → high.
        final plans = [...response.data!.plans]
          ..sort((a, b) => a.price.compareTo(b.price));
        state = state.copyWith(
          plans: plans,
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

/// The id of the plan the user has currently selected on the plan screen.
///
/// Kept separate from [subscriptionPlanProvider] so that changing the selection
/// only rebuilds the two affected plan cards (the one losing and the one
/// gaining selection) plus the bottom CTA — never the wallet or the whole list.
final selectedSubscriptionPlanProvider = StateProvider<String?>((ref) => null);

/// Per-plan "cancel anytime" opt-in toggle (keyed by plan id).
///
/// Family-scoped so each plan card owns its own switch state and toggling one
/// rebuilds only that switch — never the card or the list. The value flows into
/// the checkout's pricing-preview request.
final cancelAnytimeProvider =
    StateProvider.family<bool, String>((ref, planId) => false);