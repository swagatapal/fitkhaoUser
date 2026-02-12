import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/menu_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/menu_provider.dart';
import '../widgets/food_detail_popup.dart';
import 'checkout_screen.dart';

class MenuListScreen extends ConsumerStatefulWidget {
  final String mealType; // 'breakfast', 'lunch', 'dinner'

  const MenuListScreen({
    super.key,
    required this.mealType,
  });

  @override
  ConsumerState<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends ConsumerState<MenuListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // 'All', 'Veg', 'Non-Veg'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load menu items when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMenuItems();
    });

    // Add listener to search controller
    _searchController.addListener(_onSearchChanged);
  }

  /// Handle search query changes
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  /// Load menu items from API
  Future<void> _loadMenuItems() async {
    final menuNotifier = ref.read(menuProvider.notifier);
    await menuNotifier.loadMenuItems(mealType: widget.mealType);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  String get _menuTitle {
    switch (widget.mealType.toLowerCase()) {
      case 'breakfast':
        return AppStrings.breakfastMenu;
      case 'lunch':
        return AppStrings.lunchMenu;
      case 'dinner':
        return AppStrings.dinnerMenu;
      default:
        return AppStrings.breakfastMenu;
    }
  }

  String get _menuSubtitle {
    switch (widget.mealType.toLowerCase()) {
      case 'breakfast':
        return AppStrings.selectMealHealthyStart;
      case 'lunch':
        return AppStrings.selectMealBalancedDay;
      case 'dinner':
        return AppStrings.selectMealPerfectEnd;
      default:
        return AppStrings.selectMealHealthyStart;
    }
  }

  List<MenuItem> _getFilteredItems(List<MenuItem> menuItems) {
    return menuItems.where((item) {
      // Filter by Veg/Non-Veg
      if (_selectedFilter == 'Veg' && !item.isVeg) return false;
      if (_selectedFilter == 'Non-Veg' && item.isVeg) return false;

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = item.name.toLowerCase().contains(query);
        final descriptionMatch = item.description.toLowerCase().contains(query);
        final categoryMatch = item.category.toLowerCase().contains(query);

        if (!nameMatch && !descriptionMatch && !categoryMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Map<String, List<MenuItem>> _getItemsByCategory(List<MenuItem> filteredItems) {
    final Map<String, List<MenuItem>> grouped = {};
    for (var item in filteredItems) {
      if (!grouped.containsKey(item.category)) {
        grouped[item.category] = [];
      }
      grouped[item.category]!.add(item);
    }
    return grouped;
  }

  /// Refresh menu items from API
  Future<void> _onRefresh() async {
    final menuNotifier = ref.read(menuProvider.notifier);
    await menuNotifier.refresh(mealType: widget.mealType);
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalItems = ref.watch(cartTotalItemsProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppColors.primaryGreen,
                    backgroundColor: Colors.white,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.screenPaddingHorizontal,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSizes.spacing16),
                            _buildSearchBar(),
                            const SizedBox(height: AppSizes.spacing16),
                            _buildFilterButtons(),
                            const SizedBox(height: AppSizes.spacing20),
                            _buildMenuCategories(),
                            const SizedBox(height: AppSizes.spacing32),
                            // Add spacing for cart bar
                            if (cartItems.isNotEmpty)
                              const SizedBox(height: AppSizes.spacing80),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Cart Bar
            if (cartItems.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildCartBar(totalItems, totalPrice),
              ),
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
                  _menuTitle,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                //const SizedBox(height: AppSizes.spacing2),
                Text(
                  _menuSubtitle,
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
          CircleAvatar(
            radius: AppSizes.spacing24,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
            backgroundImage: NetworkImage(
              ref.watch(authProvider).imgUrl ?? "https://i.sstatic.net/l60Hf.png",
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
        ],
      ),
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
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: AppColors.textSecondary,
                    size: AppSizes.icon24,
                  ),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : IconButton(
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

  Widget _buildFilterButtons() {
    return Row(
      children: [
        _buildFilterButton('All'),
        const SizedBox(width: AppSizes.spacing12),
        _buildFilterButton('Veg'),
        const SizedBox(width: AppSizes.spacing12),
        _buildFilterButton('Non-Veg'),
      ],
    );
  }

  Widget _buildFilterButton(String filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing16,
          vertical: AppSizes.spacing8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius4),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
                : AppColors.borderColor,
            width: AppSizes.borderMedium,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filter != 'All')
              Container(
                width: AppSizes.spacing8,
                height: AppSizes.spacing8,
                margin: const EdgeInsets.only(right: AppSizes.spacing6),
                decoration: BoxDecoration(
                  color: filter == 'Veg' ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.grey,
                    width: AppSizes.borderThin,
                  ),
                ),
              ),
            Text(
              filter == 'Veg' ? AppStrings.veg :
              filter == 'Non-Veg' ? AppStrings.nonVeg : filter,
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.medium,
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCategories() {
    final menuState = ref.watch(menuProvider);

    return menuState.when(
      data: (menuItems) {
        if (menuItems.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.spacing32),
              child: Text(
                'No items available',
                style: TextStyle(
                  fontSize: AppTypography.fontSize16,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          );
        }

        // Filter items based on selected filter
        final filteredItems = _getFilteredItems(menuItems);

        // Group by category
        final categories = _getItemsByCategory(filteredItems);

        if (categories.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.spacing32),
              child: Text(
                'No items match the selected filter',
                style: TextStyle(
                  fontSize: AppTypography.fontSize16,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: categories.entries.map((entry) {
            return _buildCategorySection(entry.key, entry.value);
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSizes.spacing32),
          child: CircularProgressIndicator(
            color: AppColors.primaryGreen,
          ),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing32),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: AppSizes.icon48,
                color: AppColors.errorColor,
              ),
              const SizedBox(height: AppSizes.spacing16),
              Text(
                'Failed to load menu items',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing16),
              ElevatedButton(
                onPressed: _loadMenuItems,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(String category, List<MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category == "Lean Mass Gain"? "High Protein Meals":
          category == "BMI Maintenance"? "Balanced Meals":
          category == "Fat Loss"? "High Fibre Meals":"Others"
          ,
          style: const TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.darkGreen,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSizes.spacing8),
          itemBuilder: (context, index) {
            return _buildMenuItem(items[index]);
          },
        ),
        const SizedBox(height: AppSizes.spacing12),
      ],
    );
  }

  Widget _buildMenuItem(MenuItem item) {
    final isInCart = ref.watch(cartProvider.notifier).isInCart(item.id);
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: AppSizes.shadowBlur10,
            offset: const Offset(0, AppSizes.spacing4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular food image
          Container(
            width: AppSizes.icon60,
            height: AppSizes.icon60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
            ),
            child: ClipOval(
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.restaurant,
                      size: AppSizes.icon32,
                      color: AppColors.primaryGreen,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          // Food details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Container(
                    //   width: AppSizes.spacing8,
                    //   height: AppSizes.spacing8,
                    //   margin: const EdgeInsets.only(right: AppSizes.spacing6),
                    //   decoration: BoxDecoration(
                    //     color: item.isVeg ? Colors.green : Colors.red,
                    //     shape: BoxShape.circle,
                    //     border: Border.all(
                    //       color: item.isVeg ? Colors.green : Colors.red,
                    //       width: AppSizes.borderThin,
                    //     ),
                    //   ),
                    // ),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize16,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: AppSizes.icon14,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: AppSizes.spacing4),
                    Text(
                      '${item.calories} ${AppStrings.kcal}',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.regular,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    if (item.rating > 0) ...[
                      const Icon(
                        Icons.star,
                        size: AppSizes.icon14,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: AppSizes.spacing4),
                      Text(
                        item.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize12,
                          fontWeight: AppTypography.medium,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.spacing4),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${item.price.toInt()}',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize18,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => FoodDetailPopup(menuItem: item),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.spacing20,
                          vertical: AppSizes.spacing4,
                        ),
                        decoration: BoxDecoration(
                          color: isInCart
                              ? AppColors.primaryGreen.withValues(alpha: 0.1)
                              : AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(AppSizes.radius4),
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
                            color: isInCart ? AppColors.primaryGreen : Colors.white,
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
          // Price and Add button


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
          // Cart Icon with Item Count
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
          // Item Count Text
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
          // Proceed to Checkout Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CheckoutScreen(),
                ),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    AppStrings.proceedToCheckout,
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      fontWeight: AppTypography.semiBold,
                      color: AppColors.primaryGreen,
                      fontFamily: 'Lato',
                    ),
                  ),
                  // const SizedBox(width: AppSizes.spacing4),
                  // const Icon(
                  //   Icons.delete_outline,
                  //   color: AppColors.primaryGreen,
                  //   size: AppSizes.icon16,
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
