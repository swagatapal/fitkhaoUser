import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/subscription_plan_model.dart';

/// Accent used for "highlight" benefits (discounts, custom perks).
const Color kSubscriptionAccent = Color(0xFFC66301);

/// A single subscription benefit derived from a plan's features/rules.
class SubscriptionBenefit {
  final IconData icon;
  final String label;
  final bool highlight;
  const SubscriptionBenefit(this.icon, this.label, {this.highlight = false});
}

/// Builds the visible benefit list for [plan]: every boolean that is `true`,
/// every count/percent that is non-zero, the enabled rules, and any custom
/// features — the single source of truth shared by the plan card and the
/// checkout "what you'll get" section.
List<SubscriptionBenefit> deriveSubscriptionBenefits(SubscriptionPlan plan) {
  final f = plan.features;
  final r = plan.rules;
  return [
    if (f.mealCountPerDay > 0)
      SubscriptionBenefit(
          Icons.restaurant_rounded, '${f.mealCountPerDay} meals every day'),
    if (plan.hasFreeDelivery)
      const SubscriptionBenefit(
          Icons.local_shipping_rounded, 'Free delivery on every order')
    else
      SubscriptionBenefit(Icons.local_shipping_rounded,
          '₹${_money(plan.effectiveDeliveryCharge)} delivery charge per order'),
    if (f.dietChart)
      const SubscriptionBenefit(
          Icons.menu_book_rounded, 'Personalised diet chart'),
    if (f.consultationCount > 0)
      SubscriptionBenefit(Icons.health_and_safety_rounded,
          '${f.consultationCount} expert consultation${f.consultationCount > 1 ? 's' : ''}'),
    if (f.discountPercent > 0)
      SubscriptionBenefit(
          Icons.local_offer_rounded, '${f.discountPercent}% off on every order',
          highlight: true),
    if (f.snacks)
      const SubscriptionBenefit(
          Icons.bakery_dining_rounded, 'Healthy snacks included'),
    if (f.outletFoodDiscount && f.outletFoodDiscountPercent > 0)
      SubscriptionBenefit(Icons.storefront_rounded,
          '${f.outletFoodDiscountPercent}% off on outlet food'),
    if (f.cancelCoupon && f.cancelCouponAmount > 0)
      SubscriptionBenefit(Icons.confirmation_number_rounded,
          '₹${f.cancelCouponAmount} cancellation credit'),
    if (f.planBasedMealsAssgn)
      const SubscriptionBenefit(
          Icons.event_available_rounded, 'Plan-based meal scheduling'),
    if (r.canSlotChoose)
      const SubscriptionBenefit(
          Icons.schedule_rounded, 'Pick your delivery slots'),
    if (r.canCancel)
      const SubscriptionBenefit(Icons.event_busy_rounded, 'Cancel anytime'),
    if (r.canUpgrade)
      const SubscriptionBenefit(
          Icons.upgrade_rounded, 'Upgrade whenever you want'),
    for (final c in f.customFeatures)
      SubscriptionBenefit(Icons.star_rounded, c, highlight: true),
  ];
}

/// Drops the decimal on whole rupee amounts (10.0 -> "10", 10.5 -> "10.50").
String _money(double amount) =>
    amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);

/// Single benefit row — a tinted check icon + label.
class SubscriptionBenefitRow extends StatelessWidget {
  const SubscriptionBenefitRow({super.key, required this.benefit});

  final SubscriptionBenefit benefit;

  @override
  Widget build(BuildContext context) {
    final color = benefit.highlight ? kSubscriptionAccent : AppColors.primaryGreen;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(benefit.icon, size: 13, color: color),
          ),
          const SizedBox(width: AppSizes.spacing10),
          Expanded(
            child: Text(
              benefit.label,
              style: TextStyle(
                fontSize: AppTypography.fontSize13,
                fontWeight: benefit.highlight
                    ? AppTypography.semiBold
                    : AppTypography.regular,
                color: benefit.highlight
                    ? kSubscriptionAccent
                    : AppColors.textPrimary,
                height: 1.3,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical checklist of every benefit a [plan] includes.
class SubscriptionBenefitsList extends StatelessWidget {
  const SubscriptionBenefitsList({super.key, required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final benefits = deriveSubscriptionBenefits(plan);
    if (benefits.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final b in benefits) SubscriptionBenefitRow(benefit: b),
      ],
    );
  }
}
