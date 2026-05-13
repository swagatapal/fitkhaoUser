import 'package:flutter/material.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPaddingHorizontal,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSizes.spacing20),
                      _buildFitKhaoLogo(),
                      const SizedBox(height: AppSizes.spacing16),
                      // Wallet balance — always visible when loaded
                      if (ref.watch(walletProvider).wallet != null) ...[
                        _buildWalletBalanceCard(),
                        const SizedBox(height: AppSizes.spacing16),
                      ],
                      // Active subscription card
                      if (ref.watch(walletProvider).hasActiveSubscription) ...[
                        _buildActiveSubscriptionCard(),
                        const SizedBox(height: AppSizes.spacing16),
                      ],
                      // Recharge Wallet — always visible
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const RechargeTopupModal(),
                            );
                          },
                          icon: const Icon(
                            Icons.account_balance_wallet,
                            size: AppSizes.icon20,
                          ),
                          label: const Text(
                            'Recharge FitKhao Wallet',
                            style: TextStyle(
                              fontSize: AppTypography.fontSize16,
                              fontWeight: AppTypography.semiBold,
                              fontFamily: 'Lato',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            side: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radius4),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSizes.spacing16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacing24),
                      if (ref.watch(walletProvider).hasActiveSubscription) ...[
                        const Text(
                          'Upgrade Your Plan',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize20,
                            fontWeight: AppTypography.bold,
                            color: AppColors.primaryGreen,
                            fontFamily: 'Lato',
                          ),
                        ),
                        const SizedBox(height: AppSizes.spacing16),
                      ],
                      _buildPlansList(),
                      const SizedBox(height: AppSizes.spacing24),
                      _buildTransactionHistoryButton(),
                      const SizedBox(height: AppSizes.spacing24),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Choose your plan",
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                //const SizedBox(height: AppSizes.spacing2),
                Text(
                  "Select the plan that fits your goal",
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
          // CircleAvatar(
          //   radius: AppSizes.spacing24,
          //   backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
          //   backgroundImage: const NetworkImage(
          //     "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTFcyssMbcvEkMiCDu8zrO9VuN-Yy1aW1vycA&s",
          //   ),
          //   onBackgroundImageError: (exception, stackTrace) {},
          //   child: Container(
          //     decoration: BoxDecoration(
          //       shape: BoxShape.circle,
          //       border: Border.all(
          //         color: AppColors.primaryGreen.withValues(alpha: 0.3),
          //         width: AppSizes.borderThin,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildFitKhaoLogo() {
    return LogoWidget();
  }

  Widget _buildPlansList() {
    final planState = ref.watch(subscriptionPlanProvider);

    if (planState.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.spacing24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (planState.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing16),
        child: Center(
          child: Column(
            children: [
              Text(
                planState.error!,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  color: AppColors.errorColor,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spacing12),
              TextButton(
                onPressed: () =>
                    ref.read(subscriptionPlanProvider.notifier).loadPlans(),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (planState.plans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.spacing16),
        child: Center(
          child: Text(
            'No subscription plans available.',
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ),
      );
    }

    // Auto-select the basic (free) plan by default
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

    return Column(
      children: [
        for (int i = 0; i < planState.plans.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSizes.spacing16),
          _buildPlanCard(planState.plans[i]),
        ],
      ],
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isBasic = plan.price == 0;
    final isSelected = _selectedPlan?.id == plan.id;
    final f = plan.features;

    final cardContent = Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: name + code badge + selection indicator
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.planName,
                  style: TextStyle(
                    fontSize: AppTypography.fontSize16,
                    fontWeight: AppTypography.bold,
                    color: isBasic
                        ? AppColors.primaryGreen
                        : AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing8,
                  vertical: AppSizes.spacing2,
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
              const SizedBox(width: AppSizes.spacing8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
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
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing8),
          // Price + duration
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                plan.formattedPrice,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize20,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(width: AppSizes.spacing4),
              Text(
                '/ ${plan.planValidity}',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.regular,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
              if (plan.gstPercentage > 0) ...[
                const SizedBox(width: AppSizes.spacing4),
                Text(
                  '+${plan.gstPercentage.toStringAsFixed(0)}% GST',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize10,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          const Divider(height: 1),
          const SizedBox(height: AppSizes.spacing12),
          // Features grid
          Wrap(
            spacing: AppSizes.spacing8,
            runSpacing: AppSizes.spacing8,
            children: [
              if (f.freeDelivery)
                _buildFeatureChip(Icons.local_shipping_outlined, 'Free Delivery', disabled: !isBasic),
              if (f.dietChart)
                _buildFeatureChip(Icons.assignment_outlined, 'Diet Chart', disabled: !isBasic),
              if (f.consultationCount > 0)
                _buildFeatureChip(
                  Icons.headset_mic_outlined,
                  '${f.consultationCount} Consultation${f.consultationCount > 1 ? 's' : ''}',
                  disabled: !isBasic,
                ),
              if (f.mealCountPerDay > 0)
                _buildFeatureChip(
                  Icons.restaurant_outlined,
                  '${f.mealCountPerDay} Meals/Day',
                  disabled: !isBasic,
                ),
              if (f.snacks)
                _buildFeatureChip(Icons.fastfood_outlined, 'Snacks', disabled: !isBasic),
              if (f.discountPercent > 0)
                _buildFeatureChip(
                  Icons.local_offer_outlined,
                  '${f.discountPercent}% Discount',
                  highlight: true,
                  disabled: !isBasic,
                ),
              if (f.suggestedPlan)
                _buildFeatureChip(Icons.auto_awesome_outlined, 'Suggested Plan', disabled: !isBasic),
            ],
          ),
        ],
      ),
    );

    if (!isBasic) {
      return Stack(
        children: [
          Opacity(opacity: 0.45, child: cardContent),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: const Center(
                child: _ComingSoonBadge(),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: cardContent,
    );
  }

  Widget _buildFeatureChip(
    IconData icon,
    String label, {
    bool highlight = false,
    bool disabled = false,
  }) {
    final color = disabled
        ? AppColors.textSecondary
        : highlight
            ? const Color(0xFFC66301)
            : AppColors.primaryGreen;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.fontSize10,
              fontWeight: AppTypography.semiBold,
              color: color,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransactionHistoryScreen(),
            ),
          );
        },
        icon: const Icon(
          Icons.history,
          size: AppSizes.icon20,
        ),
        label: const Text(
          'View Transaction History',
          style: TextStyle(
            fontSize: AppTypography.fontSize16,
            fontWeight: AppTypography.semiBold,
            fontFamily: 'Lato',
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          side: const BorderSide(
            color: AppColors.primaryGreen,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius4),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppSizes.spacing16,
          ),
        ),
      ),
    );
  }

  Widget _buildWalletBalanceCard() {
    final wallet = ref.watch(walletProvider).wallet;
    if (wallet == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primaryGreen,
              size: AppSizes.icon24,
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wallet Balance',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.medium,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing2),
                Text(
                  '₹${wallet.couponBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize20,
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
    );
  }

  Widget _buildActiveSubscriptionCard() {
    final subscription = ref.watch(walletProvider).subscription;
    if (subscription == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A7C3E), Color(0xFF6BA84F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                child: Image.asset(
                  'assets/images/buttonshit_logo.png',
                  height: AppSizes.icon28,
                  width: AppSizes.icon28,
                ),
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Plan',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.medium,
                        color: Colors.white,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing2),
                    Text(
                      subscription.planName,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.semiBold,
                        color: Colors.white,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing12,
                  vertical: AppSizes.spacing6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSizes.radius20),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.bold,
                    color: Colors.white,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.formattedPrice,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.semiBold,
                        color: Colors.white,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing2),
                    const Text(
                      'Plan Amount',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.regular,
                        color: Colors.white,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${subscription.remainingDays}',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.semiBold,
                        color: Colors.white,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing2),
                    const Text(
                      'Days Remaining',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.regular,
                        color: Colors.white,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final hasActiveSubscription = ref.watch(walletProvider).hasActiveSubscription;
    final isFreePlan = _selectedPlan != null && _selectedPlan!.price == 0;

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.buttonHeight,
        child: hasActiveSubscription
            ? Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                  border: Border.all(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'You already have active plan',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize16,
                      fontWeight: AppTypography.bold,
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
                  disabledForegroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  isFreePlan
                      ? 'Free Plan — No Purchase Needed'
                      : _selectedPlan == null
                          ? 'Select a Plan'
                          : 'Buy ${_selectedPlan!.planValidity} Plan',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize16,
                    fontWeight: AppTypography.semiBold,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
      ),
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
        color: const Color(0xFF5A5A5A),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 14, color: Colors.white),
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