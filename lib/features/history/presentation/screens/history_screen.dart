import 'package:fitkhao_user/core/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/order_history_model.dart';
import '../../providers/order_history_provider.dart';
import 'order_tracking_screen.dart';

enum _HistoryFilter { upcoming, delivered }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryFilter _selected = _HistoryFilter.upcoming;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load order history when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderHistoryProvider.notifier).loadOrderHistory(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(orderHistoryProvider);
    final historyNotifier = ref.read(orderHistoryProvider.notifier);

    // Filter orders based on selection
    final orders = _selected == _HistoryFilter.upcoming
        ? historyNotifier.upcomingOrders
        : historyNotifier.deliveredOrders;
    final filteredOrders = _filterOrders(orders, _searchQuery);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSizes.spacing12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.screenPaddingHorizontal,
                    ),
                    child: _buildSegmentedControl(context),
                  ),
                  const SizedBox(height: AppSizes.spacing12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.screenPaddingHorizontal,
                    ),
                    child: _buildSearchBar(),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  Expanded(
                    child: Material(
                      color: AppColors.textWhite,
                      child: historyState.isLoading &&
                              historyState.orders.isEmpty
                          ? _buildLoadingState()
                          : historyState.error != null &&
                                  historyState.orders.isEmpty
                              ? _buildErrorState(
                                  historyState.error!,
                                  historyNotifier,
                                )
                              : filteredOrders.isEmpty
                                  ? _searchQuery.trim().isNotEmpty
                                      ? _buildNoResultsState(_searchQuery)
                                      : _buildEmptyState()
                                  : RefreshIndicator(
                                      onRefresh: () =>
                                          historyNotifier.refresh(),
                                      child: ListView.separated(
                                        padding: const EdgeInsets.only(
                                          left:
                                              AppSizes.screenPaddingHorizontal,
                                          right:
                                              AppSizes.screenPaddingHorizontal,
                                          bottom: AppSizes.spacing24,
                                        ),
                                        itemCount: filteredOrders.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(
                                                height: AppSizes.spacing12),
                                        itemBuilder: (context, index) {
                                          final order = filteredOrders[index];
                                          return _OrderCard(
                                            order: order,
                                            isUpcoming: _selected ==
                                                _HistoryFilter.upcoming,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      OrderTrackingScreen(
                                                          order: order),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primaryGreen),
    );
  }

  List<OrderHistory> _filterOrders(List<OrderHistory> orders, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return orders;

    final tokens = trimmed.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

    return orders.where((order) {
      final haystack = [
        order.orderNumber,
        order.kitchen.name,
        order.orderStatus,
        order.orderType,
        order.deliverySlot.slotName,
        order.deliverySlot.slotStartTime,
        order.deliverySlot.slotEndTime,
        ...order.items.map((i) => i.itemName),
      ].join(' ').toLowerCase();

      return tokens.every(haystack.contains);
    }).toList();
  }

  Widget _buildErrorState(String error, OrderHistoryNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.errorColor,
            ),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              error,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: AppTypography.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.spacing16),
            ElevatedButton(
              onPressed: () => notifier.refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              'No results for "${query.trim()}"',
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: AppTypography.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.spacing12),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              child: const Text(
                'Clear search',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.primaryGreen,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5EC),
        borderRadius: BorderRadius.circular(
          context.responsiveSpacing(AppSizes.radius50),
        ),
        border: Border.all(
          color: AppColors.primaryGreen,
          width: AppSizes.borderThin,
        ),
      ),
      child: Row(
        children: [
          _SegmentChip(
            label: 'Upcoming',
            selected: _selected == _HistoryFilter.upcoming,
            onTap: () => setState(() => _selected = _HistoryFilter.upcoming),
          ),
          _SegmentChip(
            label: 'Delivered',
            selected: _selected == _HistoryFilter.delivered,
            onTap: () => setState(() => _selected = _HistoryFilter.delivered),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.history, size: 48, color: AppColors.textTertiary),
          SizedBox(height: AppSizes.spacing12),
          Text(
            'No orders to show',
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textSecondary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
        ],
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
          // GestureDetector(
          //   onTap: () => context.pop(),
          //   child: Container(
          //     padding: const EdgeInsets.all(AppSizes.spacing8),
          //     decoration: BoxDecoration(
          //       color: AppColors.darkGreen,
          //       borderRadius: BorderRadius.circular(AppSizes.radius8),
          //     ),
          //     child: const Icon(
          //       Icons.arrow_back,
          //       color: AppColors.textWhite,
          //       size: AppSizes.icon24,
          //     ),
          //   ),
          // ),
          // const SizedBox(width: AppSizes.spacing12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Order History",
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: _showLogoutConfirmation,
            child: Icon(Icons.logout_outlined, color: AppColors.darkGreen),
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
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
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
            icon: Icon(
              _searchQuery.trim().isEmpty ? Icons.close : Icons.close,
              color: _searchQuery.trim().isEmpty
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
              size: AppSizes.icon24,
            ),
            onPressed: () {
              if (_searchQuery.trim().isEmpty) {
                // TODO: Implement voice search
                return;
              }
              setState(() {
                _searchController.clear();
                _searchQuery = '';
              });
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

  /// Show logout confirmation dialog
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontSize: AppTypography.fontSize18,
              fontWeight: AppTypography.bold,
              color: AppColors.textPrimary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textSecondary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textSecondary,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  color: Colors.white,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Handle logout process
  Future<void> _handleLogout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );

      // Perform logout
      final authNotifier = ref.read(authProvider.notifier);
      final success = await authNotifier.logout();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success && mounted) {
        // Navigate to phone auth screen and clear navigation stack
        context.go(RouteNames.phoneAuth);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: AppColors.successColor,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to logout. Please try again.'),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsiveSpacing(16.0),
            vertical: context.responsiveSpacing(10.0),
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(
              context.responsiveSpacing(AppSizes.spacing30),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: context.responsiveFontSize(AppTypography.fontSize14),
                fontWeight: AppTypography.semiBold,
                color: selected ? Colors.white : AppColors.textPrimary,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderHistory order;
  final bool isUpcoming;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.isUpcoming,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radius4),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius4),
          border: Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppSizes.opacity08),
              blurRadius: AppSizes.shadowBlur12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p12),
          child: Row(
            children: [
              // Kitchen logo/icon placeholder
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                  child: Image.network(
                    "https://media.istockphoto.com/id/877317520/photo/burgers-on-the-dark-rustic-background.jpg?s=612x612&w=0&k=20&c=3wXk0Lh-aKBjzvqqmujDOhUXEaydf4M__eT9xzyxM_A=",
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: order.items.map((item) {
                              return Text(
                                item.itemName,
                                style: const TextStyle(
                                  fontSize: AppTypography.fontSize14,
                                  fontWeight: AppTypography.semiBold,
                                  color: AppColors.textPrimary,
                                  fontFamily: AppTypography.fontFamily,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.darkGreen,
                        ),
                      ],
                    ),
                    Text(
                      'Order #${order.orderNumber} • ${order.items.length} items • (${order.kitchen.name} kitchen)',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary,
                        fontFamily: AppTypography.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _statusPill(
                          _getStatusText(order.orderStatus),
                          _getStatusColor(order.orderStatus),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(order.createdAt),
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize12,
                            color: AppColors.textTertiary,
                            fontFamily: AppTypography.fontFamily,
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
      ),
    );
  }

  static Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p10,
        vertical: AppSizes.p4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTypography.fontSize12,
          fontWeight: AppTypography.semiBold,
          color: color,
          fontFamily: AppTypography.fontFamily,
        ),
      ),
    );
  }

  static String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'prepared':
        return 'Prepared';
      case 'out_for_delivery':
      case 'out-for-delivery':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  static Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'preparing':
        return Colors.orange;
      case 'prepared':
        return AppColors.primaryGreen;
      case 'out_for_delivery':
      case 'out-for-delivery':
        return Colors.blue;
      case 'delivered':
        return AppColors.textSecondary;
      case 'cancelled':
        return AppColors.errorColor;
      default:
        return AppColors.textSecondary;
    }
  }

  static String _formatDate(String dateStr) {
    try {
      // 1. Parse the UST/UTC time
      DateTime utcDate = DateTime.parse(dateStr);

      // 2. Convert to IST (UTC + 5:30)
      DateTime istDate = utcDate.add(const Duration(hours: 5, minutes: 30));

      // 3. Use IST for further calculations
      final now = DateTime.now();
      final difference = now.difference(istDate);

      if (difference.inDays == 0) {
        final h = istDate.hour % 12 == 0 ? 12 : istDate.hour % 12;
        final m = istDate.minute.toString().padLeft(2, '0');
        final ampm = istDate.hour >= 12 ? 'PM' : 'AM';
        return '$h:$m $ampm';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${istDate.day}/${istDate.month}/${istDate.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }
}
