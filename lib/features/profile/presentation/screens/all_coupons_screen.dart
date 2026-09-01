import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../delivery/models/coupon_model.dart';
import '../../../delivery/providers/coupon_provider.dart';

/// Dark status-bar icons so the system bar stays visible over the white header.
const SystemUiOverlayStyle _kHeaderOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark, // Android
  statusBarBrightness: Brightness.light, // iOS
);

/// Every coupon the user is currently eligible for.
///
/// Read-only: coupons are redeemed at their own checkout (outlet coupons in the
/// cart, subscription coupons on the plan checkout), so this screen only lists
/// them and lets the user copy a code. It reuses [eligibleCouponsProvider] with
/// an empty rule type, which omits `?ruleTypes=` and returns the full set.
class AllCouponsScreen extends ConsumerWidget {
  const AllCouponsScreen({super.key});

  /// Empty filter — `GET /api/user/coupons` with no rule-type narrowing.
  static const String _allRuleTypes = '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(eligibleCouponsProvider(_allRuleTypes));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _kHeaderOverlay,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F4),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primaryGreen,
                  onRefresh: () async {
                    ref.invalidate(eligibleCouponsProvider(_allRuleTypes));
                    // Wait for the refetch so the spinner reflects real work.
                    await ref.read(
                      eligibleCouponsProvider(_allRuleTypes).future,
                    );
                  },
                  child: couponsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    error: (_, __) => _MessageView(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load coupons',
                      message: 'Please check your connection and try again.',
                      onRetry: () => ref.invalidate(
                        eligibleCouponsProvider(_allRuleTypes),
                      ),
                    ),
                    data: (coupons) => _buildList(context, coupons),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<CouponModel> coupons) {
    if (coupons.isEmpty) {
      return const _MessageView(
        icon: Icons.confirmation_number_outlined,
        title: 'No coupons yet',
        message:
            'Offers you can use will show up here. Check back after your next '
            'order.',
      );
    }

    return ListView.separated(
      // AlwaysScrollable so pull-to-refresh works even on a short list.
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing16,
        AppSizes.spacing16,
        AppSizes.spacing16,
        AppSizes.spacing24,
      ),
      itemCount: coupons.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing12),
      itemBuilder: (_, i) => _CouponCard(coupon: coupons[i]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p20,
        vertical: AppSizes.spacing8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: AppSizes.shadowBlur10,
            offset: const Offset(0, AppSizes.spacing2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.spacing8),
              decoration: BoxDecoration(
                color: AppColors.darkGreen,
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.textWhite,
                size: AppSizes.icon24,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Coupons',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                Text(
                  'Offers available on your account',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty / error state ─────────────────────────────────────────────────────

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // A scroll view so pull-to-refresh still works on these states.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Padding(
          padding: const EdgeInsets.all(AppSizes.spacing24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    size: AppSizes.icon48, color: AppColors.primaryGreen),
              ),
              const SizedBox(height: AppSizes.spacing16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize18,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontFamily: 'Lato',
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSizes.spacing20),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing24,
                      vertical: AppSizes.spacing12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontWeight: AppTypography.semiBold,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Coupon card ─────────────────────────────────────────────────────────────

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});

  final CouponModel coupon;

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: coupon.code));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${coupon.code} copied',
            style: const TextStyle(fontFamily: 'Lato'),
          ),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Promotional banner when the coupon carries one.
          if (coupon.hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSizes.radius16),
              ),
              child: Image.network(
                coupon.couponImage!,
                width: double.infinity,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 110,
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
            padding: const EdgeInsets.all(AppSizes.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Discount + name.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.spacing10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radius12),
                      ),
                      child: const Icon(Icons.local_offer_rounded,
                          size: AppSizes.icon20,
                          color: AppColors.primaryGreen),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
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
                              fontSize: AppTypography.fontSize14,
                              fontWeight: AppTypography.bold,
                              color: AppColors.primaryGreen,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (coupon.description.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.spacing12),
                  Text(
                    coupon.description,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                      fontFamily: 'Lato',
                    ),
                  ),
                ],

                if (coupon.remarks.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.spacing6),
                  Text(
                    coupon.remarks,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textTertiary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ],

                // Where it applies + how it was issued.
                const SizedBox(height: AppSizes.spacing12),
                Wrap(
                  spacing: AppSizes.spacing8,
                  runSpacing: AppSizes.spacing8,
                  children: [
                    _Tag(
                      icon: Icons.sell_outlined,
                      label: coupon.ruleTypeLabel,
                    ),
                    if (coupon.minOrderAmount > 0)
                      _Tag(
                        icon: Icons.shopping_bag_outlined,
                        label:
                            'Min ₹${coupon.minOrderAmount.toStringAsFixed(0)}',
                      ),
                    if (coupon.isSystemGenerated)
                      const _Tag(
                        icon: Icons.auto_awesome_outlined,
                        label: 'Auto-issued',
                      ),
                  ],
                ),

                // Code + copy action.
                const SizedBox(height: AppSizes.spacing12),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: AppSizes.spacing12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.spacing12,
                          vertical: AppSizes.spacing8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primaryGreen.withValues(alpha: 0.06),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radius8),
                          border: Border.all(
                            color: AppColors.primaryGreen
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          coupon.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.bold,
                            color: AppColors.primaryGreen,
                            letterSpacing: 0.8,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing8),
                    TextButton.icon(
                      onPressed: () => _copyCode(context),
                      icon: const Icon(Icons.copy_rounded,
                          size: AppSizes.icon16),
                      label: const Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize13,
                          fontWeight: AppTypography.semiBold,
                          fontFamily: 'Lato',
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.spacing12,
                        ),
                      ),
                    ),
                  ],
                ),

                if (coupon.formattedExpiry.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.spacing8),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: AppSizes.icon14,
                          color: AppColors.textTertiary),
                      const SizedBox(width: AppSizes.spacing4),
                      Text(
                        'Valid till ${coupon.formattedExpiry}',
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize12,
                          color: AppColors.textTertiary,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill used for the rule type / minimum order / origin badges.
class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F4),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.icon12, color: AppColors.textSecondary),
          const SizedBox(width: AppSizes.spacing4),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTypography.fontSize12,
              fontWeight: AppTypography.medium,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }
}
