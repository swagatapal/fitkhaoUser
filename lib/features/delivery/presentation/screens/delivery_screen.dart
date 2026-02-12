import 'package:fitkhao_user/features/delivery/presentation/widgets/assign_meal_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/trending_provider.dart';
import '../../providers/serviceability_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/meal_plan_nutrition_provider.dart';
import '../widgets/membership_popup.dart';
import '../widgets/delivery_slot_selector.dart';
import 'menu_list_screen.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _hasShownMembershipPopup = false;
  bool _isProfileLoading = true;

  @override
  void initState() {
    super.initState();
    // Load profile data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeScreen();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isProfileLoading = true;
    });

    final walletFuture = _loadWalletBalance();
    final nutritionFuture = _loadNutritionProgress();

    await _loadProfileData();

    if (!mounted) return;
    setState(() {
      _isProfileLoading = false;
    });

    await Future.wait([
      walletFuture,
      nutritionFuture,
      _checkServiceability(),
      //_loadTrending(),
    ]);
  }

  /// Refresh all data
  Future<void> _onRefresh() async {
    setState(() {
      _isProfileLoading = true;
    });

    final walletFuture = _loadWalletBalance();
    final nutritionFuture = _loadNutritionProgress();

    await _loadProfileData();

    if (!mounted) return;
    setState(() {
      _isProfileLoading = false;
    });

    await Future.wait([
      walletFuture,
      nutritionFuture,
      _checkServiceability(),
      //_loadTrending(),
    ]);
  }

  // ignore: unused_element
  Future<void> _loadTrending() async {
    final notifier = ref.read(trendingProvider.notifier);
    await notifier.load(
      kitchenId: '69275ba5c538faaf25e2acd1',
      timeSlot: 'morning',
      limit: 10,
    );
  }

  /// Load user profile data
  Future<bool> _loadProfileData() async {
    final authNotifier = ref.read(authProvider.notifier);
    return await authNotifier.loadProfile();
  }

  /// Load wallet balance and subscription info
  Future<void> _loadWalletBalance() async {
    final walletNotifier = ref.read(walletProvider.notifier);
    await walletNotifier.loadWalletBalance();

    // Show membership popup only if no active subscription
    if (mounted) {
      final walletState = ref.read(walletProvider);
      if (!walletState.hasActiveSubscription) {
        _showMembershipPopup();
      }
    }
  }

  /// Check if delivery is serviceable for user's location
  Future<void> _checkServiceability() async {
    final authState = ref.read(authProvider);

    // Only check if we have valid coordinates
    if (authState.latitude != null && authState.longitude != null) {
      final serviceabilityNotifier = ref.read(serviceabilityProvider.notifier);
      await serviceabilityNotifier.checkServiceability(
        latitude: authState.latitude!,
        longitude: authState.longitude!,
      );
    }
  }

  /// Load nutrition progress data
  Future<void> _loadNutritionProgress() async {
    final progressNotifier = ref.read(nutritionProgressProvider.notifier);
    await progressNotifier.getDailyNutritionProgress();
  }

  /// Show membership popup on first load
  void _showMembershipPopup() {
    if (!_hasShownMembershipPopup && mounted) {
      _hasShownMembershipPopup = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.transparent,
            builder: (context) => const MembershipPopup(),
          );
        }
      });
    }
  }

  /// Show membership popup when button is clicked
  void _showMembershipPopupOnDemand() {
    final walletState = ref.read(walletProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => MembershipPopup(
        subscription: walletState.subscription,
      ),
    );
  }

  /// Extract user location from address
  String _getUserLocation() {
    final authState = ref.watch(authProvider);

    // Try to get area or street
    if (authState.street.isNotEmpty) {
      // If street contains comma, get the first part
      final parts = authState.street.split(',');
      final p2 = authState.pincode;
      final p3 = authState.buildingNameNumber;
      //String address =
      return "${parts.first.trim()}, $p3, $p2";
    }

    // Fallback to building name
    if (authState.buildingNameNumber.isNotEmpty) {
      return authState.buildingNameNumber;
    }

    // Final fallback
    return 'Location';
  }

  /// Check if nutritional targets are available to show Today's Goal section
  bool _shouldShowTodaysGoal() {
    final authState = ref.watch(authProvider);
    return authState.targetProtein != null &&
        authState.targetFat != null &&
        authState.targetCarbs != null &&
        authState.targetKCalories != null;
  }

  /// Get formatted selected goal name
  String _getSelectedGoalName() {
    final authState = ref.watch(authProvider);
    final goal = authState.selectedGoal;

    // Map goal codes to display names
    switch (goal) {
      case 'fat-loss':
        return 'Fat Loss';
      case 'lean-mass-gain':
        return 'Lean Mass Gain';
      case 'muscle-gain':
        return 'Muscle Gain';
      case 'regular-bmi-maintenance':
        return 'BMI Maintenance';
      default:
        return goal.isNotEmpty ? goal : AppStrings.leanMassGain;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.userId ?? '';
    final showTodaysGoal = _shouldShowTodaysGoal();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primaryGreen,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPaddingHorizontal,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSizes.spacing4),
                      _buildHeader(),
                      const SizedBox(height: AppSizes.spacing8),
                      _buildServiceabilityBanner(),
                      _trackSubscription(),
                      // const SizedBox(height: AppSizes.spacing16),
                      // _buildSearchBar(),
                      const SizedBox(height: AppSizes.spacing12),
                      _buildDailyGoalCard(),
                      const SizedBox(height: AppSizes.spacing12),
                      const DeliverySlotSelector(),
                      if (showTodaysGoal) _buildTodaysGoalSection(),
                      if (showTodaysGoal)
                        const SizedBox(height: AppSizes.spacing12),
                      // const SizedBox(height: AppSizes.spacing24),
                      // _buildCompleteYourMealButton(),
                      // const SizedBox(height: AppSizes.spacing16),
                      // _buildBrowseByCategories(),
                      _buildMealPlanSection(userId, authState.errorMessage),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spacing16),
                // _buildTrendingNow(),
                const SizedBox(height: AppSizes.spacing32),
                const SizedBox(height: AppSizes.spacing32),
                const SizedBox(height: AppSizes.spacing32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealPlanSection(String userId, String? profileError) {
    if (_isProfileLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: AppColors.primaryGreen),
              SizedBox(height: AppSizes.spacing12),
              Text(
                'Loading profile...',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (userId.trim().isEmpty) {
      final message = profileError?.trim().isNotEmpty == true
          ? profileError!.trim()
          : 'Failed to load profile. Please try again.';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing24),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.errorColor,
              size: 48,
            ),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            PrimaryButton(
              text: 'Retry',
              onPressed: () async {
                setState(() {
                  _isProfileLoading = true;
                });

                await _loadProfileData();

                if (!mounted) return;
                setState(() {
                  _isProfileLoading = false;
                });

                await _checkServiceability();
              },
              backgroundColor: AppColors.primaryGreen,
              width: 160,
              height: 44,
            ),
          ],
        ),
      );
    }

    return MealPlanWidget(
      key: ValueKey(userId),
      userId: userId,
    );
  }

  Widget _buildServiceabilityBanner() {
    final serviceabilityState = ref.watch(serviceabilityProvider);

    // Only show banner if serviceability check is complete and location is not serviceable
    if (serviceabilityState.isServiceable == false) {
      return Container(
        width: MediaQuery.of(context).size.width,
        margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing16,
          vertical: AppSizes.spacing12,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD32F2F), Color(0xFFC62828)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_rounded,
              color: Colors.white,
              size: AppSizes.icon24,
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Not Available',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.bold,
                      color: Colors.white,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing4),
                  Text(
                    'Sorry, we cannot deliver food to your current address. Please check if you are in a serviceable area.',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      fontWeight: AppTypography.regular,
                      color: Colors.white.withValues(alpha: 0.9),
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

    // Don't show anything if serviceable or still checking
    return const SizedBox.shrink();
  }

  Widget _trackSubscription() {
    final subscription = ref.watch(walletProvider).subscription;
    final wallet = ref.watch(walletProvider).wallet;
    if (subscription == null) return const SizedBox.shrink();
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing12,
        vertical: AppSizes.spacing6,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A7C3E), Color(0xFF6BA84F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'Available balance : ${wallet?.couponBalance.toStringAsFixed(2)} (${subscription.remainingDays} Days Remaining)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AppTypography.fontSize12,
          fontWeight: AppTypography.semiBold,
          color: Colors.white.withValues(alpha: 0.9),
          fontFamily: 'Lato',
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppStrings.greetings} ${ref.watch(authProvider).name.isNotEmpty ? ref.watch(authProvider).name : 'User'},',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize20,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: AppSizes.icon16,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: AppSizes.spacing4),
                  Expanded(
                    child: Text(
                      _getUserLocation(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize13,
                        fontWeight: AppTypography.regular,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          children: [
            // Profile Avatar
            CircleAvatar(
              radius: AppSizes.spacing28,
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
              backgroundImage: NetworkImage(
                ref.watch(authProvider).imgUrl ??
                    "https://i.sstatic.net/l60Hf.png",
              ),
              onBackgroundImageError: (exception, stackTrace) {},
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.3),
                    width: AppSizes.borderThin,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spacing4),
            // FitKhao Plus Badge
            GestureDetector(
              onTap: _showMembershipPopupOnDemand,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing12,
                  vertical: AppSizes.spacing4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A7C3E), Color(0xFF6BA84F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radius16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/buttonshit_logo.png',
                      height: AppSizes.icon16,
                      width: AppSizes.icon16,
                    ),
                    const SizedBox(width: AppSizes.spacing4),
                    const Text(
                      'Plus',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.bold,
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
      ],
    );
  }

  // ignore: unused_element
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border: Border.all(
          color: AppColors.textWhite,
          width: AppSizes.borderMedium,
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppStrings.searchFood,
          hintStyle: const TextStyle(
            fontSize: AppTypography.fontSize14,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textSecondary,
            size: AppSizes.icon24,
          ),
          suffixIcon: IconButton(
            icon: const Icon(
              Icons.mic,
              color: AppColors.primaryGreen,
              size: AppSizes.icon24,
            ),
            onPressed: () {
              // TODO: Implement voice search
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16,
            vertical: AppSizes.spacing12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius4),
            borderSide: const BorderSide(
              color: AppColors.borderColor,
              width: AppSizes.borderMedium,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius4),
            borderSide: const BorderSide(
              color: AppColors.primaryGreen,
              width: AppSizes.borderMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyGoalCard() {
    return Container(
      //padding: const EdgeInsets.all(AppSizes.spacing20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A7C3E), Color(0xFF6BA84F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            child: Image.asset(
              "assets/images/header_bg.png",
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSizes.spacing16),
            child: Row(
              children: [
                Image.asset(
                  "assets/images/logo_1.png",
                  height: AppSizes.logoHeight,
                  width: AppSizes.logoWidth,
                ),
                const SizedBox(width: AppSizes.spacing8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        children: [
                          const Text(
                            AppStrings.dailyGoal,
                            style: TextStyle(
                              fontSize: AppTypography.fontSize14,
                              fontWeight: AppTypography.bold,
                              color: Colors.white,
                              fontFamily: 'Lato',
                            ),
                          ),
                          const SizedBox(width: AppSizes.spacing8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.spacing8,
                              vertical: AppSizes.spacing2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radius20,
                              ),
                            ),
                            child: Text(
                              _getSelectedGoalName(),
                              style: const TextStyle(
                                fontSize: AppTypography.fontSize12,
                                fontWeight: AppTypography.medium,
                                color: Colors.white,
                                fontFamily: 'Lato',
                              ),
                            ),
                          ),
                          // IconButton(
                          //   icon: const Icon(
                          //     Icons.edit,
                          //     color: Colors.white,
                          //     size: AppSizes.icon20,
                          //   ),
                          //   onPressed: () {
                          //     // TODO: Implement edit goal
                          //   },
                          // ),
                        ],
                      ),
                      // const SizedBox(height: AppSizes.spacing8),
                      const Text(
                        AppStrings.recommendedIntake,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize12,
                          fontWeight: AppTypography.medium,
                          color: Colors.white,
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacing2),
                      const Text(
                        AppStrings.targetDailyKcal,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize12,
                          fontWeight: AppTypography.regular,
                          color: Colors.white,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysGoalSection() {
    final authState = ref.watch(authProvider);
    final lastUpdated = authState.lastUpdatedTargetKCal;

    // Format last updated date
    String formattedDate = '18th November';
    if (lastUpdated != null) {
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      final day = lastUpdated.day;
      final suffix = day == 1 || day == 21 || day == 31
          ? 'st'
          : (day == 2 || day == 22
              ? 'nd'
              : (day == 3 || day == 23 ? 'rd' : 'th'));
      formattedDate = '$day$suffix ${months[lastUpdated.month - 1]}';
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                "Last updated $formattedDate",
                style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.medium,
                  color: Colors.white,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacing12),

        // Nutrition Progress Section
        _buildNutritionProgressSection(),

        //const SizedBox(height: AppSizes.spacing16),

        // Macronutrient Breakdown
        // Row(
        //   children: [
        //     Expanded(
        //       child: _buildMacroCard(
        //         label: 'Protein',
        //         value: targetProtein,
        //         unit: 'g',
        //         color: const Color(0xFF4A7C3E),
        //         icon: Icons.fitness_center,
        //       ),
        //     ),
        //     const SizedBox(width: AppSizes.spacing12),
        //     Expanded(
        //       child: _buildMacroCard(
        //         label: 'Carbs',
        //         value: targetCarbs,
        //         unit: 'g',
        //         color: const Color(0xFFC66301),
        //         icon: Icons.bakery_dining,
        //       ),
        //     ),
        //     const SizedBox(width: AppSizes.spacing12),
        //     Expanded(
        //       child: _buildMacroCard(
        //         label: 'Fat',
        //         value: targetFat,
        //         unit: 'g',
        //         color: const Color(0xFF6BA84F),
        //         icon: Icons.water_drop,
        //       ),
        //     ),
        //   ],
        // ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildMacroCard({
    required String label,
    required double value,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
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
          // Icon(
          //   icon,
          //   color: color,
          //   size: AppSizes.icon24,
          // ),
          // const SizedBox(height: AppSizes.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: AppSizes.icon16,
              ),
              const SizedBox(width: AppSizes.spacing4),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.medium,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing4),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: AppTypography.fontSize18,
                fontWeight: AppTypography.bold,
                color: color,
                fontFamily: 'Lato',
              ),
              children: [
                TextSpan(text: value.toStringAsFixed(0)),
                TextSpan(
                  text: unit,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.medium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionProgressSection() {
    final progressState = ref.watch(nutritionProgressProvider);
    final mealPlanNutrition = ref.watch(mealPlanNutritionProvider);

    if (progressState.isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryGreen,
          ),
        ),
      );
    }

    if (progressState.progressData == null) {
      return const SizedBox.shrink();
    }

    final data = progressState.progressData!;
    final targets = data.targets;
    final progress = data.progress;

    return Column(
      children: [
        // Calories Progress Card
        Container(
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
              width: 1,
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
                            TextSpan(
                                text: progress.calories.consumed
                                    .toStringAsFixed(0)),
                            const TextSpan(
                              text: ' / ',
                              style: TextStyle(
                                fontSize: AppTypography.fontSize16,
                                fontWeight: AppTypography.medium,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            TextSpan(
                              text: targets.calories.toStringAsFixed(0),
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
                      color: _getProgressColor(progress.calories.percentage),
                      borderRadius: BorderRadius.circular(AppSizes.radius20),
                    ),
                    child: Text(
                      '${progress.calories.percentage}%',
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
                  value: progress.calories.percentage / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(progress.calories.percentage),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remaining: ${progress.calories.remaining.toStringAsFixed(0)} kcal',
                    style: TextStyle(
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
              if (mealPlanNutrition.totalKcal > 0) ...[
                const SizedBox(height: AppSizes.spacing8),
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.primaryGreen,
                        size: AppSizes.icon16,
                      ),
                      const SizedBox(width: AppSizes.spacing8),
                      Expanded(
                        child: Text(
                          'Meal Plan: ${mealPlanNutrition.totalKcal.toStringAsFixed(0)} kcal',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize12,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.primaryGreen,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),

        // Macronutrients Progress
        Row(
          children: [
            Expanded(
              child: _buildMacroProgressCard(
                label: 'Protein',
                consumed: progress.protein.consumed,
                target: targets.protein,
                percentage: progress.protein.percentage,
                mealPlanValue: mealPlanNutrition.totalProtein,
                unit: 'g',
                color: const Color(0xFF0e9630),
                icon: Icons.fitness_center,
              ),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: _buildMacroProgressCard(
                label: 'Carbs',
                consumed: progress.carbs.consumed,
                target: targets.carbs,
                percentage: progress.carbs.percentage,
                mealPlanValue: mealPlanNutrition.totalCarbs,
                unit: 'g',
                color: const Color(0xFF300e96),
                icon: Icons.bakery_dining,
              ),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: _buildMacroProgressCard(
                label: 'Fat',
                consumed: progress.fat.consumed,
                target: targets.fat,
                percentage: progress.fat.percentage,
                mealPlanValue: mealPlanNutrition.totalFat,
                unit: 'g',
                color: const Color(0xFF0e9196),
                icon: Icons.water_drop,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroProgressCard({
    required String label,
    required double consumed,
    required double target,
    required int percentage,
    required double mealPlanValue,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
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
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: [
          //     Icon(
          //       icon,
          //       color: color,
          //       size: AppSizes.icon16,
          //     ),
          //     const SizedBox(width: AppSizes.spacing4),
          //     Text(
          //       label,
          //       style: TextStyle(
          //         fontSize: AppTypography.fontSize12,
          //         fontWeight: AppTypography.semiBold,
          //         color: AppColors.textPrimary,
          //         fontFamily: 'Lato',
          //       ),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: AppSizes.spacing8),

          // Circular progress indicator
          SizedBox(
            height: 50,
            width: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(percentage),
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

          // const SizedBox(height: AppSizes.spacing8),

          // Consumed / Target
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
                style: TextStyle(
                  fontSize: AppTypography.fontSize10,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
          if (mealPlanValue > 0) ...[
            const SizedBox(height: AppSizes.spacing4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing6,
                vertical: AppSizes.spacing2,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radius4),
              ),
              child: Text(
                'Plan: ${mealPlanValue.toStringAsFixed(1)}$unit',
                style: TextStyle(
                  fontSize: AppTypography.fontSize10,
                  fontWeight: AppTypography.semiBold,
                  color: color,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getProgressColor(int percentage) {
    if (percentage >= 100) {
      return const Color(0xFFD32F2F); // Red for exceeded
    } else if (percentage >= 80) {
      return const Color(0xFFFF9800); // Orange for warning
    } else if (percentage >= 50) {
      return const Color(0xFF4A7C3E); // Green for good progress
    } else {
      return const Color(0xFF6BA84F); // Light green for low progress
    }
  }

  // ignore: unused_element
  Widget _buildCompleteYourMealButton() {
    return PrimaryButton(
      text: AppStrings.completeYourMeal,
      onPressed: () {
        // TODO: Navigate to meal selection
      },
      backgroundColor: AppColors.primaryGreen,
      textColor: Colors.white,
      height: AppSizes.buttonHeight,
    );
  }

  // ignore: unused_element
  Widget _buildBrowseByCategories() {
    final serviceabilityState = ref.read(serviceabilityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              AppStrings.browseByCategories,
              style: TextStyle(
                fontSize: AppTypography.fontSize16,
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
            Consumer(
              builder: (context, ref, child) {
                final totalItems = ref.watch(cartTotalItemsProvider);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.shopping_cart,
                      color: AppColors.darkGreen,
                      size: 20,
                    ),
                    if (totalItems > 0)
                      Positioned(
                        right: -AppSizes.spacing6,
                        top: -AppSizes.spacing4,
                        child: Container(
                          padding: const EdgeInsets.all(AppSizes.spacing4),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: AppSizes.spacing16,
                            minHeight: AppSizes.spacing16,
                          ),
                          child: Center(
                            child: Text(
                              totalItems.toString(),
                              style: const TextStyle(
                                fontSize: AppTypography.fontSize10,
                                fontWeight: AppTypography.bold,
                                color: Colors.white,
                                fontFamily: 'Lato',
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            )
          ],
        ),
        const SizedBox(height: AppSizes.spacing12),
        Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCategoryCard(AppStrings.breakfast,
                    "https://img.freepik.com/premium-photo/breakfast-buffet-full-continental-english_79295-5883.jpg?semt=ais_hybrid&w=740&q=80"),
                _buildCategoryCard(AppStrings.lunch,
                    "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQUfmoU1yzh652_lP_nyxMeEFMqA6_QaYb-5A&s"),
                _buildCategoryCard(AppStrings.dinner,
                    "https://media.istockphoto.com/id/868408746/photo/assorted-indian-dish.jpg?s=612x612&w=0&k=20&c=XLsAk571Z2kEe_x6TnXWSzsG95-2agp-TcYswQrKHuo="),
              ],
            ),
            Visibility(
              visible:
                  serviceabilityState.isServiceable == false ? true : false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.2,
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    "Delivery Not Available",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textWhite),
                  ),
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String category, String categoryImage) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MenuListScreen(mealType: category),
          ),
        );
      },
      child: Container(
        width: (MediaQuery.of(context).size.width -
                (AppSizes.screenPaddingHorizontal * 2) -
                (AppSizes.spacing16 * 2)) /
            3,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: AppSizes.shadowBlur10,
              offset: const Offset(0, AppSizes.spacing4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: AppSizes.containerHeightMedium,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.radius4),
                  topRight: Radius.circular(AppSizes.radius4),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.radius4),
                  topRight: Radius.circular(AppSizes.radius4),
                ),
                child: Image.network(
                  categoryImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.restaurant,
                        size: AppSizes.icon48,
                        color: AppColors.primaryGreen,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.spacing8),
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildTrendingNow() {
  //   final trendingState = ref.watch(trendingProvider);
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Padding(
  //         padding: EdgeInsets.only(left: AppSizes.p20),
  //         child: const Text(
  //           AppStrings.trendingNow,
  //           style: TextStyle(
  //             fontSize: AppTypography.fontSize16,
  //             fontWeight: AppTypography.bold,
  //             color: AppColors.textPrimary,
  //             fontFamily: 'Lato',
  //           ),
  //         ),
  //       ),
  //       const SizedBox(height: AppSizes.spacing16),
  //       SizedBox(
  //         height: 160,
  //         child: trendingState.when(
  //           loading: () => ListView.builder(
  //             scrollDirection: Axis.horizontal,
  //             itemCount: 3,
  //             itemBuilder: (context, index) => _buildTrendingSkeleton(),
  //           ),
  //           error: (e, _) => Padding(
  //             padding: EdgeInsets.symmetric(horizontal: AppSizes.p20),
  //             child: Text(
  //               e.toString(),
  //               style: const TextStyle(color: AppColors.errorColor),
  //             ),
  //           ),
  //           data: (items) => ListView.builder(
  //             scrollDirection: Axis.horizontal,
  //             itemCount: items.length,
  //             itemBuilder: (context, index) => _buildTrendingItem(
  //               items[index].itemName,
  //               items[index].avgPrice,
  //             ),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }
  //
  // Widget _buildTrendingItem(String title, double price) {
  //   return Padding(
  //     padding: EdgeInsets.only(left: AppSizes.p20),
  //     child: Container(
  //       width: 160,
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(AppSizes.radius4),
  //         boxShadow: [
  //           BoxShadow(
  //             color: Colors.black.withValues(alpha: 0.05),
  //             blurRadius: AppSizes.shadowBlur10,
  //             offset: const Offset(0, AppSizes.spacing4),
  //           ),
  //         ],
  //       ),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Container(
  //             width: double.infinity,
  //             height: 100,
  //             decoration: BoxDecoration(
  //               color: AppColors.primaryGreen.withValues(alpha: 0.1),
  //               borderRadius: const BorderRadius.only(
  //                 topLeft: Radius.circular(AppSizes.radius4),
  //                 topRight: Radius.circular(AppSizes.radius4),
  //               ),
  //             ),
  //             child: ClipRRect(
  //               borderRadius: const BorderRadius.only(
  //                 topLeft: Radius.circular(AppSizes.radius4),
  //                 topRight: Radius.circular(AppSizes.radius4),
  //               ),
  //               child: Image.network(
  //                 'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg?semt=ais_hybrid&w=740&q=80',
  //                 fit: BoxFit.cover,
  //                 errorBuilder: (context, error, stackTrace) {
  //                   return Container(
  //                     color: AppColors.primaryGreen.withValues(alpha: 0.1),
  //                     child: const Icon(
  //                       Icons.restaurant,
  //                       size: AppSizes.icon48,
  //                       color: AppColors.primaryGreen,
  //                     ),
  //                   );
  //                 },
  //               ),
  //             ),
  //           ),
  //           Padding(
  //             padding: const EdgeInsets.all(AppSizes.spacing8),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   title,
  //                   style: const TextStyle(
  //                     fontSize: AppTypography.fontSize14,
  //                     fontWeight: AppTypography.semiBold,
  //                     color: AppColors.textPrimary,
  //                     fontFamily: 'Lato',
  //                   ),
  //                   maxLines: 1,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //                 const SizedBox(height: AppSizes.spacing4),
  //                 Text(
  //                   '₹ ${price.toStringAsFixed(0)}',
  //                   style: const TextStyle(
  //                     fontSize: AppTypography.fontSize12,
  //                     fontWeight: AppTypography.medium,
  //                     color: AppColors.textSecondary,
  //                     fontFamily: 'Lato',
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  //
  // Widget _buildTrendingSkeleton() {
  //   return Padding(
  //     padding: EdgeInsets.only(left: AppSizes.p20),
  //     child: Container(
  //       width: 160,
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(AppSizes.radius4),
  //         boxShadow: [
  //           BoxShadow(
  //             color: Colors.black.withValues(alpha: 0.05),
  //             blurRadius: AppSizes.shadowBlur10,
  //             offset: const Offset(0, AppSizes.spacing4),
  //           ),
  //         ],
  //       ),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Container(
  //             width: double.infinity,
  //             height: 100,
  //             decoration: BoxDecoration(
  //               color: AppColors.primaryGreen.withValues(alpha: 0.1),
  //               borderRadius: const BorderRadius.only(
  //                 topLeft: Radius.circular(AppSizes.radius4),
  //                 topRight: Radius.circular(AppSizes.radius4),
  //               ),
  //             ),
  //           ),
  //           const Padding(
  //             padding: EdgeInsets.all(AppSizes.spacing8),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 SizedBox(height: 12, width: 100),
  //                 SizedBox(height: AppSizes.spacing4),
  //                 SizedBox(height: 10, width: 60),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}
