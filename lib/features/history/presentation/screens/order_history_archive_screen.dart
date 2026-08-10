import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/shimmer_effect.dart';
import '../../models/order_history_model.dart';
import '../../providers/order_history_provider.dart';
import 'order_tracking_screen.dart';

/// Full order-history archive — every order (outlet + subscription) up to
/// today, each tagged by its source. Opened from the profile menu.
class OrderHistoryArchiveScreen extends ConsumerStatefulWidget {
  const OrderHistoryArchiveScreen({super.key});

  @override
  ConsumerState<OrderHistoryArchiveScreen> createState() =>
      _OrderHistoryArchiveScreenState();
}

class _OrderHistoryArchiveScreenState
    extends ConsumerState<OrderHistoryArchiveScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderHistoryArchiveProvider.notifier).load(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      final state = ref.read(orderHistoryArchiveProvider);
      if (state.hasMore && !state.isLoading) {
        ref.read(orderHistoryArchiveProvider.notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderHistoryArchiveProvider);
    final notifier = ref.read(orderHistoryArchiveProvider.notifier);
    final orders = state.orders;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Material(
                  color: AppColors.textWhite,
                  child: state.isLoading && orders.isEmpty
                      ? _buildLoading()
                      : state.error != null && orders.isEmpty
                          ? _buildError(state.error!, notifier)
                          : orders.isEmpty
                              ? _buildEmpty()
                              : RefreshIndicator(
                                  color: AppColors.primaryGreen,
                                  onRefresh: () => notifier.refresh(),
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSizes.screenPaddingHorizontal,
                                      AppSizes.spacing12,
                                      AppSizes.screenPaddingHorizontal,
                                      AppSizes.spacing24,
                                    ),
                                    itemCount:
                                        orders.length + (state.hasMore ? 1 : 0),
                                    separatorBuilder: (_, __) => const SizedBox(
                                        height: AppSizes.spacing12),
                                    itemBuilder: (context, index) {
                                      if (index >= orders.length) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: AppSizes.spacing16),
                                          child: Center(
                                            child: SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primaryGreen,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      final order = orders[index];
                                      return _ArchiveOrderCard(
                                        order: order,
                                        onTap: () => Navigator.push<void>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => OrderTrackingScreen(
                                                order: order),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                ),
              ),
            ],
          ),
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
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.spacing8),
              decoration: BoxDecoration(
                color: AppColors.darkGreen,
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.textWhite, size: AppSizes.icon24),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          const Text(
            'Order History',
            style: TextStyle(
              fontSize: AppTypography.fontSize20,
              fontWeight: AppTypography.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.1,
            color: Colors.grey.shade100,
            child: ShimmerEffect(child: Container(color: Colors.grey.shade100)),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String error, OrderHistoryArchiveNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.errorColor),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            ElevatedButton(
              onPressed: () => notifier.refresh(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 48, color: AppColors.textTertiary),
          SizedBox(height: AppSizes.spacing12),
          Text(
            'No order history yet',
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
}

/// A read-only history row with a source tag (Outlet / Subscription).
class _ArchiveOrderCard extends StatelessWidget {
  const _ArchiveOrderCard({required this.order, required this.onTap});

  final OrderHistory order;
  final VoidCallback onTap;

  bool get _isSubscription =>
      order.paymentMethod.trim().toLowerCase() == 'subscription' ||
      order.orderSource == 'subscription_slot';

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
        padding: const EdgeInsets.all(AppSizes.p12),
        child: Row(
          children: [
            _dishImage(
                order.items.isNotEmpty ? order.items.first.dishImage : null),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.items.isNotEmpty
                              ? order.items.first.itemName
                              : 'Order',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.textPrimary,
                            fontFamily: AppTypography.fontFamily,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.spacing8),
                      _sourceTag(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order #${order.orderNumber} • ${order.items.length} '
                    '${order.items.length == 1 ? 'item' : 'items'} • '
                    '${order.kitchen.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: AppColors.textSecondary,
                      fontFamily: AppTypography.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _statusPill(
                        _statusText(order.orderStatus),
                        _statusColor(order.orderStatus),
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
    );
  }

  Widget _sourceTag() {
    final label = _isSubscription ? 'Subscription' : 'Outlet';
    final color =
        _isSubscription ? AppColors.primaryGreen : const Color(0xFFC66301);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTypography.fontSize10,
          fontWeight: AppTypography.bold,
          color: color,
          fontFamily: 'Lato',
        ),
      ),
    );
  }

  static Widget _dishImage(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radius4),
      child: SizedBox(
        width: 62,
        height: 62,
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                width: 62,
                height: 62,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  static Widget _placeholder() => Container(
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        child: const Center(
          child:
              Icon(Icons.restaurant, size: 26, color: AppColors.primaryGreen),
        ),
      );

  static Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p10, vertical: AppSizes.p4),
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

  static String _statusText(String status) {
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

  static Color _statusColor(String status) {
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
      final ist =
          DateTime.parse(dateStr).add(const Duration(hours: 5, minutes: 30));
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${ist.day} ${months[ist.month - 1]} ${ist.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
