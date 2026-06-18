import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/time_converter.dart';
import '../../models/subscription_plan_model.dart';
import '../../providers/subscription_plan_provider.dart';
import '../../providers/wallet_provider.dart';
import '../widgets/cancel_subscription_sheet.dart';
import '../widgets/recharge_topup_modal.dart';
import '../widgets/subscription_benefits.dart';
import 'subscription_checkout_screen.dart';
import 'transaction_history_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Subscription plan screen.
//
// Composed of small, independently-rebuilding [ConsumerWidget]s so a selection
// tap or a wallet refresh never rebuilds the whole tree:
//   • _WalletBar           → rebuilds only on wallet change
//   • _ActivePlanBanner    → rebuilds only on subscription change
//   • _PlansList / _PlanCard → a card rebuilds only when ITS selected-state flips
//   • _SubscribeBar        → rebuilds on selection / subscription change
// Selection lives in [selectedSubscriptionPlanProvider] (a plain id), not in
// widget state, which is what keeps the rebuild surface minimal.
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionPlanScreen extends ConsumerStatefulWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  ConsumerState<SubscriptionPlanScreen> createState() =>
      _SubscriptionPlanScreenState();
}

class _SubscriptionPlanScreenState
    extends ConsumerState<SubscriptionPlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).loadWalletBalance();
      ref.read(subscriptionPlanProvider.notifier).loadPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Auto-select a sensible default once plans arrive — the recommended plan
    // if any, else the first. `ref.listen` reacts without rebuilding this screen.
    ref.listen<SubscriptionPlanState>(subscriptionPlanProvider, (prev, next) {
      if (next.plans.isEmpty) return;
      if (ref.read(selectedSubscriptionPlanProvider) != null) return;
      final def = next.plans.firstWhere(
        (p) => p.features.suggestedPlan,
        orElse: () => next.plans.first,
      );
      ref.read(selectedSubscriptionPlanProvider.notifier).state = def.id;
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFBFC),
        bottomNavigationBar: const _SubscribeBar(),
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPaddingHorizontal,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SizedBox(height: AppSizes.spacing16),
                      _WalletBar(),
                      SizedBox(height: AppSizes.spacing16),
                      _ActivePlanBanner(),
                      _PlansHeader(),
                      SizedBox(height: AppSizes.spacing12),
                      _PlansList(),
                      SizedBox(height: AppSizes.spacing24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.white,
      toolbarHeight: 64,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p20,
          vertical: AppSizes.spacing8,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.pop(),
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
              child: Text(
                'Choose Your Plan',
                style: TextStyle(
                  fontSize: AppTypography.fontSize20,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Compact wallet bar (balance + recharge + history) ───────────────────────

class _WalletBar extends ConsumerWidget {
  const _WalletBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider.select((s) => s.wallet));
    final balance = wallet?.couponBalance;

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.primaryGreen, size: AppSizes.icon20),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Wallet balance',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize10,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: 2),
                balance == null
                    ? Container(
                        width: 70,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    : Text(
                        '₹${balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize18,
                          fontWeight: AppTypography.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
              ],
            ),
          ),
          // History
          _CompactIconButton(
            icon: Icons.history_rounded,
            tooltip: 'Transaction history',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const TransactionHistoryScreen(),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacing8),
          // Recharge
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const RechargeTopupModal(),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing12,
                vertical: AppSizes.spacing8,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Recharge',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      fontWeight: AppTypography.semiBold,
                      color: Colors.white,
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSizes.spacing8),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
          child: Icon(icon,
              color: AppColors.primaryGreen, size: AppSizes.icon20),
        ),
      ),
    );
  }
}

// ─── Active subscription banner (compact) ────────────────────────────────────

class _ActivePlanBanner extends ConsumerWidget {
  const _ActivePlanBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(
      walletProvider.select((s) => s.hasActiveSubscription ? s.subscription : null),
    );
    if (sub == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing16),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5D9E40), Color(0xFF7AB655)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: const Icon(Icons.verified_rounded,
                  color: Colors.white, size: AppSizes.icon20),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Active: ${sub.planName}',
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.bold,
                      color: Colors.white,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sub.remainingDays} days left · ends ${convertMongoUtcToIst(sub.endDate)}',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize10,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
            // Cancel the active subscription (opens the refund-preview sheet).
            if (sub.id.isNotEmpty)
              GestureDetector(
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) =>
                      CancelSubscriptionSheet(subscriptionId: sub.id),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spacing12,
                    vertical: AppSizes.spacing6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSizes.radius20),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      fontWeight: AppTypography.semiBold,
                      color: Colors.white,
                      fontFamily: 'Lato',
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

// ─── Plans header ────────────────────────────────────────────────────────────

class _PlansHeader extends StatelessWidget {
  const _PlansHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a plan',
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Pick the plan that fits your goals',
          style: TextStyle(
            fontSize: AppTypography.fontSize12,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }
}

// ─── Plans list (loading / error / empty / list) ─────────────────────────────

class _PlansList extends ConsumerWidget {
  const _PlansList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionPlanProvider);

    if (state.isLoading && state.plans.isEmpty) {
      return const _PlansSkeleton();
    }
    if (state.error != null && state.plans.isEmpty) {
      return _ErrorState(
        message: state.error!,
        onRetry: () => ref.read(subscriptionPlanProvider.notifier).loadPlans(),
      );
    }
    if (state.plans.isEmpty) {
      return const _EmptyState();
    }

    return Column(
      children: [
        for (final plan in state.plans)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spacing16),
            child: _PlanCard(plan: plan),
          ),
      ],
    );
  }
}

// ─── Plan card ───────────────────────────────────────────────────────────────

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds ONLY when this card's selected-state flips.
    final isSelected = ref.watch(
      selectedSubscriptionPlanProvider.select((id) => id == plan.id),
    );
    final isRecommended = plan.features.suggestedPlan;

    return GestureDetector(
      onTap: () =>
          ref.read(selectedSubscriptionPlanProvider.notifier).state = plan.id,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSizes.spacing16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
                : AppColors.borderColor.withValues(alpha: 0.35),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primaryGreen.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: name + code (+ recommended) + radio ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.planName,
                              style: const TextStyle(
                                fontSize: AppTypography.fontSize16,
                                fontWeight: AppTypography.bold,
                                color: AppColors.textPrimary,
                                fontFamily: 'Lato',
                              ),
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: AppSizes.spacing8),
                            const _RecommendedBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSizes.spacing4),
                      Text(
                        plan.planCode,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize10,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.textSecondary.withValues(alpha: 0.8),
                          fontFamily: 'Lato',
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                _RadioDot(isSelected: isSelected),
              ],
            ),

            if (plan.description.trim().isNotEmpty) ...[
              const SizedBox(height: AppSizes.spacing8),
              Text(
                plan.description.trim(),
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                  height: 1.35,
                  fontFamily: 'Lato',
                ),
              ),
            ],

            const SizedBox(height: AppSizes.spacing12),

            // ── Price ──
            _PriceRow(plan: plan),

            const SizedBox(height: AppSizes.spacing16),
            Divider(
              height: 1,
              color: AppColors.borderColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSizes.spacing12),

            // ── Feature checklist (shared with checkout) ──
            SubscriptionBenefitsList(plan: plan),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    if (plan.price == 0) {
      return const Text(
        'Free',
        style: TextStyle(
          fontSize: AppTypography.fontSize22,
          fontWeight: AppTypography.bold,
          color: AppColors.primaryGreen,
          fontFamily: 'Lato',
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          plan.formattedPrice,
          style: const TextStyle(
            fontSize: AppTypography.fontSize24,
            fontWeight: AppTypography.bold,
            color: AppColors.primaryGreen,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(width: AppSizes.spacing4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '/ ${plan.planValidity}',
              style: const TextStyle(
                fontSize: AppTypography.fontSize12,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
            if (plan.gstPercentage > 0)
              Text(
                '+ ${plan.gstPercentage.toStringAsFixed(0)}% GST',
                style: TextStyle(
                  fontSize: AppTypography.fontSize10,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  fontFamily: 'Lato',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.primaryGreen : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSubscriptionAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12, color: kSubscriptionAccent),
          SizedBox(width: 3),
          Text(
            'RECOMMENDED',
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

// ─── Sticky subscribe bar ────────────────────────────────────────────────────

class _SubscribeBar extends ConsumerWidget {
  const _SubscribeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActive =
        ref.watch(walletProvider.select((s) => s.hasActiveSubscription));
    final selectedId = ref.watch(selectedSubscriptionPlanProvider);
    final plans = ref.watch(subscriptionPlanProvider.select((s) => s.plans));

    // Nothing to act on yet.
    if (plans.isEmpty) return const SizedBox.shrink();

    SubscriptionPlan? selected;
    for (final p in plans) {
      if (p.id == selectedId) {
        selected = p;
        break;
      }
    }

    final isFree = selected != null && selected.price == 0;

    final String label;
    final VoidCallback? onPressed;
    if (hasActive) {
      label = 'You already have an active plan';
      onPressed = null;
    } else if (selected == null) {
      label = 'Select a plan';
      onPressed = null;
    } else if (isFree) {
      label = 'Free plan — no payment needed';
      onPressed = null;
    } else {
      label = 'Subscribe · ${selected.formattedPrice} / ${selected.planValidity}';
      final plan = selected;
      onPressed = () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SubscriptionCheckoutScreen(plan: plan),
            ),
          );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing12,
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing12,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.borderColor.withValues(alpha: 0.6),
                disabledForegroundColor: AppColors.textSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.bold,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── States: skeleton / error / empty ────────────────────────────────────────

class _PlansSkeleton extends StatelessWidget {
  const _PlansSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (_) => Container(
          height: 240,
          margin: const EdgeInsets.only(bottom: AppSizes.spacing16),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(AppSizes.radius16),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacing20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE8E6),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: AppColors.errorColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 40, color: AppColors.errorColor),
          const SizedBox(height: AppSizes.spacing12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.errorColor,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
              ),
              child: const Text('Try Again', style: TextStyle(fontFamily: 'Lato')),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacing24),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded,
              size: 48, color: AppColors.primaryGreen.withValues(alpha: 0.4)),
          const SizedBox(height: AppSizes.spacing12),
          const Text(
            'No plans available',
            style: TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            'Check back soon for subscription plans',
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }
}

