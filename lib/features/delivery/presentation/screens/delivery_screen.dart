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
import '../widgets/membership_popup.dart';
import 'menu_list_screen.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Mock data for goals (will be replaced with real data later)
  final int todaysGoalKcal = 1100;
  final String selectedGoal = AppStrings.leanMassGain;

  bool _isProfileLoaded = false;
  bool _hasShownMembershipPopup = false;
  bool _trendingLoaded = false;

  @override
  void initState() {
    super.initState();
    // Load profile data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
      _loadWalletBalance();
      _loadTrending();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    if (_trendingLoaded) return;
    final notifier = ref.read(trendingProvider.notifier);
    await notifier.load(
      kitchenId: '691249acdcddaf162cea0e7a',
      timeSlot: 'morning',
      limit: 5,
    );
    if (mounted) setState(() => _trendingLoaded = true);
  }

  /// Load user profile data
  Future<void> _loadProfileData() async {
    if (_isProfileLoaded) return;

    final authNotifier = ref.read(authProvider.notifier);
    await authNotifier.loadProfile();

    if (mounted) {
      setState(() {
        _isProfileLoaded = true;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.screenPaddingHorizontal,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSizes.spacing16),
                    _buildHeader(),
                    const SizedBox(height: AppSizes.spacing8),
                    _trackSubscription(),
                    // const SizedBox(height: AppSizes.spacing16),
                    // _buildSearchBar(),
                    const SizedBox(height: AppSizes.spacing12),
                    _buildDailyGoalCard(),
                    const SizedBox(height: AppSizes.spacing12),
                    _buildTodaysGoalSection(),
                    // const SizedBox(height: AppSizes.spacing24),
                    // _buildCompleteYourMealButton(),
                    const SizedBox(height: AppSizes.spacing16),
                    _buildBrowseByCategories(),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.spacing16),
              _buildTrendingNow(),
              const SizedBox(height: AppSizes.spacing32),
              const SizedBox(height: AppSizes.spacing32),
              const SizedBox(height: AppSizes.spacing32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trackSubscription(){
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
      child:
      Text(
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
                  fontSize: AppTypography.fontSize24,
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
                  Text(
                    _getUserLocation(),
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.regular,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
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
              backgroundImage:  NetworkImage(
                ref.watch(authProvider).imgUrl??"https://i.sstatic.net/l60Hf.png",
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
                      Row(
                        children: [
                          const Text(
                            AppStrings.dailyGoal,
                            style: TextStyle(
                              fontSize: AppTypography.fontSize18,
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
                              selectedGoal,
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
                          fontSize: AppTypography.fontSize13,
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              AppStrings.todaysGoal,
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
              child: const Text(
                '18th November',
                style: TextStyle(
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
        Row(
          children: [
            SizedBox(
              width: AppSizes.containerHeightSmall70,
              height: AppSizes.containerHeightSmall70,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 0.27, // 27% progress (300/1100)
                    strokeWidth: AppSizes.spacing8,
                    backgroundColor: AppColors.borderColor.withValues(
                      alpha: 0.3,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.spacing20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize20,
                        fontWeight: AppTypography.regular,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                      children: [
                        TextSpan(text: '$todaysGoalKcal'),
                        const TextSpan(
                          text: ' ${AppStrings.kcal}',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize12,
                            fontWeight: AppTypography.regular,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing4),
                  const Text(
                    AppStrings.leftFor,
                    style: TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.regular,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  Row(
                    children: [
                      _buildMealButton(AppStrings.lunch, Icons.lunch_dining),
                      const SizedBox(width: AppSizes.spacing8),
                      _buildMealButton(AppStrings.dinner, Icons.dinner_dining),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMealButton(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing12,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(AppSizes.radius4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: AppSizes.icon16),
          const SizedBox(width: AppSizes.spacing6),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTypography.fontSize12,
              fontWeight: AppTypography.medium,
              color: Colors.white,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildBrowseByCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: AppSizes.spacing16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCategoryCard(AppStrings.breakfast),
            _buildCategoryCard(AppStrings.lunch),
            _buildCategoryCard(AppStrings.dinner),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String category) {
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
        width:
            (MediaQuery.of(context).size.width -
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
                  'https://www.shutterstock.com/image-photo/fried-salmon-steak-cooked-green-600nw-2489026949.jpg',
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

  Widget _buildTrendingNow() {
    final trendingState = ref.watch(trendingProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: AppSizes.p20),
          child: const Text(
            AppStrings.trendingNow,
            style: TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spacing16),
        SizedBox(
          height: 160,
          child: trendingState.when(
            loading: () => ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, index) => _buildTrendingSkeleton(),
            ),
            error: (e, _) => Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.p20),
              child: Text(
                e.toString(),
                style: const TextStyle(color: AppColors.errorColor),
              ),
            ),
            data: (items) => ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) => _buildTrendingItem(
                items[index].itemName,
                items[index].avgPrice,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingItem(String title, double price) {
    return Padding(
      padding: EdgeInsets.only(left: AppSizes.p20),
      child: Container(
        width: 160,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 100,
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
                  'https://img.freepik.com/free-photo/top-view-table-full-food_23-2149209253.jpg?semt=ais_hybrid&w=740&q=80',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.semiBold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.spacing4),
                  Text(
                    '₹ ${price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize12,
                      fontWeight: AppTypography.medium,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingSkeleton() {
    return Padding(
      padding: EdgeInsets.only(left: AppSizes.p20),
      child: Container(
        width: 160,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.radius4),
                  topRight: Radius.circular(AppSizes.radius4),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(AppSizes.spacing8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12, width: 100),
                  SizedBox(height: AppSizes.spacing4),
                  SizedBox(height: 10, width: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
