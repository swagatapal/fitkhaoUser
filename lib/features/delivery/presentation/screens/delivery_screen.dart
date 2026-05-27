import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:fitkhao_user/core/router/app_router.dart';
import 'package:fitkhao_user/features/delivery/presentation/screens/subscription_plan_screen.dart';
import 'package:fitkhao_user/features/notification/presentation/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final VoidCallback? onNavigateToProfile;

  const DeliveryScreen({super.key, this.onNavigateToProfile});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  bool _hasShownMembershipPopup = false;
  final bool _profileImageError = false;
  bool _hasShownNoMoreDataPopup = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
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
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
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
    _hasShownNoMoreDataPopup = false;
    await ref.read(allDishesProvider.notifier).loadMenuItems();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final dishState = ref.read(allDishesProvider);

    // Reset popup flag when user scrolls back up
    if (position.pixels < position.maxScrollExtent - 120) {
      _hasShownNoMoreDataPopup = false;
      return;
    }

    // Trigger next-page load when near the bottom (both All & category views)
    if (dishState.canLoadMore) {
      ref.read(allDishesProvider.notifier).loadMore();
      return;
    }

    // Show "no more data" toast only once per view exhaustion
    final hasReachedEnd = dishState.items.isNotEmpty &&
        !dishState.isLoading &&
        !dishState.isLoadingMore &&
        !dishState.canLoadMore;

    if (hasReachedEnd && !_hasShownNoMoreDataPopup) {
      _hasShownNoMoreDataPopup = true;
      _showNoMoreDataPopup();
    }
  }

  void _showNoMoreDataPopup() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No more data found'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Ordering window ────────────────────────────────────────────────────────
  // PRODUCTION  : 11 AM – 1 AM (crosses midnight)
  //   → use ||  : hour >= 11 || hour < 1
  //     Logic: allowed on the 11–23 side OR the 0 (midnight) side.
  //
  // TESTING (same-day window, e.g. 11 AM – 11 PM):
  //   → use &&  : hour >= 11 && hour < 23
  //     Logic: both bounds must hold; no midnight crossing.
  //
  // RULE: window crosses midnight → ||   |   same-day window → &&
  // ───────────────────────────────────────────────────────────────────────────
  bool get _isOrderingAllowed {
    final hour = DateTime.now().hour;
    // PRODUCTION value (11 AM – 1 AM, crosses midnight):
    return hour >= 11 || hour < 1;
    // To test the closed-banner right now, swap to:
     //return hour >= 11 && hour < 23;  // closes at 11 PM
  }

  void _showOrderingClosedSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Ordering is available from 11:00 AM to 1:00 AM'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFC66301),
          duration: Duration(seconds: 3),
        ),
      );
  }

  Widget _buildOrderingTimeBanner() {
    if (_isOrderingAllowed) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: Color(0xFFC66301),
              size: AppSizes.icon20,
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ordering Closed',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.bold,
                    color: Color(0xFFC66301),
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing2),
                const Text(
                  'Available daily: 11:00 AM – 1:00 AM',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.regular,
                    color: Color(0xFF795548),
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing8,
              vertical: AppSizes.spacing4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSizes.radius4),
            ),
            child: const Text(
              'Opens 11 AM',
              style: TextStyle(
                fontSize: AppTypography.fontSize10,
                fontWeight: AppTypography.semiBold,
                color: Color(0xFFC66301),
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildKitchenClosedBanner(String? reason) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing24,
        vertical: AppSizes.spacing20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            'assets/images/resturent_close.json',
            width: 180,
            height: 180,
            fit: BoxFit.contain,
            repeat: true,
          ),
          const SizedBox(height: AppSizes.spacing8),
          const Text(
            'Outlet Closed',
            style: TextStyle(
              fontSize: AppTypography.fontSize20,
              fontWeight: AppTypography.bold,
              color: Color(0xFF212121),
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing6),
          const Text(
            'Our kitchen is not accepting orders\nright now. Please check back later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.fontSize13,
              fontWeight: AppTypography.regular,
              color: Color(0xFF757575),
              fontFamily: 'Lato',
              height: 1.5,
            ),
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spacing8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing12,
                vertical: AppSizes.spacing6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(AppSizes.radius20),
              ),
              child: Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.medium,
                  color: Color(0xFF9E9E9E),
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
       // _showMembershipPopup();
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
    final serviceabilityState = ref.watch(serviceabilityProvider);
    final dishState = ref.watch(allDishesProvider);

    // Cart bar height: icon(28) + padding(24) + margin(32) ≈ 84px
    const double cartBarHeight = 84.0;

    // Show dish section only when location is serviceable, kitchen is open,
    // and we are within the ordering window.
    final showDishes = serviceabilityState.isServiceable != false &&
        serviceabilityState.isKitchenOpen != false &&
        _isOrderingAllowed;

    final showCartBar = cartItems.isNotEmpty &&
        serviceabilityState.isKitchenOpen != false &&
        serviceabilityState.isServiceable != false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Scrollable content ─────────────────────────────────────────
            // Positioned.fill ensures the Stack fills the SafeArea so the
            // floating cart bar is always anchored to the real bottom edge.
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppColors.primaryGreen,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // ── Scrollable header (profile + banners) ──────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.screenPaddingHorizontal,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSizes.spacing4),
                            _buildCompactHeader(authState, location),
                            const SizedBox(height: AppSizes.spacing8),
                            if (serviceabilityState.isServiceable == false)
                              _buildServiceabilityBanner()
                            else if (serviceabilityState.isKitchenOpen == false)
                              _buildKitchenClosedBanner(
                                  serviceabilityState.kitchenClosedReason)
                            else if (!_isOrderingAllowed)
                              _buildOrderingTimeBanner(),
                          ],
                        ),
                      ),
                    ),

                    // ── Sticky filter chips ─────────────────────────────────
                    // Pinned = true keeps chips visible while the header
                    // scrolls out of view.
                    if (showDishes)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _FilterChipsDelegate(
                          dishState: dishState,
                          child: _buildFilterChips(),
                        ),
                      ),

                    // ── Dish list ───────────────────────────────────────────
                    if (showDishes)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.screenPaddingHorizontal,
                        ),
                        sliver: SliverToBoxAdapter(child: _buildDishList()),
                      ),

                    // ── Bottom padding — extra room for the cart bar ────────
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: showCartBar
                            ? cartBarHeight + AppSizes.spacing32
                            : AppSizes.spacing32,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Floating cart bar ──────────────────────────────────────────
            if (showCartBar)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).size.height * 0.1,
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
            onTap: () {
              if (!_isOrderingAllowed) {
                _showOrderingClosedSnackBar();
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
              );
            },
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
          onTap: widget.onNavigateToProfile,
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
          //onTap: _showMembershipPopupOnDemand,
          onTap: (){
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                const SubscriptionPlanScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image.asset(
                //   'assets/images/buttonshit_logo.png',
                //   height: 13,
                //   width: 13,
                // ),
                // const SizedBox(width: 4),
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
        SizedBox(width: 8,),
        GestureDetector(
            onTap: (){
              Navigator.push(
                  context,
                  MaterialPageRoute(
                  builder: (_) => const NotificationScreen(),
              ),);
            },
            child: Icon(Icons.notifications, color: AppColors.darkGreen,size:24))
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
        SizedBox(height: MediaQuery.of(context).size.height*0.05,),
      ],
    );
  }

  Widget _buildFilterChips() {
    final dishState = ref.watch(allDishesProvider);

    final selectedCatId = dishState.selectedCategoryId;
    final selectedType = dishState.selectedDishType;
    final categories = dishState.categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Category tabs row ──────────────────────────────────────────────
        if (dishState.areCategoriesLoading)
          _buildCategoryTabsSkeleton()
        else if (categories.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(
                  label: 'All',
                  isSelected: selectedCatId == null,
                  onTap: () {
                    _hasShownNoMoreDataPopup = false;
                    ref.read(allDishesProvider.notifier).selectCategory(null);
                  },
                ),
                ...categories.map(
                  (cat) => _chip(
                    label: cat.name,
                    isSelected: selectedCatId == cat.id,
                    onTap: () {
                      _hasShownNoMoreDataPopup = false;
                      ref
                          .read(allDishesProvider.notifier)
                          .selectCategory(cat.id);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
        ],
        // ── Veg / Non-veg filter row ───────────────────────────────────────
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

  /// Skeleton for the category tabs while loading
  Widget _buildCategoryTabsSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: List.generate(
            4,
            (_) => Container(
              margin: const EdgeInsets.only(right: AppSizes.spacing8),
              width: 72,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radius20),
              ),
            ),
          ),
        ),
      ),
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

    // Show skeleton while first page loads
    if (dishState.isLoading) return _buildDishListSkeleton();

    // Error state — only when there is nothing to display at all
    if (dishState.error != null && dishState.items.isEmpty) {
      return _buildDishListError(dishState.error!);
    }

    // Route to grouped (All) or flat (per-category) body
    return dishState.isAllView
        ? _buildGroupedSectionsBody(dishState)
        : _buildFlatCategoryBody(dishState);
  }

  // ── "All" grouped view ─────────────────────────────────────────────────────

  Widget _buildGroupedSectionsBody(AllDishesState dishState) {
    final sections = dishState.groupedSections;

    if (sections.isEmpty) {
      return _buildEmptyState(
        dishState.allItems.isEmpty
            ? 'No items available'
            : 'No items match the selected filters',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          _buildSectionHeader(section.category.name),
          for (final item in section.items)
            _FadeSlideIn(
              key: ValueKey('all_${item.id}'),
              child: _buildDishCard(item),
            ),
          const SizedBox(height: AppSizes.spacing8),
        ],
        if (dishState.isLoadingMore) _buildLoadMoreIndicator(),
      ],
    );
  }

  // ── Per-category paginated view ─────────────────────────────────────────────

  Widget _buildFlatCategoryBody(AllDishesState dishState) {
    final items = dishState.filteredItems;

    if (items.isEmpty) {
      return _buildEmptyState(
        dishState.categoryItems.isEmpty
            ? 'No items available in this category'
            : 'No items match the selected filters',
      );
    }

    return Column(
      children: [
        for (final item in items)
          _FadeSlideIn(
            key: ValueKey('cat_${dishState.selectedCategoryId}_${item.id}'),
            child: _buildDishCard(item),
          ),
        if (dishState.isLoadingMore) _buildLoadMoreIndicator(),
      ],
    );
  }

  Widget _buildLoadMoreIndicator() {
    return const Padding(
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
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String name) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSizes.spacing16,
        bottom: AppSizes.spacing8,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSizes.spacing8),
          Text(
            name,
            style: const TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty / error states ───────────────────────────────────────────────────

  Widget _buildEmptyState(String message) {
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
            message,
            textAlign: TextAlign.center,
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

  Widget _buildDishListSkeleton() {
    return Column(
      children: List.generate(
        6,
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
    final cartNotifier = ref.watch(cartProvider.notifier);
    final isInCart = cartNotifier.isInCart(item.id);
    final cartQty = isInCart ? cartNotifier.getItemQuantity(item.id) : 0;
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
                  // Food image — loaded once and served from disk+memory cache
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      width: AppSizes.icon120,
                      height: AppSizes.icon120,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      fadeOutDuration: const Duration(milliseconds: 100),
                      placeholder: (_, __) => Container(
                        width: AppSizes.icon120,
                        height: AppSizes.icon120,
                        color: Colors.grey.withValues(alpha: 0.12),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: AppSizes.icon120,
                        height: AppSizes.icon120,
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
                        Wrap(
                          spacing:AppSizes.spacing6,
                          runSpacing: AppSizes.spacing4,
                          children: [
                            item.protein !="0.0g" ?
                            _buildMacroChip(
                                'Protein', item.protein, const Color(0xFF4A7C3E)):SizedBox.shrink(),
                            item.carbs !="0.0g" ?
                            _buildMacroChip(
                                'Carbs', item.carbs, const Color(0xFFC66301)):SizedBox.shrink(),
                            item.fats !="0.0g" ?
                            _buildMacroChip(
                                'Fat', item.fats, const Color(0xFF6BA84F)):SizedBox.shrink(),
                            // item.fiber !="0.0g" ?
                            // _buildMacroChip(
                            //     'Fibre', item.fiber, const Color(0xFF6BA84F)):SizedBox.shrink(),
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
                            // Add button / quantity stepper
                            if (!isInCart)
                              GestureDetector(
                                onTap: isAvailable
                                    ? () {
                                        if (!_isOrderingAllowed) {
                                          _showOrderingClosedSnackBar();
                                          return;
                                        }
                                        showDialog(
                                          context: context,
                                          builder: (_) =>
                                              FoodDetailPopup(menuItem: item),
                                        );
                                      }
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSizes.spacing16,
                                    vertical: AppSizes.spacing4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    borderRadius: BorderRadius.circular(
                                        AppSizes.radius4),
                                    border: Border.all(
                                      color: AppColors.primaryGreen,
                                      width: AppSizes.borderThin,
                                    ),
                                  ),
                                  child: const Text(
                                    AppStrings.add,
                                    style: TextStyle(
                                      fontSize: AppTypography.fontSize12,
                                      fontWeight: AppTypography.semiBold,
                                      color: Colors.white,
                                      fontFamily: 'Lato',
                                    ),
                                  ),
                                ),
                              )
                            else
                              _buildQuantityStepper(item, cartQty),
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

  Widget _buildQuantityStepper(MenuItem item, int qty) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border: Border.all(
          color: AppColors.primaryGreen,
          width: AppSizes.borderThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (!_isOrderingAllowed) {
                _showOrderingClosedSnackBar();
                return;
              }
              ref.read(cartProvider.notifier).updateQuantity(item.id, qty - 1);
            },
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              child: const Icon(
                Icons.remove,
                size: 16,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.bold,
                color: AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (!_isOrderingAllowed) {
                _showOrderingClosedSnackBar();
                return;
              }
              ref.read(cartProvider.notifier).addItem(item);
            },
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              child: const Icon(
                Icons.add,
                size: 16,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
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

// ─── Fade + slide-up animation widget ────────────────────────────────────────
//
// Wrapping each dish card in this widget gives a smooth "rise in" entrance
// the first time an item appears in the tree.  Flutter preserves widget
// identity via [Key], so existing items are never re-animated — only items
// that are genuinely new (scroll-load appends, view switches) animate in.

class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required super.key, required this.child});
  final Widget child;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ─── Sticky filter-chips delegate ────────────────────────────────────────────
//
// Used with [SliverPersistentHeader(pinned: true)] so that category tabs and
// the veg/non-veg filter row stay visible at the top of the viewport while
// the profile header and dish cards scroll freely underneath.
//
// Height breakdown (px):
//   top padding                          8
//   category tabs row (ListView h=36)   36
//   gap between rows                     8
//   veg/non-veg chip row                ~28
//   bottom gap (AppSizes.spacing12)     12
//   ─────────────────────────────────── ──
//   with  category tabs             ≈  92  → 96 (safety buffer)
//   without category tabs           ≈  48  → 52 (safety buffer)

class _FilterChipsDelegate extends SliverPersistentHeaderDelegate {
  const _FilterChipsDelegate({
    required this.dishState,
    required this.child,
  });

  final AllDishesState dishState;
  final Widget child;

  double get _height {
    // Taller variant when the category-tab row is present or loading.
    if (dishState.areCategoriesLoading || dishState.categories.isNotEmpty) {
      return 96.0;
    }
    // Compact variant — only the veg/non-veg row.
    return 52.0;
  }

  @override
  double get maxExtent => _height;

  @override
  double get minExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Add a soft shadow once the list scrolls beneath the pinned header so
    // there is a clear visual separation between content layers.
    return Material(
      color: AppColors.background,
      elevation: overlapsContent ? 2.0 : 0.0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSizes.screenPaddingHorizontal,
          right: AppSizes.screenPaddingHorizontal,
          top: 8.0,
        ),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterChipsDelegate old) =>
      // Always rebuild so chips reflect the latest provider state and the
      // height getters are re-evaluated when categories first load.
      old.dishState != dishState || old.child != child;
}
