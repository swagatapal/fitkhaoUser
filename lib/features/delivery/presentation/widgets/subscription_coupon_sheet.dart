import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/coupon_model.dart';
import '../../providers/coupon_provider.dart';

/// What the user did in [SubscriptionCouponSheet].
///
/// Distinguishes "cleared the coupon" (a result carrying a null [coupon]) from
/// "dismissed the sheet without changing anything" (a null result), which a
/// bare `CouponModel?` could not express.
class CouponSheetResult {
  /// The chosen coupon, or null when the user removed the applied one.
  final CouponModel? coupon;

  const CouponSheetResult(this.coupon);
}

/// Bottom sheet listing the coupons the user can redeem on a subscription.
///
/// Selection is single-choice — the backend takes an array of rule ids, but the
/// app applies one at a time, matching the food checkout — and the sheet only
/// reports the choice: pricing stays server-authoritative and is recomputed by
/// the caller through the pricing preview.
class SubscriptionCouponSheet extends ConsumerWidget {
  /// Rule type filter passed to `GET /api/user/coupons?ruleTypes=`.
  static const String ruleType = 'subscription_buy';

  /// Rule id of the currently applied coupon, if any.
  final String? appliedCouponId;

  /// Amount a coupon's `minOrderAmount` is checked against.
  final double orderAmount;

  const SubscriptionCouponSheet({
    super.key,
    required this.appliedCouponId,
    required this.orderAmount,
  });

  /// Opens the sheet. Resolves to null when dismissed without a change.
  static Future<CouponSheetResult?> show(
    BuildContext context, {
    required String? appliedCouponId,
    required double orderAmount,
  }) {
    return showModalBottomSheet<CouponSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubscriptionCouponSheet(
        appliedCouponId: appliedCouponId,
        orderAmount: orderAmount,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(eligibleCouponsProvider(ruleType));

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F6F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle.
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.spacing12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spacing20,
              AppSizes.spacing16,
              AppSizes.spacing16,
              AppSizes.spacing4,
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer_outlined,
                    color: AppColors.primaryGreen, size: AppSizes.icon20),
                const SizedBox(width: AppSizes.spacing8),
                const Expanded(
                  child: Text(
                    'Available Coupons',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize18,
                      fontWeight: AppTypography.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
                if (appliedCouponId != null)
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .pop(const CouponSheetResult(null)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.spacing8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize13,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.errorColor,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: couponsAsync.when(
              loading: () => const _SheetMessage.loading(),
              error: (_, __) => _SheetMessage(
                icon: Icons.error_outline,
                text: 'Could not load coupons. Please try again.',
                onRetry: () =>
                    ref.invalidate(eligibleCouponsProvider(ruleType)),
              ),
              data: (coupons) => _buildList(context, coupons),
            ),
          ),

          SizedBox(
            height: MediaQuery.of(context).padding.bottom + AppSizes.spacing8,
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<CouponModel> coupons) {
    if (coupons.isEmpty) {
      return const _SheetMessage(
        icon: Icons.confirmation_number_outlined,
        text: 'No coupons available for subscriptions right now',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      shrinkWrap: true,
      itemCount: coupons.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing12),
      itemBuilder: (_, i) {
        final coupon = coupons[i];
        final eligible =
            coupon.minOrderAmount <= 0 || orderAmount >= coupon.minOrderAmount;
        return _SubscriptionCouponCard(
          coupon: coupon,
          isApplied: coupon.id == appliedCouponId,
          isEligible: eligible,
          orderAmount: orderAmount,
          onApply: eligible
              ? () => Navigator.of(context).pop(CouponSheetResult(coupon))
              : null,
        );
      },
    );
  }
}

// ─── Empty / loading / error body ────────────────────────────────────────────

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    required this.icon,
    required this.text,
    this.onRetry,
  }) : isLoading = false;

  const _SheetMessage.loading()
      : icon = Icons.hourglass_empty,
        text = '',
        onRetry = null,
        isLoading = true;

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSizes.spacing24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.icon48, color: AppColors.textTertiary),
          const SizedBox(height: AppSizes.spacing12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSizes.spacing12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
              ),
              child: const Text('Retry', style: TextStyle(fontFamily: 'Lato')),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Coupon card ─────────────────────────────────────────────────────────────

class _SubscriptionCouponCard extends StatelessWidget {
  const _SubscriptionCouponCard({
    required this.coupon,
    required this.isApplied,
    required this.isEligible,
    required this.orderAmount,
    required this.onApply,
  });

  final CouponModel coupon;
  final bool isApplied;
  final bool isEligible;
  final double orderAmount;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isApplied ? AppColors.primaryGreen : AppColors.borderColor;

    return Opacity(
      opacity: isEligible ? 1 : 0.55,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        child: InkWell(
          onTap: onApply,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radius12),
              border: Border.all(
                color: borderColor,
                width: isApplied ? AppSizes.borderMedium : AppSizes.borderThin,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Promotional banner, when the coupon carries one.
                if (coupon.hasImage)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppSizes.radius12),
                    ),
                    child: Image.network(
                      coupon.couponImage!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 96,
                          color: AppColors.primaryGreen.withValues(alpha: 0.06),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: AppSizes.icon24,
                            height: AppSizes.icon24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(AppSizes.spacing12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  coupon.name.isNotEmpty
                                      ? coupon.name
                                      : coupon.code,
                                  style: const TextStyle(
                                    fontSize: AppTypography.fontSize15,
                                    fontWeight: AppTypography.bold,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  coupon.discountLabel,
                                  style: const TextStyle(
                                    fontSize: AppTypography.fontSize13,
                                    fontWeight: AppTypography.semiBold,
                                    color: AppColors.primaryGreen,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSizes.spacing8),
                          if (isApplied)
                            const Icon(Icons.check_circle,
                                size: AppSizes.icon20,
                                color: AppColors.primaryGreen)
                          else if (isEligible)
                            const Text(
                              'APPLY',
                              style: TextStyle(
                                fontSize: AppTypography.fontSize13,
                                fontWeight: AppTypography.bold,
                                color: AppColors.primaryGreen,
                                fontFamily: 'Lato',
                              ),
                            ),
                        ],
                      ),

                      if (coupon.code.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.spacing8),
                        _CodeChip(code: coupon.code),
                      ],

                      if (coupon.description.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.spacing8),
                        Text(
                          coupon.description,
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ],

                      // Why the coupon can't be used yet.
                      if (!isEligible) ...[
                        const SizedBox(height: AppSizes.spacing8),
                        Text(
                          'Needs a plan of at least '
                          '₹${coupon.minOrderAmount.toInt()} '
                          '(this plan is ₹${orderAmount.toInt()})',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize12,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.errorColor,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ],

                      if (coupon.formattedExpiry.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.spacing6),
                        Text(
                          'Valid till ${coupon.formattedExpiry}',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize10,
                            color: AppColors.textTertiary,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed-look chip showing the coupon code.
class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: AppTypography.fontSize12,
          fontWeight: AppTypography.bold,
          color: AppColors.primaryGreen,
          letterSpacing: 0.6,
          fontFamily: 'Lato',
        ),
      ),
    );
  }
}
