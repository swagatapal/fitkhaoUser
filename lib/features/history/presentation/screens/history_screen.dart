import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fitkhao_user/core/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../shared/widgets/shimmer_effect.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../policy/models/app_constants_model.dart';
import '../../../policy/providers/app_constants_provider.dart';
import '../../models/order_history_model.dart';
import '../../providers/order_history_provider.dart';
import '../widgets/eta_countdown.dart';
import '../widgets/subscription_slot_change_sheet.dart';
import 'order_tracking_screen.dart';
import '../../../delivery/models/cart_item.dart';
import '../../../delivery/models/menu_item.dart';
import '../../../delivery/providers/cart_provider.dart';
import '../../../delivery/presentation/screens/checkout_screen.dart';

/// Which tab the history screen opens on.
enum HistoryTab { upcoming, delivered }

class HistoryScreen extends ConsumerStatefulWidget {
  /// Tab to display first — defaults to [HistoryTab.upcoming].
  final HistoryTab initialTab;

  const HistoryScreen({super.key, this.initialTab = HistoryTab.upcoming});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late HistoryTab _selected = widget.initialTab;
  final TextEditingController _searchController = TextEditingController();

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

    // Pull the cancel window from the backend; fall back to defaults while
    // loading or if the request fails — the card never shows NaN / 0.
    final cancelWindowSeconds =
        ref.watch(appConstantsProvider).valueOrNull?.cancelOrderWindowSeconds ??
            AppConstants.defaults.cancelOrderWindowSeconds;

    // Filter orders based on selection
    final orders = _selected == HistoryTab.upcoming
        ? historyNotifier.upcomingOrders
        : historyNotifier.deliveredOrders;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(widget.initialTab),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSizes.spacing12),
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(
                    //     horizontal: AppSizes.screenPaddingHorizontal,
                    //   ),
                    //   child: _buildSearchBar(),
                    // ),
                    // const SizedBox(height: AppSizes.spacing8),
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
                                : orders.isEmpty
                                    ? _buildEmptyState()
                                    : RefreshIndicator(
                                        onRefresh: () =>
                                            historyNotifier.refresh(),
                                        child: ListView.separated(
                                          padding: const EdgeInsets.only(
                                            left: AppSizes
                                                .screenPaddingHorizontal,
                                            right: AppSizes
                                                .screenPaddingHorizontal,
                                            bottom: AppSizes.spacing24,
                                          ),
                                          itemCount: orders.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(
                                                  height: AppSizes.spacing12),
                                          itemBuilder: (context, index) {
                                            final order = orders[index];
                                            return _OrderCard(
                                              order: order,
                                              isUpcoming: _selected ==
                                                  HistoryTab.upcoming,
                                              cancelWindowSeconds:
                                                  cancelWindowSeconds,
                                              onTap: () => Navigator.push<void>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      OrderTrackingScreen(
                                                          order: order),
                                                ),
                                              ),
                                              onCancelOrder: _cancelOrder,
                                              onCancelSuccess: () {
                                                ref
                                                    .read(orderHistoryProvider
                                                        .notifier)
                                                    .refresh();
                                              },
                                              onReorder: () => _reorder(order),
                                              onChangeSlot: () =>
                                                  _changeSubscriptionSlot(
                                                      order),
                                            );
                                          },
                                        ),
                                      ),
                      ),
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

  Widget _buildLoadingState() {
    return Center(
        child: ListView.builder(
      itemCount: 6,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: EdgeInsets.only(left: 16.0, right: 16, top: 16),
          child: _shimmerCard(height: MediaQuery.of(context).size.height * 0.1),
        );
      },
    )

        // Padding(
        //   padding: const EdgeInsets.all(16.0),
        //   child: Column(
        //     children: [
        //       _shimmerCard(height: MediaQuery.of(context).size.height*0.1),
        //       const SizedBox(height: AppSizes.spacing16),
        //       _shimmerCard(height: MediaQuery.of(context).size.height*0.1),
        //       const SizedBox(height: AppSizes.spacing16),
        //       _shimmerCard(height: MediaQuery.of(context).size.height*0.1),
        //       const SizedBox(height: AppSizes.spacing16),
        //       _shimmerCard(height: MediaQuery.of(context).size.height*0.1),
        //       const SizedBox(height: AppSizes.spacing16),
        //       _shimmerCard(height: MediaQuery.of(context).size.height*0.1),
        //       const SizedBox(height: AppSizes.spacing16),
        //
        //
        //     ],
        //   ),
        // ),
        );
  }

  Widget _shimmerCard({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ShimmerEffect(child: Container(color: Colors.grey.shade100)),
      ),
    );
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
            selected: _selected == HistoryTab.upcoming,
            onTap: () => setState(() => _selected = HistoryTab.upcoming),
          ),
          _SegmentChip(
            label: 'Delivered',
            selected: _selected == HistoryTab.delivered,
            onTap: () => setState(() => _selected = HistoryTab.delivered),
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

  Future<void> _cancelOrder(String orderId, String reason) async {
    final orderRepo = ref.read(orderRepositoryProvider);
    final response = await orderRepo.cancelOrder(
      orderId: orderId,
      reason: reason,
    );

    if (response['success'] != true) {
      throw Exception(
        response['message'] as String? ?? 'Failed to cancel order',
      );
    }
  }

  /// Change a subscription order's delivery slot/address via the bottom sheet.
  Future<void> _changeSubscriptionSlot(OrderHistory order) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubscriptionSlotChangeSheet(order: order),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Delivery updated successfully.'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ));
      await ref.read(orderHistoryProvider.notifier).refresh();
    }
  }

  Widget _buildHeader(HistoryTab tabStatus) {
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
            onTap: () => Navigator.of(context).maybePop(),
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
                  tabStatus == HistoryTab.upcoming
                      ? 'Upcoming Orders'
                      : 'Delivered Orders',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
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
          // suffixIcon: IconButton(
          //   icon: const Icon(
          //     Icons.mic,
          //     color: AppColors.primaryGreen,
          //     size: AppSizes.icon24,
          //   ),
          //   onPressed: () {
          //     // TODO: Implement voice search
          //   },
          // ),
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

  /// Replaces the cart with items from [order] and navigates to checkout.
  void _reorder(OrderHistory order) {
    final cartItems = order.items.map((item) {
      return CartItem(
        menuItem: MenuItem(
          id: item.dishId,
          name: item.itemName,
          imageUrl: item.dishImage ?? '',
          calories: item.nutritionalInfo?.kcal.toInt() ?? 0,
          price: item.itemPrice,
          category: '',
          isVeg: true,
          protein: item.nutritionalInfo != null
              ? '${item.nutritionalInfo!.protein.toStringAsFixed(1)}g'
              : '0g',
          carbs: item.nutritionalInfo != null
              ? '${item.nutritionalInfo!.carbs.toStringAsFixed(1)}g'
              : '0g',
          fats: item.nutritionalInfo != null
              ? '${item.nutritionalInfo!.fat.toStringAsFixed(1)}g'
              : '0g',
        ),
        quantity: item.quantity,
      );
    }).toList();

    ref.read(cartProvider.notifier).reorder(cartItems);
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
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

class _OrderCard extends StatefulWidget {
  final OrderHistory order;
  final bool isUpcoming;
  final int cancelWindowSeconds;
  final VoidCallback onTap;
  final Future<void> Function(String orderId, String reason)? onCancelOrder;
  final VoidCallback? onCancelSuccess;
  final VoidCallback? onReorder;

  /// Opens the change-slot/address sheet (subscription orders only).
  final VoidCallback? onChangeSlot;

  const _OrderCard({
    required this.order,
    required this.isUpcoming,
    required this.cancelWindowSeconds,
    required this.onTap,
    this.onCancelOrder,
    this.onCancelSuccess,
    this.onReorder,
    this.onChangeSlot,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  static const _cancellableStatuses = {'pending', 'confirmed'};

  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  bool get _canCancel {
    final status = widget.order.orderStatus.toLowerCase();
    return widget.isUpcoming &&
        widget.onCancelOrder != null &&
        _cancellableStatuses.contains(status) &&
        _remainingSeconds > 0;
  }

  bool get _canReorder => !widget.isUpcoming && widget.onReorder != null;

  /// Slot/address change is only for subscription-slot orders that haven't
  /// reached a terminal / in-transit state (the 6 AM IST deadline is enforced
  /// server-side).
  static const _slotChangeBlockedStatuses = {
    'delivered',
    'cancelled',
    'failed',
    'rejected',
    'out_for_delivery',
  };

  bool get _canChangeSlot =>
      widget.isUpcoming &&
      widget.onChangeSlot != null &&
      widget.order.orderSource == 'subscription_slot' &&
      !_slotChangeBlockedStatuses
          .contains(widget.order.orderStatus.toLowerCase());

  @override
  void initState() {
    super.initState();
    _startOrStopCountdown(rebuild: false);
  }

  @override
  void didUpdateWidget(covariant _OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.createdAt != widget.order.createdAt ||
        oldWidget.order.orderStatus != widget.order.orderStatus ||
        oldWidget.isUpcoming != widget.isUpcoming) {
      _startOrStopCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startOrStopCountdown({bool rebuild = true}) {
    _countdownTimer?.cancel();
    final remainingSeconds = _calculateRemainingSeconds();
    final status = widget.order.orderStatus.toLowerCase();
    final shouldShowCountdown = widget.isUpcoming &&
        widget.onCancelOrder != null &&
        _cancellableStatuses.contains(status) &&
        remainingSeconds > 0;

    if (rebuild) {
      setState(() {
        _remainingSeconds = remainingSeconds;
      });
    } else {
      _remainingSeconds = remainingSeconds;
    }

    if (!shouldShowCountdown) {
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final remainingSeconds = _calculateRemainingSeconds();
      if (remainingSeconds <= 0) {
        _countdownTimer?.cancel();
      }

      setState(() {
        _remainingSeconds = remainingSeconds;
      });
    });
  }

  int _calculateRemainingSeconds() {
    try {
      final createdAt = DateTime.parse(widget.order.createdAt).toLocal();
      final expiresAt = createdAt.add(
        Duration(seconds: widget.cancelWindowSeconds),
      );
      final remaining = expiresAt.difference(DateTime.now()).inSeconds;
      return remaining > 0 ? remaining : 0;
    } catch (_) {
      return 0;
    }
  }

  String _buildCountdownLabel() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final parts = <String>[];

    if (minutes > 0) {
      parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
    }
    if (seconds > 0 || parts.isEmpty) {
      parts.add('$seconds ${seconds == 1 ? 'second' : 'seconds'}');
    }

    return '${parts.join(' ')} left';
  }

  void _showCancelModal(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CancelOrderModal(
        orderNumber: widget.order.orderNumber,
        onCancel: (reason) => widget.onCancelOrder!(widget.order.id, reason),
      ),
    ).then((cancelled) {
      if (cancelled != true) return;

      widget.onCancelSuccess?.call();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Order cancelled successfully'),
          backgroundColor: AppColors.successColor,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.p12),
              child: Row(
                children: [
                  _buildDishImage(
                    widget.order.items.isNotEmpty
                        ? widget.order.items.first.dishImage
                        : null,
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
                                children: widget.order.items.map((item) {
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
                          'Order #${widget.order.orderNumber} • ${widget.order.items.length} items • (${widget.order.kitchen.name} )',
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
                              _getStatusText(widget.order.orderStatus),
                              _getStatusColor(widget.order.orderStatus),
                            ),
                            const Spacer(),
                            Text(
                              _formatDate(widget.order.createdAt),
                              style: const TextStyle(
                                fontSize: AppTypography.fontSize12,
                                color: AppColors.textTertiary,
                                fontFamily: AppTypography.fontFamily,
                              ),
                            ),
                          ],
                        ),
                        if (widget.order.hasLiveEta) ...[
                          const SizedBox(height: AppSizes.spacing8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: EtaCountdown(
                              estimatedDeliveryAt:
                                  widget.order.estimatedDeliveryAt!,
                              compact: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_canChangeSlot) _buildChangeSlotSection(),
            if (_canCancel) _buildCancelSection(context),
            if (_canReorder) _buildReorderSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeSlotSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: AppColors.borderColor),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p12,
            vertical: AppSizes.spacing8,
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onChangeSlot,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: BorderSide(
                    color: AppColors.primaryGreen.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
              ),
              icon: const Icon(Icons.edit_calendar_rounded,
                  size: AppSizes.icon16),
              label: const Text(
                'Change slot / address',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReorderSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: AppColors.borderColor),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p12,
            vertical: AppSizes.spacing8,
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onReorder,
              icon: const Icon(Icons.refresh_rounded, size: AppSizes.icon16),
              label: const Text(
                'Reorder',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSizes.spacing8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelSection(BuildContext context) {
    final countdownLabel = _buildCountdownLabel();

    Widget countdownChip() {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing8,
          vertical: AppSizes.spacing4,
        ),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.radius4),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.timer_outlined,
              size: AppSizes.icon14,
              color: Colors.orange,
            ),
            const SizedBox(width: AppSizes.spacing4),
            Flexible(
              child: Text(
                countdownLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.semiBold,
                  color: Colors.orange,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget cancelButton() {
      return OutlinedButton(
        onPressed: () => _showCancelModal(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.errorColor,
          side: const BorderSide(color: AppColors.errorColor),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing8,
            vertical: AppSizes.spacing6,
          ),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius4),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(Icons.cancel_outlined, size: AppSizes.icon16),
            SizedBox(width: AppSizes.spacing4),
            Flexible(
              child: Text(
                'Cancel Order',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: AppTypography.fontSize13,
                  fontWeight: AppTypography.semiBold,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: AppColors.borderColor),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p12,
            vertical: AppSizes.spacing8,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cancelButtonWidth =
                  (constraints.maxWidth * 0.42).clamp(118.0, 148.0).toDouble();

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: countdownChip(),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacing8),
                  SizedBox(
                    width: cancelButtonWidth,
                    child: cancelButton(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static Widget _buildDishImage(String? imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radius4),
      child: SizedBox(
        width: 70,
        height: 70,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _DishImagePlaceholder(),
                errorWidget: (_, __, ___) => const _DishImagePlaceholder(),
              )
            : const _DishImagePlaceholder(),
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
    switch (status.trim().toLowerCase().replaceAll('-', '_')) {
      case 'pending':
        return 'Pending';

      case 'confirmed':
        return 'Confirmed';

      case 'accepted_by_kitchen':
        return 'Accepted by Kitchen';

      case 'preparing':
        return 'Preparing';

      case 'prepared':
        return 'Prepared';

      case 'assigned':
        return 'Rider Assigned';

      case 'out_for_delivery':
        return 'On the way';

      case 'delivered':
        return 'Delivered';

      case 'cancelled':
        return 'Cancelled';

      case 'rejected':
        return 'Rejected';

      case 'failed':
        return 'Failed';

      default:
        return status;
    }
  }

  static Color _getStatusColor(String status) {
    switch (status.trim().toLowerCase().replaceAll('-', '_')) {
      case 'pending':
      case 'confirmed':
        return Colors.orange;

      case 'accepted_by_kitchen':
      case 'preparing':
      case 'prepared':
        return AppColors.primaryGreen;

      case 'assigned':
      case 'out_for_delivery':
        return Colors.blue;

      case 'delivered':
        return AppColors.successColor;

      case 'cancelled':
      case 'rejected':
      case 'failed':
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
    } catch (_) {
      return dateStr;
    }
  }
}

class _CancelOrderModal extends StatefulWidget {
  final String orderNumber;
  final Future<void> Function(String reason) onCancel;

  const _CancelOrderModal({
    required this.orderNumber,
    required this.onCancel,
  });

  @override
  State<_CancelOrderModal> createState() => _CancelOrderModalState();
}

class _CancelOrderModalState extends State<_CancelOrderModal> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitCancellation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onCancel(_reasonController.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.spacing12),
                      decoration: BoxDecoration(
                        color: AppColors.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radius8),
                      ),
                      child: const Icon(
                        Icons.cancel,
                        color: AppColors.errorColor,
                        size: AppSizes.icon24,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    const Expanded(
                      child: Text(
                        'Cancel Order',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize20,
                          fontWeight: AppTypography.bold,
                          color: AppColors.textPrimary,
                          fontFamily: AppTypography.fontFamily,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing16),
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: AppColors.primaryGreen,
                        size: AppSizes.icon20,
                      ),
                      const SizedBox(width: AppSizes.spacing8),
                      Expanded(
                        child: Text(
                          'Order #${widget.orderNumber}',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.textPrimary,
                            fontFamily: AppTypography.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spacing20),
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: AppSizes.icon20,
                      ),
                      const SizedBox(width: AppSizes.spacing8),
                      Expanded(
                        child: Text(
                          'Your payment will be refunded to your wallet within 2-3 business days.',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize12,
                            color: Colors.orange.shade800,
                            fontFamily: AppTypography.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spacing20),
                const Text(
                  'Reason for Cancellation',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 4,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    hintText:
                        'Please tell us why you want to cancel this order (minimum 10 characters)',
                    hintStyle: const TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: AppColors.textTertiary,
                      fontFamily: AppTypography.fontFamily,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(
                        color: AppColors.borderColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(
                        color: AppColors.borderColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(
                        color: AppColors.errorColor,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(
                        color: AppColors.errorColor,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing16,
                      vertical: AppSizes.spacing12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please provide a reason for cancellation';
                    }
                    if (value.trim().length < 10) {
                      return 'Reason must be at least 10 characters long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.spacing24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.p16,
                          ),
                          side: const BorderSide(color: AppColors.borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radius4,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.textPrimary,
                            fontFamily: AppTypography.fontFamily,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitCancellation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorColor,
                          disabledBackgroundColor:
                              AppColors.errorColor.withValues(
                            alpha: 0.5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.p16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radius4,
                            ),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Confirm Cancel',
                                style: TextStyle(
                                  fontSize: AppTypography.fontSize14,
                                  fontWeight: AppTypography.semiBold,
                                  color: Colors.white,
                                  fontFamily: AppTypography.fontFamily,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DishImagePlaceholder extends StatelessWidget {
  const _DishImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.restaurant,
        size: 32,
        color: AppColors.primaryGreen,
      ),
    );
  }
}
