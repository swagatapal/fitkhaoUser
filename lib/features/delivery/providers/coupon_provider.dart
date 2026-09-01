import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/coupon_model.dart';
import '../repository/coupon_repository.dart';

class CouponState {
  final List<CouponModel> coupons;
  final bool isLoading;
  final String? error;

  const CouponState({
    this.coupons = const [],
    this.isLoading = false,
    this.error,
  });

  CouponState copyWith({
    List<CouponModel>? coupons,
    bool? isLoading,
    String? error,
  }) {
    return CouponState(
      coupons: coupons ?? this.coupons,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CouponNotifier extends StateNotifier<CouponState> {
  final CouponRepository _repository;

  CouponNotifier(this._repository) : super(const CouponState());

  /// Loads the eligible coupons, optionally narrowed to a comma-separated set
  /// of [ruleTypes] (e.g. `outlet`). Empty fetches every eligible coupon.
  Future<void> loadCoupons({String ruleTypes = ''}) async {
    if (state.isLoading) return;
    debugPrint('[CouponNotifier] Loading eligible coupons '
        '(ruleTypes=${ruleTypes.isEmpty ? 'all' : ruleTypes})...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response =
          await _repository.fetchEligibleCoupons(ruleTypes: ruleTypes);
      if (response.success) {
        state = CouponState(coupons: response.coupons, isLoading: false);
        debugPrint(
            '[CouponNotifier] Loaded ${response.coupons.length} coupons');
      } else {
        state = CouponState(
          isLoading: false,
          error: response.message.isNotEmpty
              ? response.message
              : 'Failed to load coupons',
        );
      }
    } catch (e) {
      debugPrint('[CouponNotifier] Error: $e');
      state = CouponState(isLoading: false, error: 'Failed to load coupons');
    }
  }
}

final couponProvider =
    StateNotifierProvider<CouponNotifier, CouponState>((ref) {
  return CouponNotifier(ref.watch(couponRepositoryProvider));
});

/// Eligible coupons for a single rule type (e.g. `subscription`).
///
/// Kept separate from [couponProvider] — which the food checkout owns — so the
/// two screens never overwrite each other's list. Auto-disposed and keyed by
/// the rule type, so opening the sheet refetches and closing it discards.
final eligibleCouponsProvider =
    FutureProvider.autoDispose.family<List<CouponModel>, String>(
  (ref, ruleTypes) async {
    final repo = ref.watch(couponRepositoryProvider);
    final res = await repo.fetchEligibleCoupons(ruleTypes: ruleTypes);
    if (!res.success) {
      throw Exception(res.message.isNotEmpty
          ? res.message
          : 'Could not load coupons. Please try again.');
    }
    return res.coupons;
  },
);
