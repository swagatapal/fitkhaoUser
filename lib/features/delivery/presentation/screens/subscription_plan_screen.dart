import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/logo_widget.dart';
import '../../models/subscription_plan_model.dart';
import '../../providers/subscription_plan_provider.dart';
import '../../providers/wallet_provider.dart';
import '../widgets/recharge_topup_modal.dart';
import 'subscription_checkout_screen.dart';
import 'transaction_history_screen.dart';

class SubscriptionPlanScreen extends ConsumerStatefulWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  ConsumerState<SubscriptionPlanScreen> createState() =>
      _SubscriptionPlanScreenState();
}

class _SubscriptionPlanScreenState
    extends ConsumerState<SubscriptionPlanScreen> {
  SubscriptionPlan? _selectedPlan;

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFBFC),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPaddingHorizontal,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSizes.spacing24),
                      _buildBrandSection(),
                      const SizedBox(height: AppSizes.spacing32),
                      _buildWalletSection(),
                      const SizedBox(height: AppSizes.spacing32),
                      if (ref.watch(walletProvider).hasActiveSubscription)
                        _buildActiveSubscriptionSection(),
                      if (ref.watch(walletProvider).hasActiveSubscription)
                        const SizedBox(height: AppSizes.spacing32),
                      _buildPlansSection(),
                      const SizedBox(height: AppSizes.spacing24),
                      _buildActionButtons(),
                      const SizedBox(height: AppSizes.spacing32),
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

  // ─── Sliver App Bar ───
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          margin: const EdgeInsets.all(AppSizes.spacing8),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
      title: const Text(
        'Choose Your Plan',
        style: TextStyle(
          fontSize: AppTypography.fontSize18,
          fontWeight: AppTypography.bold,
          color: AppColors.textPrimary,
          fontFamily: 'Lato',
        ),
      ),
      centerTitle: false,
    );
  }

  // ─── Brand Section ───
  Widget _buildBrandSection() {
    return Row(
      children: [
        const LogoWidget(),
        const SizedBox(width: AppSizes.spacing12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to FitKhao',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.semiBold,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing4),
            Text(
              'Find your perfect nutrition plan',
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                fontWeight: AppTypography.regular,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Wallet Section ───
  Widget _buildWalletSection() {
    final walletState = ref.watch(walletProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wallet',
          style: TextStyle(
            fontSize: AppTypography.fontSize16,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        if (walletState.wallet != null)
          _buildWalletBalanceCard()
        else
          _buildWalletSkeleton(),
        const SizedBox(height: AppSizes.spacing12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const RechargeTopupModal(),
              );
            },
            icon: const Icon(Icons.add_rounded, size: AppSizes.icon20),
            label: const Text(
              'Recharge Wallet',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.semiBold,
                fontFamily: 'Lato',
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(
                color: AppColors.primaryGreen,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletBalanceCard() {
    final wallet = ref.watch(walletProvider).wallet!;

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5D9E40), Color(0xFF7AB655)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
            child: const Icon(
              Icons.wallet_giftcard_rounded,
              color: Colors.white,
              size: AppSizes.icon28,
            ),
          ),
          const SizedBox(width: AppSizes.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${wallet.couponBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize22,
                    fontWeight: AppTypography.bold,
                    color: Colors.white,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing4),
                Text(
                  'Available Balance',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.regular,
                    color: Colors.white.withValues(alpha: 0.85),
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

  Widget _buildWalletSkeleton() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      height: 80,
    );
  }

  // ─── Active Subscription Section ───
  Widget _buildActiveSubscriptionSection() {
    final subscription = ref.watch(walletProvider).subscription!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Plan',
          style: TextStyle(
            fontSize: AppTypography.fontSize16,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        Container(
          padding: const EdgeInsets.all(AppSizes.spacing16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGreen.withValues(alpha: 0.95),
                AppColors.primaryGreen.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            border: Border.all(
              color: AppColors.primaryGreen,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.planName,
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize16,
                          fontWeight: AppTypography.bold,
                          color: Colors.white,
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacing4),
                      Text(
                        'Active until ${subscription.endDate}',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize12,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing12,
                      vertical: AppSizes.spacing6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppSizes.radius20),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize10,
                        fontWeight: AppTypography.semiBold,
                        color: Colors.white,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacing12),
              Row(
                children: [
                  Expanded(
                    child: _buildSubscriptionInfoCard(
                      subscription.formattedPrice,
                      'Plan Amount',
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacing12),
                  Expanded(
                    child: _buildSubscriptionInfoCard(
                      '${subscription.remainingDays}',
                      'Days Left',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionInfoCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.bold,
              color: Colors.white,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing4),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.fontSize10,
              color: Colors.white.withValues(alpha: 0.75),
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }

  // ─── Plans Section ───
  Widget _buildPlansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose a Plan',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize16,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing4),
                Text(
                  'Select the best plan for your needs',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacing16),
        _buildPlansList(),
      ],
    );
  }

  Widget _buildPlansList() {
    final planState = ref.watch(subscriptionPlanProvider);

    if (planState.isLoading) {
      return _buildPlansLoadingSkeleton();
    }

    if (planState.error != null) {
      return _buildErrorState(planState.error!);
    }

    if (planState.plans.isEmpty) {
      return _buildEmptyState();
    }

    // Auto-select basic plan
    if (_selectedPlan == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final basicPlan = planState.plans.firstWhere(
            (p) => p.price == 0,
            orElse: () => planState.plans.first,
          );
          setState(() => _selectedPlan = basicPlan);
        }
      });
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: planState.plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing16),
      itemBuilder: (context, index) {
        return _buildPlanCard(planState.plans[index]);
      },
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isBasic = plan.price == 0;
    final isSelected = _selectedPlan?.id == plan.id;
    final f = plan.features;

    final cardContent = GestureDetector(
      onTap: isBasic ? () => setState(() => _selectedPlan = plan) : null,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
                : AppColors.borderColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.planName,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize16,
                          fontWeight: AppTypography.bold,
                          color: isBasic
                              ? AppColors.primaryGreen
                              : AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacing4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.spacing8,
                          vertical: AppSizes.spacing4,
                        ),
                        decoration: BoxDecoration(
                          color: isBasic
                              ? AppColors.primaryGreen.withValues(alpha: 0.1)
                              : AppColors.borderColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppSizes.radius4),
                        ),
                        child: Text(
                          plan.planCode,
                          style: TextStyle(
                            fontSize: AppTypography.fontSize10,
                            fontWeight: AppTypography.semiBold,
                            color: isBasic
                                ? AppColors.primaryGreen
                                : AppColors.textSecondary,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.primaryGreen
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.borderColor,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacing12),

            // Price
            Row(
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
                        '+${plan.gstPercentage.toStringAsFixed(0)}% GST',
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize10,
                          color: AppColors.textSecondary,
                          fontFamily: 'Lato',
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacing16),

            // Divider
            Divider(
              height: 1,
              color: AppColors.borderColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSizes.spacing16),

            // Features
            _buildFeaturesGrid(f, isBasic),
          ],
        ),
      ),
    );

    if (!isBasic) {
      return Stack(
        children: [
          Opacity(opacity: 0.4, child: cardContent),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radius12),
              ),
              child: const Center(
                child: _ComingSoonBadge(),
              ),
            ),
          ),
        ],
      );
    }

    return cardContent;
  }

  Widget _buildFeaturesGrid(PlanFeatures f, bool isBasic) {
    final features = [
      if (f.freeDelivery) _buildFeature(Icons.local_shipping_rounded, 'Free Delivery'),
      if (f.dietChart) _buildFeature(Icons.assignment_rounded, 'Diet Chart'),
      if (f.consultationCount > 0)
        _buildFeature(
          Icons.headset_mic_rounded,
          '${f.consultationCount} Consultation${f.consultationCount > 1 ? 's' : ''}',
        ),
      if (f.mealCountPerDay > 0)
        _buildFeature(Icons.restaurant_rounded, '${f.mealCountPerDay} Meals/Day'),
      if (f.snacks) _buildFeature(Icons.fastfood_rounded, 'Snacks'),
      if (f.discountPercent > 0)
        _buildFeature(Icons.local_offer_rounded, '${f.discountPercent}% Discount', highlight: true),
      if (f.suggestedPlan) _buildFeature(Icons.auto_awesome_rounded, 'Suggested'),
    ];

    return Wrap(
      spacing: AppSizes.spacing8,
      runSpacing: AppSizes.spacing8,
      children: features,
    );
  }

  Widget _buildFeature(IconData icon, String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing10,
        vertical: AppSizes.spacing6,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFC66301).withValues(alpha: 0.1)
            : AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius6),
        border: Border.all(
          color: highlight
              ? const Color(0xFFC66301).withValues(alpha: 0.2)
              : AppColors.primaryGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight
                ? const Color(0xFFC66301)
                : AppColors.primaryGreen,
          ),
          const SizedBox(width: AppSizes.spacing4),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.fontSize10,
              fontWeight: AppTypography.semiBold,
              color: highlight
                  ? const Color(0xFFC66301)
                  : AppColors.primaryGreen,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }

  // ─── Action Buttons ───
  Widget _buildActionButtons() {
    final walletState = ref.watch(walletProvider);
    final isFreePlan = _selectedPlan != null && _selectedPlan!.price == 0;
    final hasActiveSubscription = walletState.hasActiveSubscription;

    return Column(
      children: [
        // Primary Action Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: hasActiveSubscription
              ? Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radius12),
                    border: Border.all(color: AppColors.primaryGreen),
                  ),
                  child: const Center(
                    child: Text(
                      'You have an active plan',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.primaryGreen,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: (_selectedPlan == null || isFreePlan)
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubscriptionCheckoutScreen(
                                planDays: _selectedPlan!.planDays,
                                planPrice: _selectedPlan!.formattedPrice,
                                planCode: _selectedPlan!.planCode,
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.borderColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius12),
                    ),
                  ),
                  child: Text(
                    isFreePlan
                        ? 'Free Plan — No Payment Needed'
                        : _selectedPlan == null
                            ? 'Select a Plan'
                            : 'Subscribe to ${_selectedPlan!.planValidity}',
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.semiBold,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
        ),
        const SizedBox(height: AppSizes.spacing12),

        // Secondary Action Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransactionHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history_rounded, size: AppSizes.icon18),
            label: const Text(
              'View Transaction History',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.semiBold,
                fontFamily: 'Lato',
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(
                color: AppColors.primaryGreen,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Error & Empty States ───
  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE8E6),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: AppColors.errorColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: AppColors.errorColor,
          ),
          const SizedBox(height: AppSizes.spacing12),
          Text(
            error,
            style: const TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.errorColor,
              fontFamily: 'Lato',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.spacing12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  ref.read(subscriptionPlanProvider.notifier).loadPlans(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(fontFamily: 'Lato'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing24),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 48,
            color: AppColors.primaryGreen.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSizes.spacing12),
          const Text(
            'No Plans Available',
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

  Widget _buildPlansLoadingSkeleton() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing16),
      itemBuilder: (context, index) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(AppSizes.radius12),
          ),
        );
      },
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock_rounded, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Coming Soon',
            style: TextStyle(
              fontSize: AppTypography.fontSize13,
              fontWeight: AppTypography.semiBold,
              color: Colors.white,
              fontFamily: 'Lato',
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
