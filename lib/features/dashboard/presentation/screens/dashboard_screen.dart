import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../delivery/models/subscription_plan_model.dart';
import '../../../delivery/models/wallet_balance_model.dart';
import '../../../delivery/presentation/screens/subscription_plan_screen.dart';
import '../../../delivery/providers/nutrition_provider.dart';
import '../../../delivery/providers/delivery_slot_provider.dart';
import '../../../delivery/providers/subscription_plan_provider.dart';
import '../../../delivery/providers/wallet_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../widgets/delivery_slot_widget.dart';
import '../widgets/meal_plan_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await Future.wait([
      ref.read(authProvider.notifier).loadProfile(),
      ref.read(nutritionProgressProvider.notifier).getDailyNutritionProgress(),
      ref.read(walletProvider.notifier).loadWalletBalance(),
      ref.read(subscriptionPlanProvider.notifier).loadPlans(),
    ]);
    // Load meal plan and delivery slots only if tier warrants it
    final tier = _currentTier();
    if (tier == PlanTier.pro || tier == PlanTier.achievers) {
      await Future.wait([
        ref.read(mealPlanProvider.notifier).loadMealPlan(),
        ref.read(deliverySlotApiProvider.notifier).loadDeliverySlots(),
      ]);
    }
  }

  PlanTier _currentTier() {
    // Profile API activeSubscription is the authoritative source;
    // fall back to wallet API subscription if profile hasn't loaded yet.
    final authSub = ref.read(authProvider).activeSubscription;
    if (authSub != null) return authSub.planTier;
    final walletSub = ref.read(walletProvider).subscription;
    return walletSub?.planTier ?? PlanTier.none;
  }

  bool _hasNutritionalTargets() {
    final auth = ref.watch(authProvider);
    return auth.targetProtein != null &&
        auth.targetFat != null &&
        auth.targetCarbs != null &&
        auth.targetKCalories != null;
  }

  String _formattedLastUpdated() {
    final lastUpdated = ref.watch(authProvider).lastUpdatedTargetKCal;
    if (lastUpdated == null) return '';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final day = lastUpdated.day;
    final suffix = (day == 1 || day == 21 || day == 31)
        ? 'st'
        : (day == 2 || day == 22)
            ? 'nd'
            : (day == 3 || day == 23)
                ? 'rd'
                : 'th';
    return '$day$suffix ${months[lastUpdated.month - 1]}';
  }

  Color _progressColor(int percentage) {
    if (percentage >= 100) return const Color(0xFFD32F2F);
    if (percentage >= 80) return const Color(0xFFFF9800);
    if (percentage >= 50) return const Color(0xFF4A7C3E);
    return const Color(0xFF6BA84F);
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final planState = ref.watch(subscriptionPlanProvider);

    final authState = ref.watch(authProvider);

    // Derive tier — null while wallet is still loading (shows skeleton).
    // Profile activeSubscription is authoritative; wallet subscription is fallback.
    final tier = walletState.isLoading
        ? null
        : (authState.activeSubscription?.planTier
            ?? walletState.subscription?.planTier
            ?? PlanTier.none);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primaryGreen,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenPaddingHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSizes.spacing16),
                _buildHeader(),
                const SizedBox(height: AppSizes.spacing20),
                // Loading wallet state
                if (tier == null)
                  _buildTierLoadingPlaceholder()
                // No subscription
                else if (tier == PlanTier.none)
                  _buildNoSubscriptionSection(planState)
                else ...[
                  // Nutritional targets (all tiers)
                  if (_hasNutritionalTargets()) ...[
                    _buildNutritionalTargetsSection(),
                    const SizedBox(height: AppSizes.spacing24),
                  ] else
                    _buildNoTargetsPlaceholder(),
                  // Go plan: locked features upgrade prompt
                  if (tier == PlanTier.go) ...[
                    _buildGoUpgradeBanner(planState.plans),
                    const SizedBox(height: AppSizes.spacing32),
                  ],
                  // Pro & Achievers: full dashboard content
                  if (tier == PlanTier.pro || tier == PlanTier.achievers) ...[
                    _buildMealPlanSection(),
                    const SizedBox(height: AppSizes.spacing32),
                    const DeliverySlotWidget(),
                    const SizedBox(height: AppSizes.spacing32),
                  ],
                  // Pro: promote Achievers
                  if (tier == PlanTier.pro)
                    _buildProUpgradeBanner(planState.plans),
                ],
                const SizedBox(height: AppSizes.spacing32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final formattedDate = _formattedLastUpdated();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'My Progress',
          style: TextStyle(
            fontSize: AppTypography.fontSize20,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        if (formattedDate.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing12,
              vertical: AppSizes.spacing6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFC66301),
              borderRadius: BorderRadius.circular(AppSizes.radius4),
            ),
            child: Text(
              'Updated $formattedDate',
              style: const TextStyle(
                fontSize: AppTypography.fontSize12,
                fontWeight: AppTypography.medium,
                color: Colors.white,
                fontFamily: 'Lato',
              ),
            ),
          ),
      ],
    );
  }

  // ─── Tier loading skeleton ────────────────────────────────────────────────

  Widget _buildTierLoadingPlaceholder() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );
  }

  // ─── No subscription ─────────────────────────────────────────────────────

  Widget _buildNoSubscriptionSection(SubscriptionPlanState planState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero CTA banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.spacing20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A7C3E), Color(0xFF6BA84F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.restaurant_menu_outlined,
                  color: Colors.white, size: 36),
              const SizedBox(height: AppSizes.spacing12),
              const Text(
                'Start Your Healthy Journey',
                style: TextStyle(
                  fontSize: AppTypography.fontSize18,
                  fontWeight: AppTypography.bold,
                  color: Colors.white,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing6),
              const Text(
                'Subscribe to unlock personalised meal plans,\nnutrition tracking, and expert consultations.',
                style: TextStyle(
                  fontSize: AppTypography.fontSize13,
                  color: Colors.white,
                  fontFamily: 'Lato',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSizes.spacing16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionPlanScreen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.spacing12),
                  ),
                  child: const Text(
                    'View Subscription Plans',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.bold,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacing24),
        // Plans preview
        if (planState.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.spacing16),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          )
        else if (planState.plans.isNotEmpty) ...[
          const Text(
            'Available Plans',
            style: TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          for (final plan in planState.plans) ...[
            _buildCompactPlanCard(plan),
            const SizedBox(height: AppSizes.spacing12),
          ],
        ],
      ],
    );
  }

  Widget _buildCompactPlanCard(SubscriptionPlan plan) {
    final f = plan.features;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionPlanScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.3)),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.planName,
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize14,
                          fontWeight: AppTypography.bold,
                          color: AppColors.primaryGreen,
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(width: AppSizes.spacing6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSizes.radius4),
                        ),
                        child: Text(
                          plan.planCode,
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize10,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.primaryGreen,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.spacing6),
                  Wrap(
                    spacing: AppSizes.spacing6,
                    runSpacing: AppSizes.spacing4,
                    children: [
                      if (f.freeDelivery)
                        _miniChip(Icons.local_shipping_outlined, 'Free Delivery'),
                      if (f.dietChart)
                        _miniChip(Icons.assignment_outlined, 'Diet Chart'),
                      if (f.consultationCount > 0)
                        _miniChip(Icons.headset_mic_outlined,
                            '${f.consultationCount} Consultation${f.consultationCount > 1 ? 's' : ''}'),
                      if (f.mealCountPerDay > 0)
                        _miniChip(Icons.restaurant_outlined,
                            '${f.mealCountPerDay} Meals/Day'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.formattedPrice,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize16,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                Text(
                  '/ ${plan.planValidity}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize10,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppColors.primaryGreen),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Go plan upgrade banner ───────────────────────────────────────────────

  Widget _buildGoUpgradeBanner(List<SubscriptionPlan> plans) {
    // Find the next tiers to promote
    final higherPlans = plans.where((p) {
      final code = p.planCode.toLowerCase();
      return code.contains('pro') || code.contains('achiever');
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
            color: const Color(0xFFC66301).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC66301).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing6),
                decoration: BoxDecoration(
                  color: const Color(0xFFC66301).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
                child: const Icon(Icons.lock_outline,
                    size: 18, color: Color(0xFFC66301)),
              ),
              const SizedBox(width: AppSizes.spacing10),
              const Expanded(
                child: Text(
                  'Unlock More Features',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize15,
                    fontWeight: AppTypography.bold,
                    color: Color(0xFFC66301),
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          const Text(
            'Upgrade to Pro or Achievers to access:',
            style: TextStyle(
              fontSize: AppTypography.fontSize13,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing10),
          _lockedFeatureRow(Icons.calendar_today_outlined,
              'Personalised Meal Plan', 'Daily assigned meals by your nutritionist'),
          const SizedBox(height: AppSizes.spacing8),
          _lockedFeatureRow(Icons.delivery_dining_outlined,
              'Delivery Slot Selection', 'Choose when your meals get delivered'),
          if (higherPlans.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spacing16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionPlanScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC66301),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
                ),
                child: const Text(
                  'Upgrade Plan',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.bold,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lockedFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 14, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: AppSizes.spacing10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize13,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize10,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.lock_outline, size: 14, color: AppColors.textTertiary),
      ],
    );
  }

  // ─── Pro → Achievers upgrade banner ──────────────────────────────────────

  Widget _buildProUpgradeBanner(List<SubscriptionPlan> plans) {
    final achieversPlan = plans.firstWhere(
      (p) => p.planCode.toLowerCase().contains('achiever'),
      orElse: () => plans.isNotEmpty ? plans.last : _emptyPlan,
    );
    final f = achieversPlan.features;

    // Build a list of benefits that Achievers adds
    final extraBenefits = <_Benefit>[];
    if (f.snacks) {
      extraBenefits.add(const _Benefit(
          Icons.fastfood_outlined, 'Snacks Included',
          'Healthy snacks added to your daily plan'));
    }
    if (f.consultationCount > 0) {
      extraBenefits.add(_Benefit(
          Icons.headset_mic_outlined,
          '${f.consultationCount} Expert Consultations',
          'Direct sessions with your nutritionist'));
    }
    if (f.discountPercent > 0) {
      extraBenefits.add(_Benefit(
          Icons.local_offer_outlined,
          '${f.discountPercent}% Discount',
          'Extra savings on every order'));
    }
    if (f.suggestedPlan) {
      extraBenefits.add(const _Benefit(
          Icons.auto_awesome_outlined, 'AI Suggested Plan',
          'Smart meal suggestions tailored to your progress'));
    }

    if (extraBenefits.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4A7C3E).withValues(alpha: 0.08),
            const Color(0xFF6BA84F).withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
                child: const Icon(Icons.workspace_premium_outlined,
                    size: 18, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: AppSizes.spacing10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to ${achieversPlan.planName}',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize15,
                        fontWeight: AppTypography.bold,
                        color: AppColors.primaryGreen,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const Text(
                      'Get the complete FitKhao experience',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize10,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          const Divider(height: 1),
          const SizedBox(height: AppSizes.spacing12),
          const Text(
            "What you'll additionally get:",
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing10),
          for (final b in extraBenefits) ...[
            _achieversBenefitRow(b),
            const SizedBox(height: AppSizes.spacing8),
          ],
          const SizedBox(height: AppSizes.spacing8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achieversPlan.formattedPrice,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.bold,
                        color: AppColors.primaryGreen,
                        fontFamily: 'Lato',
                      ),
                    ),
                    Text(
                      '/ ${achieversPlan.planValidity}',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize10,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionPlanScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spacing20,
                    vertical: AppSizes.spacing10,
                  ),
                ),
                child: const Text(
                  'Upgrade Now',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize13,
                    fontWeight: AppTypography.bold,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _achieversBenefitRow(_Benefit b) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline,
            size: 16, color: AppColors.primaryGreen),
        const SizedBox(width: AppSizes.spacing8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.title,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize13,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              Text(
                b.subtitle,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize10,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Nutritional targets ─────────────────────────────────────────────────

  Widget _buildNutritionalTargetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nutritional Targets',
          style: TextStyle(
            fontSize: AppTypography.fontSize16,
            fontWeight: AppTypography.semiBold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        _buildNutritionProgress(),
      ],
    );
  }

  Widget _buildNutritionProgress() {
    final progressState = ref.watch(nutritionProgressProvider);

    if (progressState.isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (progressState.error != null) {
      return _buildErrorState(progressState.error!);
    }

    if (progressState.progressData == null) {
      return const SizedBox.shrink();
    }

    final targets = progressState.progressData!.targets;
    final progress = progressState.progressData!.progress;

    return Column(
      children: [
        _buildCaloriesCard(
          consumed: progress.calories.consumed,
          target: targets.calories,
          remaining: progress.calories.remaining,
          percentage: progress.calories.percentage,
        ),
        const SizedBox(height: AppSizes.spacing12),
        Row(
          children: [
            Expanded(
              child: _buildMacroCard(
                label: 'Protein',
                consumed: progress.protein.consumed,
                target: targets.protein,
                percentage: progress.protein.percentage,
                unit: 'g',
                color: const Color(0xFF4A7C3E),
              ),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: _buildMacroCard(
                label: 'Carbs',
                consumed: progress.carbs.consumed,
                target: targets.carbs,
                percentage: progress.carbs.percentage,
                unit: 'g',
                color: const Color(0xFFC66301),
              ),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: _buildMacroCard(
                label: 'Fat',
                consumed: progress.fat.consumed,
                target: targets.fat,
                percentage: progress.fat.percentage,
                unit: 'g',
                color: const Color(0xFF6BA84F),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCaloriesCard({
    required double consumed,
    required double target,
    required double remaining,
    required int percentage,
  }) {
    final color = _progressColor(percentage);
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.1),
            AppColors.primaryGreen.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Calories',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.medium,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize20,
                        fontWeight: AppTypography.bold,
                        color: AppColors.primaryGreen,
                        fontFamily: 'Lato',
                      ),
                      children: [
                        TextSpan(text: consumed.toStringAsFixed(0)),
                        const TextSpan(
                          text: ' / ',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize16,
                            fontWeight: AppTypography.medium,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextSpan(
                          text: target.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const TextSpan(
                          text: ' kcal',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.medium,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing12,
                  vertical: AppSizes.spacing4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppSizes.radius20),
                ),
                child: Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.bold,
                    color: Colors.white,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radius4),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining: ${remaining.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.medium,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
              const Icon(
                Icons.local_fire_department,
                color: AppColors.primaryGreen,
                size: AppSizes.icon20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard({
    required String label,
    required double consumed,
    required double target,
    required int percentage,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: AppSizes.shadowBlur10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 50,
            width: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (percentage / 100).clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _progressColor(percentage),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize10,
                    fontWeight: AppTypography.semiBold,
                    color: color,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.bold,
                    color: color,
                    fontFamily: 'Lato',
                  ),
                  children: [
                    TextSpan(text: consumed.toStringAsFixed(1)),
                    TextSpan(
                      text: unit,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize10,
                        fontWeight: AppTypography.medium,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                ' /${target.toStringAsFixed(0)}$unit',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize10,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing2),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTypography.fontSize10,
              fontWeight: AppTypography.medium,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.errorColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.errorColor,
            size: AppSizes.icon20,
          ),
          const SizedBox(width: AppSizes.spacing8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: AppTypography.fontSize12,
                color: AppColors.errorColor,
                fontFamily: 'Lato',
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadData,
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                fontWeight: AppTypography.semiBold,
                color: AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlanSection() => const MealPlanWidget();

  Widget _buildNoTargetsPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.track_changes_outlined,
              size: AppSizes.icon80,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSizes.spacing16),
            const Text(
              'No targets set yet',
              style: TextStyle(
                fontSize: AppTypography.fontSize16,
                fontWeight: AppTypography.semiBold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing8),
            const Text(
              'Complete your health assessment to see your\nnutritional targets and daily progress here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.primaryGreen),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: AppTypography.semiBold,
              color: AppColors.primaryGreen,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }

  static final _emptyPlan = SubscriptionPlan(
    id: '',
    planCode: '',
    planName: 'Achievers',
    durationInDays: 30,
    price: 0,
    isActive: true,
  );
}

// Simple data holder for benefit rows — private to this file
class _Benefit {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Benefit(this.icon, this.title, this.subtitle);
}
