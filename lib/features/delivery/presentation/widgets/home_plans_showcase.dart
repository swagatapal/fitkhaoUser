import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/utils/time_converter.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../shared/animation/anime_entrance.dart';
import '../../models/subscription_plan_model.dart';
import '../../models/wallet_balance_model.dart';
import '../../providers/subscription_plan_provider.dart';
import '../screens/my_subscription_screen.dart';
import '../screens/subscription_plan_screen.dart';
import 'subscription_benefits.dart';

/// "FitKhao Plus" plans section at the top of the home (Order Food) screen.
///
/// Every plan is laid out at once so they can be compared at a glance:
/// • the recommended plan as a full-width hero card, then
/// • all other plans in a two-column grid (cards in a row share one height).
/// Each card shows its length, price, an approximate per-meal price, meals per
/// day and its top features with their own icons. Tapping a card opens the
/// plan screen scrolled to that plan (guests sign in first via
/// [openSubscriptionPlans]).
///
/// Never blocks the menu: while loading it shows placeholders in the same
/// shape, and on an error or an empty catalogue it collapses to nothing.
class HomePlansShowcase extends ConsumerWidget {
  const HomePlansShowcase({
    super.key,
    this.title = 'FitKhao Plus',
    this.subtitle = 'Planned, calorie-counted meals for your goal',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionPlanProvider);

    final loading = state.isLoading && state.plans.isEmpty;
    if (!loading && state.plans.isEmpty) return const SizedBox.shrink();

    // Recommended plan leads as the hero; the rest keep the provider's
    // cheapest → dearest order in the grid.
    SubscriptionPlan? featured;
    for (final p in state.plans) {
      if (p.features.suggestedPlan) {
        featured = p;
        break;
      }
    }
    final gridPlans =
        state.plans.where((p) => !identical(p, featured)).toList();

    // "Best value" = lowest price per meal, flagged only when there is more
    // than one plan to compare and it isn't already the featured pick.
    String? bestValueId;
    double? bestPerMeal;
    var comparable = 0;
    for (final p in state.plans) {
      final pm = _perMeal(p);
      if (pm == null) continue;
      comparable++;
      if (bestPerMeal == null || pm < bestPerMeal) {
        bestPerMeal = pm;
        bestValueId = p.id;
      }
    }
    if (comparable < 2 || bestValueId == featured?.id) bestValueId = null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing8,
        AppSizes.screenPaddingHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: title,
            subtitle: subtitle,
            planCount: state.plans.length,
          ),
          const SizedBox(height: AppSizes.spacing12),
          if (loading) ...[
            const _SkeletonBox(height: 170),
            const SizedBox(height: AppSizes.spacing12),
            const _GridRows(children: [
              _SkeletonBox(height: 230),
              _SkeletonBox(height: 230),
            ]),
          ] else ...[
            if (featured != null) ...[
              AnimEntrance(
                delay: AnimEntrance.stagger(0),
                child: _FeaturedPlanCard(plan: featured),
              ),
              if (gridPlans.isNotEmpty)
                const SizedBox(height: AppSizes.spacing12),
            ],
            _GridRows(
              children: [
                for (var i = 0; i < gridPlans.length; i++)
                  AnimEntrance(
                    delay: AnimEntrance.stagger(i + 1),
                    child: _GridPlanCard(
                      plan: gridPlans[i],
                      accent: _tierAccent(i),
                      isBestValue: gridPlans[i].id == bestValueId,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section header ──────────────────────────────────────────────────────────

/// Plain section heading — same look as "Order from our kitchen" — with the
/// subtitle under it and a "Compare" link to the full plan screen.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.planCount,
  });

  final String title;
  final String subtitle;
  final int planCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      size: AppSizes.icon20, color: AppColors.primaryGreen),
                  const SizedBox(width: AppSizes.spacing6),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize18,
                        fontWeight: AppTypography.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => openSubscriptionPlans(context),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryGreen,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing8),
            minimumSize: const Size(0, 32),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                planCount > 1 ? 'Compare' : 'Details',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize13,
                  fontWeight: AppTypography.bold,
                  fontFamily: 'Lato',
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shared bits ─────────────────────────────────────────────────────────────

/// "₹29,992" — Indian digit grouping.
final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');
String _rupees(double v) => '₹${_inr.format(v.round())}';

/// Display-only "was" price for the Pujo offer: the real price + 40%, shown
/// struck through. The plan's real [SubscriptionPlan.price] is what's charged.
/// shortcut: hard-coded seasonal markup, move to the plans API / remote config
/// if offers become a regular thing.
double pujoMrp(double price) => price * 1.4;

/// "🪔 PUJO SPECIAL OFFER" tag on the home plan cards.
class PujoOfferTag extends StatelessWidget {
  const PujoOfferTag({super.key, required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: onDark
            ? null
            : const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFFF8F00)],
              ),
        color: onDark ? const Color(0xFFFFE082) : null,
        borderRadius: BorderRadius.circular(AppSizes.radius20),
      ),
      child: Text(
        '🪔 PUJO SPECIAL OFFER',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: AppTypography.extraBold,
          letterSpacing: 0.4,
          color: onDark ? const Color(0xFFB71C1C) : Colors.white,
          fontFamily: 'Lato',
        ),
      ),
    );
  }
}

/// Rough per-meal price for comparing plans. Null when the plan doesn't state
/// its meals per day.
double? _perMeal(SubscriptionPlan plan) {
  final meals = plan.durationInDays * plan.features.mealCountPerDay;
  if (plan.price <= 0 || meals <= 0) return null;
  return plan.price / meals;
}

/// Plan length as a short badge: "1 DAY", "3 DAYS", "1 MONTH", "3 MONTHS".
String _lengthBadge(SubscriptionPlan plan) {
  final d = plan.durationInDays;
  if (d >= 28 && d % 30 <= 2) {
    final m = (d / 30).round();
    return m == 1 ? '1 MONTH' : '$m MONTHS';
  }
  return d == 1 ? '1 DAY' : '$d DAYS';
}

void _openPlan(BuildContext context, SubscriptionPlan plan) =>
    openSubscriptionPlans(context, scrollToPlanId: plan.id);

/// Accent per grid position so neighbouring plans read as distinct tiers.
const List<Color> _kTierAccents = [
  AppColors.primaryGreen,
  Color(0xFF0E9F8A), // teal
  Color(0xFF3F6FD8), // blue
  Color(0xFF8B5CF6), // purple
  kSubscriptionAccent, // orange
];
Color _tierAccent(int index) => _kTierAccents[index % _kTierAccents.length];

/// Lays [children] out two per row; the cards in a row share one height (the
/// taller card's), so the grid reads as even rows whatever each plan lists.
class _GridRows extends StatelessWidget {
  const _GridRows({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final hasPair = i + 1 < children.length;
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: AppSizes.spacing12),
            // An odd last plan keeps half width so every card is one size.
            Expanded(child: hasPair ? children[i + 1] : const SizedBox()),
          ],
        ),
      ));
      if (i + 2 < children.length) {
        rows.add(const SizedBox(height: AppSizes.spacing12));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.benefit,
    required this.color,
    required this.textColor,
  });

  final SubscriptionBenefit benefit;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(benefit.icon, size: 11, color: color),
          ),
          const SizedBox(width: AppSizes.spacing6),
          Expanded(
            child: Text(
              benefit.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: textColor,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaPill extends StatelessWidget {
  const _CtaPill({required this.onDark, this.color = AppColors.primaryGreen});

  final bool onDark;

  /// Fill colour on a light card.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? AppColors.darkGreen : Colors.white;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : color,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'View plan',
            style: TextStyle(
              fontSize: AppTypography.fontSize13,
              fontWeight: AppTypography.bold,
              color: fg,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 16, color: fg),
        ],
      ),
    );
  }
}

// ─── Featured (recommended) plan — full width ────────────────────────────────

class _FeaturedPlanCard extends StatelessWidget {
  const _FeaturedPlanCard({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final perMeal = _perMeal(plan);
    final meals = plan.features.mealCountPerDay;
    final benefits = deriveSubscriptionBenefits(plan).take(4).toList();
    final white = Colors.white;
    final soft = Colors.white.withValues(alpha: 0.85);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        onTap: () => _openPlan(context, plan),
        child: Ink(
          padding: const EdgeInsets.all(AppSizes.spacing16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.darkGreen, AppColors.primaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radius16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Soft decorative glow circles behind the content.
              // Flush with the card edges (= -padding) so they never spill
              // past its rounded corners.
              const Positioned(top: -16, right: -16, child: _Glow(size: 110)),
              const Positioned(bottom: -16, left: -16, child: _Glow(size: 70)),
              Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _Badge(),
                  const Spacer(),
                  _LengthChip(label: _lengthBadge(plan), onDark: true),
                ],
              ),
              const SizedBox(height: AppSizes.spacing10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.planName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTypography.fontSize20,
                            fontWeight: AppTypography.bold,
                            color: white,
                            fontFamily: 'Lato',
                          ),
                        ),
                        if (meals > 0)
                          Text(
                            '$meals meals a day',
                            style: TextStyle(
                              fontSize: AppTypography.fontSize12,
                              color: soft,
                              fontFamily: 'Lato',
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const PujoOfferTag(onDark: true),
                      const SizedBox(height: 4),
                      Text(
                        _rupees(pujoMrp(plan.price)),
                        style: TextStyle(
                          fontSize: AppTypography.fontSize13,
                          color: soft,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: soft,
                          fontFamily: 'Lato',
                        ),
                      ),
                      Text(
                        _rupees(plan.price),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: AppTypography.extraBold,
                          color: white,
                          fontFamily: 'Lato',
                        ),
                      ),
                      if (perMeal != null)
                        Text(
                          '≈ ${_rupees(perMeal)} per meal',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize12,
                            fontWeight: AppTypography.semiBold,
                            color: soft,
                            fontFamily: 'Lato',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (benefits.isNotEmpty) ...[
                const SizedBox(height: AppSizes.spacing12),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: AppSizes.spacing12),
                // Features in two columns to keep the hero compact.
                _GridRows(children: [
                  for (final b in benefits)
                    _FeatureLine(benefit: b, color: white, textColor: white),
                ]),
              ],
              const SizedBox(height: AppSizes.spacing8),
              const _CtaPill(onDark: true),
            ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}

// ─── Grid plan card ──────────────────────────────────────────────────────────

class _GridPlanCard extends StatelessWidget {
  const _GridPlanCard({
    required this.plan,
    required this.accent,
    this.isBestValue = false,
  });

  final SubscriptionPlan plan;

  /// Tier colour: top band, length chip, price, feature icons and CTA.
  final Color accent;

  /// Lowest price per meal among the plans → "BEST VALUE" ribbon.
  final bool isBestValue;

  @override
  Widget build(BuildContext context) {
    final perMeal = _perMeal(plan);
    final meals = plan.features.mealCountPerDay;
    final benefits = deriveSubscriptionBenefits(plan).take(3).toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        onTap: () => _openPlan(context, plan),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius16),
            border: Border.all(
              color: isBestValue
                  ? kSubscriptionAccent.withValues(alpha: 0.6)
                  : accent.withValues(alpha: 0.25),
              width: isBestValue ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radius16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tier colour band ──
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.55)],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.spacing12,
                      AppSizes.spacing10,
                      AppSizes.spacing12,
                      AppSizes.spacing12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Wrap (not Row) so the two badges drop onto a second
                        // line on narrow cards instead of overflowing. A
                        // Spacer can't live in a Wrap — spaceBetween pushes
                        // them to opposite edges when they share a line.
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSizes.spacing6,
                          runSpacing: AppSizes.spacing6,
                          children: [
                            _LengthChip(
                              label: _lengthBadge(plan),
                              onDark: false,
                              color: accent,
                            ),
                            if (isBestValue) const _BestValueTag(),
                          ],
                        ),
                        const SizedBox(height: AppSizes.spacing8),
                        Text(
                          plan.planName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize15,
                            fontWeight: AppTypography.bold,
                            color: AppColors.textPrimary,
                            height: 1.2,
                            fontFamily: 'Lato',
                          ),
                        ),
                        const SizedBox(height: AppSizes.spacing6),
                        const PujoOfferTag(onDark: false),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _rupees(plan.price),
                                style: TextStyle(
                                  fontSize: AppTypography.fontSize22,
                                  fontWeight: AppTypography.extraBold,
                                  color: accent,
                                  fontFamily: 'Lato',
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _rupees(pujoMrp(plan.price)),
                                style: const TextStyle(
                                  fontSize: AppTypography.fontSize12,
                                  color: AppColors.textTertiary,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: AppColors.textTertiary,
                                  fontFamily: 'Lato',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          [
                            if (perMeal != null) '≈ ${_rupees(perMeal)}/meal',
                            if (meals > 0) '$meals meals/day',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.textSecondary,
                            fontFamily: 'Lato',
                          ),
                        ),
                        if (benefits.isNotEmpty) ...[
                          const SizedBox(height: AppSizes.spacing8),
                          Divider(
                              height: 1,
                              color:
                                  AppColors.borderColor.withValues(alpha: 0.6)),
                          const SizedBox(height: AppSizes.spacing8),
                          for (final b in benefits)
                            _FeatureLine(
                              benefit: b,
                              color: b.highlight ? kSubscriptionAccent : accent,
                              textColor: AppColors.textPrimary,
                            ),
                        ],
                        const Spacer(),
                        const SizedBox(height: AppSizes.spacing6),
                        _CtaPill(onDark: false, color: accent),
                      ],
                    ),
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

class _BestValueTag extends StatelessWidget {
  const _BestValueTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kSubscriptionAccent, Color(0xFFE58A2B)],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 11, color: Colors.white),
          SizedBox(width: 2),
          Text(
            'BEST VALUE',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: AppTypography.bold,
              letterSpacing: 0.4,
              color: Colors.white,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }
}

class _LengthChip extends StatelessWidget {
  const _LengthChip({
    required this.label,
    required this.onDark,
    this.color = AppColors.darkGreen,
  });

  final String label;
  final bool onDark;

  /// Tint on a light card.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: AppTypography.bold,
          letterSpacing: 0.5,
          color: onDark ? Colors.white : color,
          fontFamily: 'Lato',
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12, color: kSubscriptionAccent),
          SizedBox(width: 2),
          Text(
            'BEST PICK',
            style: TextStyle(
              fontSize: 9,
              fontWeight: AppTypography.bold,
              color: kSubscriptionAccent,
              letterSpacing: 0.4,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
      ),
    );
  }
}

// ─── Home plan section (picks the right variant per user) ────────────────────

enum _PlanSectionMode { guest, member, renew, prospect }

/// Top section of the home (Order Food) screen — the subscription half of the
/// "plans + outlet food" home. Chooses what to show from who is looking:
///
/// • guest    → generic plans grid.
/// • prospect → signed in, no plan: plans grid personalised to the user's
///              goal and calorie target, plus a "Why Plus" perks strip.
/// • renew    → plan ended but still inside its grace period: a renew card
///              (with the renewal discount) above the plans.
/// • member   → active plan: a compact "Your plan" card (days left, outlet
///              perk, Renew when the window is open) instead of selling plans.
///
/// The variants cross-fade and resize smoothly, so the profile arriving after
/// the menu (and flipping guest-ish → member) never makes the page jump.
class HomePlanSection extends ConsumerWidget {
  const HomePlanSection({super.key, this.onOpenMySubscription});

  /// Switches the home shell to the My Subscription tab, when hosted in it.
  final VoidCallback? onOpenMySubscription;

  static String _goalLabel(String code) {
    switch (code) {
      case 'fat-loss':
        return 'fat-loss';
      case 'lean-mass-gain':
        return 'muscle-gain';
      default:
        return 'fitness';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    // Live plan, or — when activeSubscription is null — the profile's
    // lastExpiredSubscription (drives the renew card in its grace period).
    final sub = ref.watch(authProvider.select((s) => s.renewalSubscription));
    final plans = ref.watch(subscriptionPlanProvider.select((s) => s.plans));

    // The plan the user had / has, when it is in the catalogue.
    SubscriptionPlan? ownPlan;
    if (sub != null) {
      for (final p in plans) {
        if (p.planCode == sub.planCode) {
          ownPlan = p;
          break;
        }
      }
    }

    final _PlanSectionMode mode;
    if (!signedIn) {
      mode = _PlanSectionMode.guest;
    } else if (sub != null && sub.isActive) {
      mode = _PlanSectionMode.member;
    } else if (sub != null &&
        ownPlan != null &&
        sub.canRenewNow(fallbackGraceDays: ownPlan.gracePeriodDays)) {
      mode = _PlanSectionMode.renew;
    } else {
      mode = _PlanSectionMode.prospect;
    }

    final Widget child;
    switch (mode) {
      case _PlanSectionMode.guest:
        child = const HomePlansShowcase();
      case _PlanSectionMode.member:
        child = _MemberPlanCard(
          sub: sub!,
          plan: ownPlan,
          onOpen: onOpenMySubscription,
        );
      case _PlanSectionMode.renew:
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RenewPlanCard(sub: sub!, plan: ownPlan!),
            const HomePlansShowcase(
              title: 'Or pick a new plan',
              subtitle: 'Planned, calorie-counted meals for your goal',
            ),
          ],
        );
      case _PlanSectionMode.prospect:
        final goal = ref.watch(authProvider.select((s) => s.selectedGoal));
        final kcal = ref.watch(authProvider.select((s) => s.targetKCalories));
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomePlansShowcase(
              title: 'Eat right every day',
              subtitle: [
                'Plans for your ${_goalLabel(goal)} goal',
                if (kcal != null && kcal > 0)
                  '${kcal.toStringAsFixed(0)} kcal/day',
              ].join(' · '),
            ),
            const _PlusPerksStrip(),
          ],
        );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(mode), child: child),
      ),
    );
  }
}

// ─── "Why Plus" perks strip ──────────────────────────────────────────────────

/// One-line reasons to subscribe, derived from the live plan catalogue (only
/// perks some plan actually offers are listed).
class _PlusPerksStrip extends ConsumerWidget {
  const _PlusPerksStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(subscriptionPlanProvider.select((s) => s.plans));
    if (plans.isEmpty) return const SizedBox.shrink();

    final maxOutletOff = plans.fold<int>(
        0,
        (m, p) => p.features.outletFoodDiscount &&
                p.features.outletFoodDiscountPercent > m
            ? p.features.outletFoodDiscountPercent
            : m);
    final perks = <(IconData, String)>[
      if (maxOutletOff > 0)
        (Icons.local_offer_rounded, 'Up to $maxOutletOff% off outlet food'),
      if (plans.any((p) => p.hasFreeDelivery))
        (Icons.delivery_dining_rounded, 'Free delivery'),
      if (plans.any((p) => p.features.dietChart))
        (Icons.assignment_rounded, 'Personal diet chart'),
      if (plans.any((p) => p.features.consultationCount > 0))
        (Icons.support_agent_rounded, 'Nutritionist consult'),
    ];
    if (perks.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing8,
          AppSizes.screenPaddingHorizontal,
          0,
        ),
        itemCount: perks.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.spacing8),
        itemBuilder: (_, i) {
          final (icon, label) = perks[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radius20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: AppColors.primaryGreen),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.darkGreen,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Member: "Your plan" card ────────────────────────────────────────────────

class _MemberPlanCard extends ConsumerWidget {
  const _MemberPlanCard({required this.sub, this.plan, this.onOpen});

  final SubscriptionInfo sub;
  final SubscriptionPlan? plan;
  final VoidCallback? onOpen;

  void _open(BuildContext context) {
    if (onOpen != null) {
      onOpen!();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MySubscriptionScreen(
        planName: sub.planName,
        subscriptionId: sub.id,
      ),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outletOff = sub.outletFoodDiscountPercent;
    final days = sub.remainingDays;
    final canRenew = plan != null &&
        sub.canRenewNow(fallbackGraceDays: plan!.gracePeriodDays);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing8,
        AppSizes.screenPaddingHorizontal,
        0,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radius16),
          onTap: () => _open(context),
          child: Ink(
            padding: const EdgeInsets.all(AppSizes.spacing16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.darkGreen, AppColors.primaryGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSizes.radius16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: Colors.white, size: AppSizes.icon20),
                    const SizedBox(width: AppSizes.spacing8),
                    Expanded(
                      child: Text(
                        sub.planName.isEmpty ? 'Your plan' : sub.planName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize16,
                          fontWeight: AppTypography.bold,
                          color: Colors.white,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ),
                    Text(
                      days == 1 ? '1 day left' : '$days days left',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.semiBold,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing8),
                Text(
                  [
                    if (sub.mealsPerDay > 0) '${sub.mealsPerDay} meals/day',
                    if (outletOff > 0) '$outletOff% off outlet orders',
                    if (sub.mealsPerDay <= 0 && outletOff <= 0)
                      'See today’s meals and your diet chart',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing12),
                Row(
                  children: [
                    Expanded(
                      child: _PillButton(
                        label: 'My meals & plan',
                        filled: !canRenew,
                        onTap: () => _open(context),
                      ),
                    ),
                    if (canRenew) ...[
                      const SizedBox(width: AppSizes.spacing8),
                      Expanded(
                        child: _PillButton(
                          label: 'Renew plan',
                          filled: true,
                          onTap: () => openSubscriptionPlans(context,
                              scrollToPlanId: plan!.id),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Grace period: renew card ────────────────────────────────────────────────

class _RenewPlanCard extends ConsumerWidget {
  const _RenewPlanCard({required this.sub, required this.plan});

  final SubscriptionInfo sub;
  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renewal = plan.renewal;
    final renewBy = convertMongoUtcToIstExceptTime(
        sub.renewalDeadline(fallbackGraceDays: plan.gracePeriodDays)
            ?.toIso8601String());
    final discounted = renewal != null && renewal.hasDiscount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing8,
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing8,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(AppSizes.radius16),
          border:
              Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hourglass_bottom_rounded,
                    color: kSubscriptionAccent, size: AppSizes.icon20),
                const SizedBox(width: AppSizes.spacing8),
                Expanded(
                  child: Text(
                    'Your ${sub.planName} has ended',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize16,
                      fontWeight: AppTypography.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacing4),
            Text(
              renewBy.isNotEmpty
                  ? 'Renew by $renewBy to keep your meals going.'
                  : 'Renew now to keep your meals going.',
              style: const TextStyle(
                fontSize: AppTypography.fontSize13,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeightSmall,
              child: ElevatedButton(
                onPressed: () =>
                    openSubscriptionPlans(context, scrollToPlanId: plan.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                ),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.bold,
                      fontFamily: 'Lato',
                    ),
                    children: [
                      const TextSpan(text: 'Renew · '),
                      if (discounted) ...[
                        TextSpan(
                          text: '₹${renewal.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: AppTypography.regular,
                            color: Colors.white.withValues(alpha: 0.75),
                            decoration: TextDecoration.lineThrough,
                            decorationColor:
                                Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        TextSpan(
                            text:
                                ' ₹${renewal.discountPrice.toStringAsFixed(0)}'),
                      ] else
                        TextSpan(text: plan.formattedPrice),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(AppSizes.radius8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.fontSize13,
                fontWeight: AppTypography.bold,
                color: filled ? AppColors.darkGreen : Colors.white,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Heading that separates the plans section from the outlet menu below it.
class HomeMenuSectionTitle extends StatelessWidget {
  const HomeMenuSectionTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing20,
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing4,
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant_menu_rounded,
              size: AppSizes.icon20, color: AppColors.primaryGreen),
          SizedBox(width: AppSizes.spacing6),
          Text(
            'Order from our kitchen',
            style: TextStyle(
              fontSize: AppTypography.fontSize18,
              fontWeight: AppTypography.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }
}
