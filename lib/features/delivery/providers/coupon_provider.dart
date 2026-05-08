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

  Future<void> loadCoupons() async {
    if (state.isLoading) return;
    debugPrint('[CouponNotifier] Loading eligible coupons...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.fetchEligibleCoupons();
      if (response.success) {
        state = CouponState(coupons: response.coupons, isLoading: false);
        debugPrint('[CouponNotifier] Loaded ${response.coupons.length} coupons');
      } else {
        state = CouponState(
          isLoading: false,
          error: response.message.isNotEmpty ? response.message : 'Failed to load coupons',
        );
      }
    } catch (e) {
      debugPrint('[CouponNotifier] Error: $e');
      state = CouponState(isLoading: false, error: 'Failed to load coupons');
    }
  }
}

final couponProvider = StateNotifierProvider<CouponNotifier, CouponState>((ref) {
  return CouponNotifier(ref.watch(couponRepositoryProvider));
});
