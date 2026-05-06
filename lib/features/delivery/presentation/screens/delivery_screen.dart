import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/serviceability_provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/menu_item.dart';
import '../../providers/menu_provider.dart';
import '../widgets/food_detail_popup.dart';
import '../widgets/location_view_sheet.dart';
import '../widgets/membership_popup.dart';
import 'checkout_screen.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _hasShownMembershipPopup = false;
  final bool _profileImageError = false;

  @override
  void initState() {
    super.initState();
    // Load profile data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
      _loadWalletBalance();
      _checkServiceability();
      _loadAllDishes();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onDishSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(allDishesProvider.notifier).setSearchQuery(value.trim());
    });
  }

  void _clearDishSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    ref.read(allDishesProvider.notifier).setSearchQuery('');
  }

  /// Refresh all data
  Future<void> _onRefresh() async {
    await Future.wait([
      _loadProfileData(),
      _loadWalletBalance(),
      _checkServiceability(),
      _loadAllDishes(),
    ]);
  }

  Future<void> _loadAllDishes() async {
    await ref.read(allDishesProvider.notifier).loadMenuItems();
  }


  /// Load user profile data
  Future<void> _loadProfileData() async {
    final authNotifier = ref.read(authProvider.notifier);
    await authNotifier.loadProfile();
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

  String _computeLocation(authState) {
    if ((authState.street as String).isNotEmpty) {
      final parts = (authState.street as String).split(',');
      final p2 = authState.pincode as String;
      //  final p3 = authState.buildingNameNumber as String;
      // return "${parts.first.trim()}, $p3, $p2";
      return "${parts.join(', ')}, $p2";
    }
    if ((authState.buildingNameNumber as String).isNotEmpty) {
      return authState.buildingNameNumber as String;
    }
    return 'Location';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final cartItems = ref.watch(cartProvider);
    final totalItems = ref.watch(cartTotalItemsProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);
    final location = _computeLocation(authState);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
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
                          //_buildHeader(),
                          _buildCompactHeader(authState, location),
                          const SizedBox(height: AppSizes.spacing8),
                          _buildServiceabilityBanner(),
                          //_buildBrowseByCategories(),
                          _buildDishSearchBar(),
                          _buildDishesSection(),
                          const SizedBox(height: AppSizes.spacing32),
                        ],
                      ),
                    ),
                    // Bottom padding so content isn't hidden behind cart bar
                    if (cartItems.isNotEmpty)
                      const SizedBox(height: AppSizes.spacing80),
                    const SizedBox(height: AppSizes.spacing32),
                  ],
                ),
              ),
            ),
            if (cartItems.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 60,
                child: _buildCartBar(totalItems, totalPrice),
              ),
          ],
        ),
      ),
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded,
                color: AppColors.errorColor, size: AppSizes.icon24),
            SizedBox(width: AppSizes.spacing8),
            Text(
              'Clear Cart',
              style: TextStyle(
                fontSize: AppTypography.fontSize18,
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove all items from your cart?',
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSizes.spacing16,
          0,
          AppSizes.spacing16,
          AppSizes.spacing16,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.spacing12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderColor),
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ref.read(cartProvider.notifier).clearCart();
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.spacing12),
                    decoration: BoxDecoration(
                      color: AppColors.errorColor,
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Clear Cart',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.semiBold,
                        color: Colors.white,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartBar(int totalItems, double totalPrice) {
    return Container(
      margin: const EdgeInsets.all(AppSizes.spacing16),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing20,
        vertical: AppSizes.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: AppSizes.shadowBlur20,
            offset: const Offset(0, -AppSizes.spacing4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.shopping_cart,
                color: Colors.white,
                size: AppSizes.icon28,
              ),
              if (totalItems > 0)
                Positioned(
                  right: -AppSizes.spacing6,
                  top: -AppSizes.spacing4,
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.spacing4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
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
                          color: AppColors.primaryGreen,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$totalItems ${totalItems == 1 ? AppStrings.item : AppStrings.items}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: Colors.white,
                    fontFamily: 'Lato',
                  ),
                ),
                Text(
                  '₹${totalPrice.toInt()}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.regular,
                    color: Colors.white,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
          // Delete cart icon
          GestureDetector(
            onTap: _showClearCartDialog,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: AppSizes.spacing8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: AppSizes.icon20,
              ),
            ),
          ),
          // Proceed to checkout
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CheckoutScreen(),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing16,
                vertical: AppSizes.spacing8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radius6),
              ),
              child: const Text(
                AppStrings.proceedToCheckout,
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.primaryGreen,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ),
        ],
      ),
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

  /// Open bottom sheet showing user's location on map
  void _openLocationMap() {
    final authState = ref.read(authProvider);
    final lat = authState.latitude;
    final lng = authState.longitude;

    if (lat == null || lng == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationViewSheet(
        latitude: lat,
        longitude: lng,
        address: _getUserLocation(),
      ),
    );
  }

  Widget _buildCompactHeader(authState, String location) {
    final firstName = (authState.name as String).isNotEmpty
        ? (authState.name as String).split(' ').first
        : 'User';
    final imgUrl = authState.imgUrl as String?;
    final hasValidUrl =
        imgUrl != null && imgUrl.isNotEmpty && !_profileImageError;

    return Row(
      children: [
        // Small avatar
        GestureDetector(
          //onTap: () => ref.read(mainNavIndexProvider.notifier).state = 1,
          child: hasValidUrl
              ? CircleAvatar(
            radius: 19,
            backgroundImage: NetworkImage(imgUrl),
            backgroundColor:
            AppColors.primaryGreen.withValues(alpha: 0.1),
          )
              : CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.primaryGreen,
            child: Text(
              firstName[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Name + location
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey, $firstName! 👋',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize18,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: _openLocationMap,
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 11,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Lato',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // FitKhao Plus badge
        GestureDetector(
          onTap: _showMembershipPopupOnDemand,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A7C3E), Color(0xFF6BA84F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSizes.radius16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/buttonshit_logo.png',
                  height: 13,
                  width: 13,
                ),
                const SizedBox(width: 4),
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
    );
  }  // ─── Dish Search Bar ─────────────────────────────────────────────────────

  Widget _buildDishSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: AppSizes.shadowBlur10,
              offset: const Offset(0, AppSizes.spacing2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onDishSearchChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
          decoration: InputDecoration(
            hintText: 'Search dishes...',
            hintStyle: const TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textTertiary,
              fontFamily: 'Lato',
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
              size: AppSizes.icon20,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (_, value, __) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: _clearDishSearch,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSizes.spacing12),
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: AppSizes.icon20,
                    ),
                  ),
                );
              },
            ),
            border: InputBorder.none,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: AppSizes.borderMedium,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing16,
              vertical: AppSizes.spacing12,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Dishes Section ──────────────────────────────────────────────────────

  Widget _buildDishesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterChips(),
        _buildDishList(),
      ],
    );
  }

  Widget _buildFilterChips() {
    final dishState = ref.watch(allDishesProvider);
    if (dishState.isLoading || dishState.allItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final categories = dishState.categories;
    final selectedCatId = dishState.selectedCategoryId;
    final selectedType = dishState.selectedDishType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(
                  label: 'All',
                  isSelected: selectedCatId == null,
                  onTap: () =>
                      ref.read(allDishesProvider.notifier).setCategoryFilter(null),
                ),
                ...categories.map(
                  (cat) => _chip(
                    label: cat.name,
                    isSelected: selectedCatId == cat.id,
                    onTap: () => ref
                        .read(allDishesProvider.notifier)
                        .setCategoryFilter(cat.id),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
        ],
        Row(
          children: [
            _chip(
              label: 'All',
              isSelected: selectedType == 'all',
              onTap: () =>
                  ref.read(allDishesProvider.notifier).setDishTypeFilter('all'),
            ),
            const SizedBox(width: AppSizes.spacing8),
            _chip(
              label: 'Veg',
              isSelected: selectedType == 'veg',
              dotColor: const Color(0xFF388E3C),
              onTap: () =>
                  ref.read(allDishesProvider.notifier).setDishTypeFilter('veg'),
            ),
            const SizedBox(width: AppSizes.spacing8),
            _chip(
              label: 'Non-Veg',
              isSelected: selectedType == 'non-veg',
              dotColor: const Color(0xFFD32F2F),
              onTap: () => ref
                  .read(allDishesProvider.notifier)
                  .setDishTypeFilter('non-veg'),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacing12),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? dotColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: AppSizes.spacing8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing12,
          vertical: AppSizes.spacing6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
                : AppColors.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: AppSizes.spacing8,
                height: AppSizes.spacing8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSizes.spacing4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                fontWeight: isSelected
                    ? AppTypography.semiBold
                    : AppTypography.regular,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishList() {
    final dishState = ref.watch(allDishesProvider);

    if (dishState.isLoading) return _buildDishListSkeleton();

    if (dishState.error != null && dishState.allItems.isEmpty) {
      return _buildDishListError(dishState.error!);
    }

    final items = dishState.filteredItems;

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.no_meals_outlined,
              size: AppSizes.icon48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              dishState.allItems.isEmpty
                  ? 'No items available'
                  : 'No items match the selected filters',
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...items.map((item) => _buildDishCard(item)),
        if (dishState.isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.spacing16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          )
        else if (dishState.canLoadMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.spacing12),
            child: GestureDetector(
              onTap: () => ref.read(allDishesProvider.notifier).loadMore(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSizes.spacing12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryGreen),
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Load More',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.primaryGreen,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDishListSkeleton() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
          height: 96,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
        ),
      ),
    );
  }

  Widget _buildDishListError(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.errorColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.errorColor, size: AppSizes.icon20),
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
            onTap: _loadAllDishes,
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

  Widget _buildDishCard(MenuItem item) {
    final isInCart = ref.watch(cartProvider.notifier).isInCart(item.id);
    final isAvailable = item.isAvailable;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
      child: GestureDetector(
        onTap: isAvailable
            ? () => showDialog(
                  context: context,
                  builder: (_) => FoodDetailPopup(menuItem: item),
                )
            : null,
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radius8),
                border: Border.all(color: AppColors.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: AppSizes.shadowBlur10,
                    offset: const Offset(0, AppSizes.spacing2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                    child: Image.network(
                      item.imageUrl,
                      width: AppSizes.icon120,
                      height: AppSizes.icon120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: AppSizes.icon60,
                        height: AppSizes.icon60,
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.restaurant,
                          size: AppSizes.icon32,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacing12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + veg indicator
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: AppTypography.fontSize14,
                                  fontWeight: AppTypography.semiBold,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'Lato',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSizes.spacing6),
                            Container(
                              width: AppSizes.spacing12,
                              height: AppSizes.spacing12,
                              margin:
                                  const EdgeInsets.only(top: AppSizes.spacing2),
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                border: Border.all(
                                  color: item.isVeg
                                      ? const Color(0xFF388E3C)
                                      : const Color(0xFFD32F2F),
                                  width: AppSizes.borderNormal,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: AppSizes.spacing6,
                                  height: AppSizes.spacing6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: item.isVeg
                                        ? const Color(0xFF388E3C)
                                        : const Color(0xFFD32F2F),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.spacing4),
                        // Calories + rating
                        Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              size: AppSizes.icon12,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: AppSizes.spacing2),
                            Text(
                              '${item.calories} kcal',
                              style: const TextStyle(
                                fontSize: AppTypography.fontSize12,
                                color: AppColors.textSecondary,
                                fontFamily: 'Lato',
                              ),
                            ),
                            if (item.rating > 0) ...[
                              const SizedBox(width: AppSizes.spacing8),
                              const Icon(Icons.star,
                                  size: AppSizes.icon12, color: Colors.amber),
                              const SizedBox(width: AppSizes.spacing2),
                              Text(
                                item.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: AppTypography.fontSize12,
                                  fontWeight: AppTypography.medium,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'Lato',
                                ),
                              ),
                              if (item.ratingCount > 0)
                                Text(
                                  ' (${item.ratingCount})',
                                  style: const TextStyle(
                                    fontSize: AppTypography.fontSize10,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSizes.spacing4),
                        // Macros row
                        Row(
                          children: [
                            _buildMacroChip(
                                'P', item.protein, const Color(0xFF4A7C3E)),
                            const SizedBox(width: AppSizes.spacing6),
                            _buildMacroChip(
                                'C', item.carbs, const Color(0xFFC66301)),
                            const SizedBox(width: AppSizes.spacing6),
                            _buildMacroChip(
                                'F', item.fats, const Color(0xFF6BA84F)),
                          ],
                        ),
                        const SizedBox(height: AppSizes.spacing6),
                        // Price + Add button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Price
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '₹${item.price.toInt()}',
                                  style: const TextStyle(
                                    fontSize: AppTypography.fontSize16,
                                    fontWeight: AppTypography.bold,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                                if (item.discountPrice != null &&
                                    item.marketPrice > item.discountPrice!) ...[
                                  const SizedBox(width: AppSizes.spacing4),
                                  Text(
                                    '₹${item.marketPrice.toInt()}',
                                    style: const TextStyle(
                                      fontSize: AppTypography.fontSize10,
                                      color: AppColors.textTertiary,
                                      fontFamily: 'Lato',
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Add button
                            GestureDetector(
                              onTap: isAvailable
                                  ? () => showDialog(
                                        context: context,
                                        builder: (_) =>
                                            FoodDetailPopup(menuItem: item),
                                      )
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.spacing16,
                                  vertical: AppSizes.spacing4,
                                ),
                                decoration: BoxDecoration(
                                  color: isInCart
                                      ? AppColors.primaryGreen
                                          .withValues(alpha: 0.1)
                                      : AppColors.primaryGreen,
                                  borderRadius:
                                      BorderRadius.circular(AppSizes.radius4),
                                  border: Border.all(
                                    color: AppColors.primaryGreen,
                                    width: AppSizes.borderThin,
                                  ),
                                ),
                                child: Text(
                                  isInCart ? AppStrings.added : AppStrings.add,
                                  style: TextStyle(
                                    fontSize: AppTypography.fontSize12,
                                    fontWeight: AppTypography.semiBold,
                                    color: isInCart
                                        ? AppColors.primaryGreen
                                        : Colors.white,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Disabled overlay for unavailable items
            if (!isAvailable)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.78),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.spacing12,
                          vertical: AppSizes.spacing6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radius20),
                        ),
                        child: const Text(
                          'Currently Unavailable',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Lato',
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing6,
        vertical: AppSizes.spacing2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: AppTypography.fontSize10,
          fontWeight: AppTypography.medium,
          color: color,
          fontFamily: 'Lato',
        ),
      ),
    );
  }
}
