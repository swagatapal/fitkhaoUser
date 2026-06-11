import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fitkhao_user/shared/animation/anime_entrance.dart';
import 'package:flutter/services.dart';
import 'package:fitkhao_user/features/profile/presentation/screens/profile_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/delivery_gate_provider.dart';
import '../../providers/dish_search_provider.dart';
import '../../models/menu_item.dart';
import '../../providers/menu_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/food_detail_popup.dart';
import '../widgets/location_view_sheet.dart';
import 'checkout_screen.dart';

/// Saturation matrix that renders its subtree fully grayscale.
/// Applied to the dish list while ordering is in the passive (closed) state.
const ColorFilter _kGrayscaleFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

// ─── Dish-type filter definitions (single source of truth) ───────────────────
class _DishTypeOption {
  final String value; // normalized: matches MenuItem.menuTypes entries
  final String label;
  final IconData icon;
  final Color color;

  const _DishTypeOption(this.value, this.label, this.icon, this.color);
}

const List<_DishTypeOption> _kDishTypeOptions = [
  _DishTypeOption('veg', 'Veg', Icons.eco_rounded, Color(0xFF388E3C)),
  _DishTypeOption(
      'eggetarian', 'Eggetarian', Icons.egg_rounded, Color(0xFFF57C00)),
  _DishTypeOption(
      'nonveg', 'Non-Veg', Icons.set_meal_rounded, Color(0xFFD32F2F)),
  _DishTypeOption('vegan', 'Vegan', Icons.spa_rounded, Color(0xFF6A1B9A)),
  _DishTypeOption(
      'beverage', 'Beverage', Icons.local_cafe_rounded, Color(0xFF1976D2)),
  _DishTypeOption(
      'smoothie', 'Smoothie', Icons.local_drink_rounded, Color(0xFFEC407A)),
];

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  final bool _profileImageError = false;

  /// IDs of categories that are currently collapsed in the "All" grouped view.
  final Set<String> _collapsedCategories = {};

  DateTime? currentBackPressTime;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showOrderingClosedSnackBar() {
    if (!mounted) return;
    final areaBlocked = ref.read(deliveryGateProvider).areaBlocksOrdering;
    final reason = areaBlocked
        ? 'We don’t deliver to your area yet. Add another address for delivery'
        : (ref.read(kitchenProvider).kitchenClosedReason ??
            'The outlet is currently closed');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(reason),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFC66301),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  /// Loads everything needed on first open / re-entry.
  ///
  /// Food is the priority: cached dishes (held in the provider's persisted
  /// state) render instantly and refresh silently; only a cold start shows the
  /// skeleton. Profile, wallet and serviceability all run in the background and
  /// never gate the food list — serviceability is fetched purely to resolve the
  /// kitchenId (used by checkout) and the kitchen open/close status.
  Future<void> _loadInitialData() async {
    unawaited(_loadProfileData());
    unawaited(_loadWalletBalance());
    unawaited(_loadKitchens());
    // Keep the server cart fresh on every entry (badge, steppers, totals).
    unawaited(ref.read(cartProvider.notifier).loadCart());
    // Resolve the delivery-area serviceability + location/notification prompts.
    unawaited(ref.read(deliveryGateProvider.notifier).evaluate());

    final hasCachedDishes = ref.read(allDishesProvider).items.isNotEmpty;
    if (hasCachedDishes) {
      unawaited(ref.read(allDishesProvider.notifier).silentRefresh());
    } else {
      await _loadAllDishes();
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(allDishesProvider.notifier).silentRefresh(),
      _loadKitchens(),
      ref.read(cartProvider.notifier).loadCart(),
      ref.read(deliveryGateProvider.notifier).evaluate(),
    ]);
  }

  Future<void> _loadAllDishes() async {
    if (_collapsedCategories.isNotEmpty) {
      setState(() => _collapsedCategories.clear());
    }
    await ref.read(allDishesProvider.notifier).loadMenuItems();
  }

  Future<void> _loadProfileData() async {
    await ref.read(authProvider.notifier).loadProfile();
  }

  Future<void> _loadWalletBalance() async {
    await ref.read(walletProvider.notifier).loadWalletBalance();
  }

  /// Background-only kitchen resolution. The UI never blocks on this; it loads
  /// the active kitchen list, default-selects a kitchen, and resolves its
  /// open/close status (used to gate ordering and surface the closed banner).
  Future<void> _loadKitchens() async {
    await ref.read(kitchenProvider.notifier).loadKitchens();
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (!_collapsedCategories.remove(categoryId)) {
        _collapsedCategories.add(categoryId);
      }
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;

    if (position.pixels < position.maxScrollExtent - 120) {
      return;
    }

    // Paginate the active view — search results or the browse list.
    if (ref.read(dishSearchProvider).isActive) {
      ref.read(dishSearchProvider.notifier).loadMore();
    } else if (ref.read(allDishesProvider).canLoadMore) {
      ref.read(allDishesProvider.notifier).loadMore();
    }
  }

  void _onDishSearchChanged(String value) {
    _searchDebounce?.cancel();
    // Debounce keystrokes; the provider sequences requests to drop stale ones.
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final kitchenId = ref.read(kitchenProvider).selectedKitchenId;
      ref
          .read(dishSearchProvider.notifier)
          .search(value.trim(), kitchenId: kitchenId);
    });
  }

  void _clearDishSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    ref.read(dishSearchProvider.notifier).clear();
  }

  // ── Location helpers ──────────────────────────────────────────────────────

  String _getUserLocation() {
    final authState = ref.read(authProvider);
    if (authState.street.isNotEmpty) {
      final parts = authState.street.split(',');
      return "${parts.first.trim()}, ${authState.buildingNameNumber}, ${authState.pincode}";
    }
    if (authState.buildingNameNumber.isNotEmpty) {
      return authState.buildingNameNumber;
    }
    return 'Location';
  }

  String _computeLocation(authState) {
    if ((authState.street as String).isNotEmpty) {
      final parts = (authState.street as String).split(',');
      return "${parts.join(', ')}, ${authState.pincode as String}";
    }
    if ((authState.buildingNameNumber as String).isNotEmpty) {
      return authState.buildingNameNumber as String;
    }
    return 'Location';
  }

  void _openLocationMap() {
    // Prefer the coordinate the availability was resolved against; fall back to
    // the profile address coordinate.
    final gate = ref.read(deliveryGateProvider);
    final authState = ref.read(authProvider);
    final lat = gate.latitude ?? authState.latitude;
    final lng = gate.longitude ?? authState.longitude;
    if (lat == null || lng == null) return;

    final address =
        (gate.resolvedAddress != null && gate.resolvedAddress!.isNotEmpty)
            ? gate.resolvedAddress!
            : _getUserLocation();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationViewSheet(
        latitude: lat,
        longitude: lng,
        address: address,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final location = _computeLocation(authState);
    final dishState = ref.watch(allDishesProvider);

    // Outlet open/close is the authoritative kitchen open-status from the API
    // (it already encodes the kitchen's operating hours/schedule server-side).
    // null → not yet resolved (fail-open, treat as open). false → closed.
    final kitchenOpen = ref.watch(
      kitchenProvider.select((s) => s.isKitchenOpen != false),
    );

    // Backend search — when active, results replace the browse view + filters.
    final search = ref.watch(dishSearchProvider);
    final isSearching = search.isActive;

    // Entry-gate state: area serviceability + location / notification prompts.
    final gate = ref.watch(deliveryGateProvider);
    final areaBlocked = gate.areaBlocksOrdering;

    // Header location label: the address the availability was resolved against
    // (reverse-geocoded for the device location), falling back to the profile.
    final displayAddress =
        (gate.resolvedAddress != null && gate.resolvedAddress!.isNotEmpty)
            ? gate.resolvedAddress!
            : location;

    // ACTIVE  → kitchen open AND area serviceable → colorful, can order.
    // PASSIVE → otherwise                         → grayscale, view-only.
    final isOrderingActive = kitchenOpen && !areaBlocked;

    final closedReason =
        ref.watch(kitchenProvider.select((s) => s.kitchenClosedReason)) ??
            'The outlet is currently closed';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        DateTime now = DateTime.now();
        if (didPop ||
            currentBackPressTime == null ||
            now.difference(currentBackPressTime!) > Duration(seconds: 2)) {
          currentBackPressTime = now;
          SnackBar(
              backgroundColor: AppColors.darkGreen,
              content:  Text( 'Tap back again to Exit', style: TextStyle(color: AppColors.textWhite),));
          // return false;
        } else {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          drawer: const AppDrawer(),
          body: SafeArea(
            child: Stack(
              children: [
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
                        // ── Header + search + (passive banner) ──────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.screenPaddingHorizontal,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: AppSizes.spacing4),
                                _buildCompactHeader(authState, displayAddress),
                                const SizedBox(height: AppSizes.spacing8),
                                _buildDishSearchBar(),
                                // Area not serviceable → blocks ordering.
                                if (areaBlocked) _buildNotServiceableBanner(),
                                // Kitchen closed (independent of area).
                                if (!kitchenOpen)
                                  _buildPassiveBanner(closedReason),
                                // Location permission missing (food stays enabled).
                                if (gate.showLocationInfo) _buildLocationInfo(),
                                // Notifications off — soft nudge.
                                if (gate.showNotificationInfo)
                                  _buildNotificationInfo(),
                              ],
                            ),
                          ),
                        ),

                        // ── Sticky compact filters (hidden while searching) ──
                        if (!isSearching)
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _FilterHeaderDelegate(
                              dishState: dishState,
                              child: _buildFilters(dishState),
                            ),
                          ),

                        // ── Food list / search results (grayscale in passive) ─
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.screenPaddingHorizontal,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: isSearching
                                ? _buildSearchResults(search, isOrderingActive)
                                : _buildDishList(dishState, isOrderingActive),
                          ),
                        ),

                        // ── Bottom spacer (reserves room for the cart bar) ──
                        SliverToBoxAdapter(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final hasItems =
                                  ref.watch(cartTotalItemsProvider) > 0;
                              final reserve = hasItems && isOrderingActive;
                              return SizedBox(height: reserve ? 168 : 96);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Floating cart bar (only when active + non-empty) ────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).size.height * 0.03,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final totalItems = ref.watch(cartTotalItemsProvider);
                      if (totalItems == 0 || !isOrderingActive) {
                        return const SizedBox.shrink();
                      }
                      return _CartBar(
                        onClear: _showClearCartDialog,
                        onCheckout: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CheckoutScreen()),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Passive banner ──────────────────────────────────────────────────────────

  Widget _buildPassiveBanner(String reason) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing12,
        vertical: AppSizes.spacing10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border:
            Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: Color(0xFFC66301),
              size: AppSizes.icon16,
            ),
          ),
          const SizedBox(width: AppSizes.spacing10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Outlet Closed',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize13,
                    fontWeight: AppTypography.bold,
                    color: Color(0xFFC66301),
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.regular,
                    color: Color(0xFF795548),
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

  // ── Not-serviceable banner ───────────────────────────────────────────────────

  Widget _buildNotServiceableBanner() {
    final zone = ref.watch(deliveryGateProvider.select((s) => s.zoneName));
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing12,
        vertical: AppSizes.spacing10,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: AppColors.errorColor.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing6),
            decoration: BoxDecoration(
              color: AppColors.errorColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_off_rounded,
                color: AppColors.errorColor, size: AppSizes.icon16),
          ),
          const SizedBox(width: AppSizes.spacing10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Area not serviceable',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize13,
                    fontWeight: AppTypography.bold,
                    color: AppColors.errorColor,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  zone != null && zone.isNotEmpty
                      ? 'We don’t deliver to your area yet. Browse the menu below.'
                      : 'We don’t deliver to your area yet. Try a different address.',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: Color(0xFF7A4A4A),
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

  // ── Location-permission info box ──────────────────────────────────────────────

  Widget _buildLocationInfo() {
    return _InfoBanner(
      icon: Icons.my_location_rounded,
      accent: const Color(0xFF2E7CF6),
      title: 'Turn on location',
      message:
          'Enable location so we can check delivery availability for your area.',
      actionLabel: 'Enable',
      onAction: () => ref.read(deliveryGateProvider.notifier).enableLocation(),
      onDismiss: () =>
          ref.read(deliveryGateProvider.notifier).dismissLocationInfo(),
    );
  }

  // ── Notification-permission info box ──────────────────────────────────────────

  Widget _buildNotificationInfo() {
    return _InfoBanner(
      icon: Icons.notifications_active_outlined,
      accent: const Color(0xFFF5A623),
      title: 'Stay in the loop',
      message:
          'Enable notifications so you don’t miss order updates and offers.',
      actionLabel: 'Enable',
      onAction: () =>
          ref.read(deliveryGateProvider.notifier).enableNotifications(),
      onDismiss: () =>
          ref.read(deliveryGateProvider.notifier).dismissNotificationInfo(),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildCompactHeader(authState, String location) {
    final firstName = (authState.name as String).isNotEmpty
        ? (authState.name as String).split(' ').first
        : 'User';
    final imgUrl = authState.imgUrl as String?;
    final hasValidUrl =
        imgUrl != null && imgUrl.isNotEmpty && !_profileImageError;

    return Row(
      children: [
        GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
            child: const Icon(
              Icons.menu_rounded,
              color: AppColors.darkGreen,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ProfileMenuScreen()),
          ),
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
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 12, color: AppColors.primaryGreen),
                    const SizedBox(width: 3),
                    Flexible(
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
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Search bar ──────────────────────────────────────────────────────────────

  Widget _buildDishSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
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
            hintText: 'Search for dishes you love…',
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
                    child: Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: AppSizes.icon20),
                  ),
                );
              },
            ),
            border: InputBorder.none,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius12),
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

  // ── Filters (compact, space-efficient) ───────────────────────────────────────

  Widget _buildFilters(AllDishesState dishState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dishState.areCategoriesLoading)
          _buildCategoryTabsSkeleton()
        else if (dishState.categories.isNotEmpty) ...[
          _buildCategoryTabBar(dishState),
          const SizedBox(height: AppSizes.spacing8),
        ],
        _buildDishTypeStrip(dishState),
      ],
    );
  }

  Widget _buildCategoryTabBar(AllDishesState dishState) {
    final selectedCatId = dishState.selectedCategoryId;
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          _categoryTab(
            label: 'All',
            isSelected: selectedCatId == null,
            onTap: () =>
                ref.read(allDishesProvider.notifier).selectCategory(null),
          ),
          ...dishState.categories.map(
            (cat) => _categoryTab(
              label: cat.name,
              isSelected: selectedCatId == cat.id,
              onTap: () =>
                  ref.read(allDishesProvider.notifier).selectCategory(cat.id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.spacing8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF5D9E40), Color(0xFF6BA84F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : AppColors.borderColor.withValues(alpha: 0.5),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.fontSize13,
              fontWeight:
                  isSelected ? AppTypography.bold : AppTypography.medium,
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
        ),
      ),
    );
  }

  /// Dish-type strip — multi-select, color-coded, deliberately styled
  /// differently from the category tabs so the two filters read as separate.
  Widget _buildDishTypeStrip(AllDishesState dishState) {
    final selected = dishState.selectedDishTypes;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: _kDishTypeOptions.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.spacing8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _dishTypePill(
              label: 'All',
              icon: Icons.restaurant_menu_rounded,
              color: AppColors.primaryGreen,
              isSelected: selected.isEmpty,
              onTap: () =>
                  ref.read(allDishesProvider.notifier).clearDishTypes(),
            );
          }
          final option = _kDishTypeOptions[index - 1];
          return _dishTypePill(
            label: option.label,
            icon: option.icon,
            color: option.color,
            isSelected: selected.contains(option.value),
            onTap: () => ref
                .read(allDishesProvider.notifier)
                .toggleDishType(option.value),
          );
        },
      ),
    );
  }

  Widget _dishTypePill({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius20),
          border: Border.all(
            color: isSelected
                ? color
                : AppColors.borderColor.withValues(alpha: 0.5),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: isSelected ? color : AppColors.textSecondary),
            const SizedBox(width: AppSizes.spacing4),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                fontWeight:
                    isSelected ? AppTypography.semiBold : AppTypography.regular,
                color: isSelected ? color : AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: AppSizes.spacing4),
              Icon(Icons.check_circle, size: 13, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabsSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(
            5,
            (i) => Container(
              margin: const EdgeInsets.only(right: AppSizes.spacing8),
              width: 72 + (i.isEven ? 16 : 0),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Dish list ────────────────────────────────────────────────────────────────

  Widget _buildDishList(AllDishesState dishState, bool isActive) {
    Widget content;
    if (dishState.isLoading) {
      content = _buildDishListSkeleton();
    } else if (dishState.error != null && dishState.items.isEmpty) {
      content = _buildDishListError(dishState.error!);
    } else if (dishState.isAllView) {
      content = _buildGroupedSectionsBody(dishState, isActive);
    } else {
      content = _buildFlatCategoryBody(dishState, isActive);
    }

    // Grayscale the entire food area when ordering is in the passive state.
    if (!isActive) {
      content = ColorFiltered(colorFilter: _kGrayscaleFilter, child: content);
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacing8),
      child: content,
    );
  }

  // ── Search results ────────────────────────────────────────────────────────────

  Widget _buildSearchResults(DishSearchState search, bool isActive) {
    Widget content;
    switch (search.status) {
      case DishSearchStatus.loading:
        content = _buildDishListSkeleton();
        break;
      case DishSearchStatus.error:
        content = _buildDishListError(
          search.error ?? 'Search failed. Please try again.',
          onRetry: () => ref.read(dishSearchProvider.notifier).retry(),
        );
        break;
      case DishSearchStatus.empty:
        content = _buildEmptyState('No dishes found for “${search.query}”');
        break;
      default: // success / loadingMore
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  top: AppSizes.spacing8, bottom: AppSizes.spacing4),
              child: Text(
                '${search.results.length} '
                '${search.results.length == 1 ? 'result' : 'results'} '
                'for “${search.query}”',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ),
            for (final item in search.results)
              _FadeSlideIn(
                key: ValueKey('search_${item.id}'),
                child: _DishCard(
                  item: item,
                  isOrderingEnabled: isActive,
                  onOrderingDisabledTap: _showOrderingClosedSnackBar,
                ),
              ),
            if (search.isLoadingMore) _buildLoadMoreIndicator(),
            const SizedBox(height: AppSizes.spacing8),
          ],
        );
    }

    if (!isActive) {
      content = ColorFiltered(colorFilter: _kGrayscaleFilter, child: content);
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacing4),
      child: content,
    );
  }

  Widget _buildGroupedSectionsBody(AllDishesState dishState, bool isActive) {
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
          _buildCollapsibleSectionHeader(section),
          _buildCollapsibleSectionItems(section, isActive),
        ],
        if (dishState.isLoadingMore) _buildLoadMoreIndicator(),
        const SizedBox(height: AppSizes.spacing8),
      ],
    );
  }

  Widget _buildCollapsibleSectionHeader(GroupedDishSection section) {
    final isCollapsed = _collapsedCategories.contains(section.category.id);
    return GestureDetector(
      onTap: () => _toggleCategory(section.category.id),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSizes.spacing16,
          bottom: AppSizes.spacing8,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: isCollapsed
                    ? AppColors.textTertiary
                    : AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.bold,
                  color: isCollapsed
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
                child: Text(section.category.name),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing8,
                vertical: AppSizes.spacing2,
              ),
              decoration: BoxDecoration(
                color: isCollapsed
                    ? Colors.grey.withValues(alpha: 0.10)
                    : AppColors.primaryGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSizes.radius20),
              ),
              child: Text(
                '${section.items.length} items',
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.semiBold,
                  color: isCollapsed
                      ? AppColors.textTertiary
                      : AppColors.primaryGreen,
                  fontFamily: 'Lato',
                ),
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
            AnimatedRotation(
              turns: isCollapsed ? 0.5 : 0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: isCollapsed
                    ? AppColors.textTertiary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleSectionItems(
      GroupedDishSection section, bool isActive) {
    final isCollapsed = _collapsedCategories.contains(section.category.id);
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: isCollapsed
          ? const SizedBox(width: double.infinity)
          : Column(
              children: [
                for (final item in section.items)
                  _FadeSlideIn(
                    key: ValueKey('all_${item.id}'),
                    child: _DishCard(
                      item: item,
                      isOrderingEnabled: isActive,
                      onOrderingDisabledTap: _showOrderingClosedSnackBar,
                    ),
                  ),
                const SizedBox(height: AppSizes.spacing8),
              ],
            ),
    );
  }

  Widget _buildFlatCategoryBody(AllDishesState dishState, bool isActive) {
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
          AnimEntrance(
            delay: AnimEntrance.stagger(items.indexOf(item)),
            child: _FadeSlideIn(
              key: ValueKey('cat_${dishState.selectedCategoryId}_${item.id}'),
              child: _DishCard(
                item: item,
                isOrderingEnabled: isActive,
                onOrderingDisabledTap: _showOrderingClosedSnackBar,
              ),
            ),
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

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.no_meals_outlined,
              size: AppSizes.icon48, color: AppColors.textTertiary),
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
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radius12),
          ),
        ),
      ),
    );
  }

  Widget _buildDishListError(String message, {VoidCallback? onRetry}) {
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
            onTap: onRetry ?? _loadAllDishes,
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

  // ── Clear-cart dialog ─────────────────────────────────────────────────────

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
            AppSizes.spacing16, 0, AppSizes.spacing16, AppSizes.spacing16),
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
}

// ─── Dish card (scoped to its own cart slice) ────────────────────────────────
//
// A ConsumerWidget so that adding/removing THIS item from the cart rebuilds
// only this card — never the whole list. The quantity is read via a granular
// `select`, so unrelated cart mutations don't touch this widget.

class _DishCard extends ConsumerWidget {
  const _DishCard({
    required this.item,
    required this.isOrderingEnabled,
    required this.onOrderingDisabledTap,
  });

  final MenuItem item;
  final bool isOrderingEnabled;
  final VoidCallback onOrderingDisabledTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(
      cartProvider.select((items) {
        for (final c in items) {
          if (c.menuItem.id == item.id) return c.quantity;
        }
        return 0;
      }),
    );
    final isInCart = qty > 0;
    final isAvailable = item.isAvailable;
    final canOrder = isOrderingEnabled && isAvailable;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
      child: GestureDetector(
        onTap: () {
          if (!isAvailable) return;
          if (!isOrderingEnabled) {
            onOrderingDisabledTap();
            return;
          }
          showDialog(
            context: context,
            builder: (_) => FoodDetailPopup(menuItem: item),
          );
        },
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radius12),
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
                        child: const Icon(Icons.restaurant,
                            size: AppSizes.icon32,
                            color: AppColors.primaryGreen),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            _vegIndicator(item.isVeg),
                          ],
                        ),
                        const SizedBox(height: AppSizes.spacing4),
                        _caloriesAndRating(),
                        const SizedBox(height: AppSizes.spacing4),
                        _macros(),
                        const SizedBox(height: AppSizes.spacing6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _price(),
                            if (isOrderingEnabled)
                              isInCart
                                  ? _QuantityStepper(item: item, qty: qty)
                                  : _addButton(context, canOrder),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isAvailable)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radius12),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.78),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.spacing12,
                            vertical: AppSizes.spacing6),
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

  Widget _vegIndicator(bool isVeg) {
    final color = isVeg ? const Color(0xFF388E3C) : const Color(0xFFD32F2F);
    return Container(
      width: AppSizes.spacing12,
      height: AppSizes.spacing12,
      margin: const EdgeInsets.only(top: AppSizes.spacing2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: AppSizes.borderNormal),
      ),
      child: Center(
        child: Container(
          width: AppSizes.spacing6,
          height: AppSizes.spacing6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }

  Widget _caloriesAndRating() {
    return Row(
      children: [
        if (item.calories != 0) ...[
          const Icon(Icons.local_fire_department,
              size: AppSizes.icon12, color: AppColors.primaryGreen),
          const SizedBox(width: AppSizes.spacing2),
          Text(
            '${item.calories} kcal',
            style: const TextStyle(
              fontSize: AppTypography.fontSize12,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ],
        if (item.rating > 0) ...[
          const SizedBox(width: AppSizes.spacing8),
          const Icon(Icons.star, size: AppSizes.icon12, color: Colors.amber),
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
    );
  }

  Widget _macros() {
    final chips = <Widget>[
      if (item.protein != '0.0g')
        _macroChip('Protein', item.protein, const Color(0xFF4A7C3E)),
      if (item.carbs != '0.0g')
        _macroChip('Carbs', item.carbs, const Color(0xFFC66301)),
      if (item.fats != '0.0g')
        _macroChip('Fat', item.fats, const Color(0xFF6BA84F)),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSizes.spacing6,
      runSpacing: AppSizes.spacing4,
      children: chips,
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing6, vertical: AppSizes.spacing2),
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

  Widget _price() {
    return Row(
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
    );
  }

  Widget _addButton(BuildContext context, bool canOrder) {
    return GestureDetector(
      onTap: canOrder
          ? () => showDialog(
                context: context,
                builder: (_) => FoodDetailPopup(menuItem: item),
              )
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16, vertical: AppSizes.spacing4),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(AppSizes.radius4),
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
    );
  }
}

// ─── Quantity stepper ────────────────────────────────────────────────────────

class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper({required this.item, required this.qty});

  final MenuItem item;
  final int qty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border: Border.all(
            color: AppColors.primaryGreen, width: AppSizes.borderThin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(
            Icons.remove,
            () => ref
                .read(cartProvider.notifier)
                .updateQuantity(item.id, qty - 1),
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
          _stepBtn(
            Icons.add,
            () => ref.read(cartProvider.notifier).addItem(item),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: AppColors.primaryGreen),
      ),
    );
  }
}

// ─── Floating cart bar (scoped to cart totals) ───────────────────────────────

class _CartBar extends ConsumerWidget {
  const _CartBar({required this.onClear, required this.onCheckout});

  final VoidCallback onClear;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalItems = ref.watch(cartTotalItemsProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);

    return Container(
      margin: const EdgeInsets.all(AppSizes.spacing16),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing20, vertical: AppSizes.spacing12),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
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
              const Icon(Icons.shopping_cart,
                  color: Colors.white, size: AppSizes.icon28),
              if (totalItems > 0)
                Positioned(
                  right: -AppSizes.spacing6,
                  top: -AppSizes.spacing4,
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.spacing4),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    constraints: const BoxConstraints(
                        minWidth: AppSizes.spacing16,
                        minHeight: AppSizes.spacing16),
                    child: Center(
                      child: Text(
                        '$totalItems',
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
          GestureDetector(
            onTap: onClear,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: AppSizes.spacing8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: AppSizes.icon20),
            ),
          ),
          GestureDetector(
            onTap: onCheckout,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing16, vertical: AppSizes.spacing8),
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
}

// ─── Fade + slide-up entrance ────────────────────────────────────────────────

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
        vsync: this, duration: const Duration(milliseconds: 320));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
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
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Dismissible info banner (location / notification prompts) ────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  const _InfoBanner({
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: AppSizes.icon18),
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
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacing8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onDismiss,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: AppSizes.spacing4),
                  child: Icon(Icons.close_rounded,
                      size: AppSizes.icon16, color: AppColors.textTertiary),
                ),
              ),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing12,
                      vertical: AppSizes.spacing6),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppSizes.radius6),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize12,
                      fontWeight: AppTypography.bold,
                      color: Colors.white,
                      fontFamily: 'Lato',
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
}

// ─── Sticky compact-filters delegate ─────────────────────────────────────────

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterHeaderDelegate({required this.dishState, required this.child});

  final AllDishesState dishState;
  final Widget child;

  // Heights are derived from the fixed inner row sizes so the pinned header
  // never overflows:
  //   top pad (8) + category row (38) + gap (8) + type strip (34) + bottom (8)
  //     = 96   (with categories)  → +2 slack
  //   top pad (8) + type strip (34) + bottom (8)
  //     = 50   (no categories)    → +2 slack
  double get _height {
    final hasCategories =
        dishState.areCategoriesLoading || dishState.categories.isNotEmpty;
    return hasCategories ? 98.0 : 52.0;
  }

  @override
  double get maxExtent => _height;

  @override
  double get minExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // SizedBox.expand forces the child to fill the full [_height] the delegate
    // declares. A persistent header lays its child out with a LOOSE height
    // constraint, so without this the child could settle shorter than
    // maxExtent — making paintExtent < layoutExtent (an invalid SliverGeometry).
    return SizedBox.expand(
      child: Material(
        color: AppColors.background,
        elevation: overlapsContent ? 2.0 : 0.0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSizes.screenPaddingHorizontal,
            right: AppSizes.screenPaddingHorizontal,
            top: AppSizes.spacing8,
            bottom: AppSizes.spacing8,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterHeaderDelegate old) =>
      old.dishState != dishState || old.child != child;
}
