import 'package:cached_network_image/cached_network_image.dart';
import 'package:fitkhao_user/features/profile/presentation/screens/profile_menu_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/order_history_model.dart';
import '../../providers/order_history_provider.dart';
import '../widgets/eta_countdown.dart';
import '../widgets/order_review_sheet.dart';
import '../../../policy/models/app_constants_model.dart';
import '../../../policy/providers/app_constants_provider.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  /// The order to show. May be null when the screen is opened by id only
  /// (e.g. from the subscription meals list) — details are then fetched.
  final OrderHistory? order;

  /// Order id to fetch when a full [order] object isn't available.
  final String? orderId;

  const OrderTrackingScreen({super.key, required OrderHistory this.order})
      : orderId = null;

  /// Opens the screen with only an order id; the full details are fetched.
  const OrderTrackingScreen.byId({super.key, required String this.orderId})
      : order = null;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  String get _orderId => widget.order?.id ?? widget.orderId!;

  @override
  Widget build(BuildContext context) {
    final orderId = _orderId;
    final detailsAsync = ref.watch(orderDetailsProvider(orderId));

    // Show the order passed from the list instantly; swap in the freshly
    // fetched details the moment they arrive (no blank-screen flash). When
    // opened by id there's no fallback yet, so show a loader/error until the
    // fetch resolves.
    final order = detailsAsync.valueOrNull ?? widget.order;
    final isRefreshing = detailsAsync.isLoading;

    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: detailsAsync.hasError
                    ? _buildDetailsError(orderId)
                    : const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // A fetch failure is non-blocking — the fallback order stays on screen.
    ref.listen<AsyncValue<OrderHistory>>(orderDetailsProvider(orderId),
        (prev, next) {
      if (next.hasError && !next.isLoading && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Couldn’t refresh the latest order details.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.errorColor,
              duration: Duration(seconds: 3),
            ),
          );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (isRefreshing)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Color(0x14000000),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryGreen,
                onRefresh: () =>
                    ref.refresh(orderDetailsProvider(orderId).future),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPaddingHorizontal,
                    vertical: AppSizes.screenPaddingVertical,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OrderSummaryCard(order: order),
                      if (order.hasLiveEta) ...[
                        const SizedBox(height: AppSizes.spacing16),
                        EtaCountdown(
                          estimatedDeliveryAt: order.estimatedDeliveryAt!,
                        ),
                      ],
                      const SizedBox(height: AppSizes.spacing16),
                      _buildOrderItems(order),
                      const SizedBox(height: AppSizes.spacing16),
                      _buildDeliveryDetails(order),
                      const SizedBox(height: AppSizes.spacing16),
                      // Subscription-slot orders are billed via the plan, so we
                      // hide the price breakdown + invoice and simply note that
                      // it's covered by the subscription.
                      if (_isSubscriptionOrder(order))
                        _buildSubscriptionPaidCard()
                      else ...[
                        _buildPriceSummary(order),
                        const SizedBox(height: AppSizes.spacing16),
                        _buildInvoiceButton(order),
                      ],
                      const SizedBox(height: AppSizes.spacing16),
                      const SizedBox(height: AppSizes.spacing16),
                      _buildTimeline(context, order),
                      if (_canReview(order)) ...[
                        const SizedBox(height: AppSizes.spacing20),
                        _buildReviewPrompt(context, order),
                      ],
                      if (!_shouldHideHelpActions(order.orderStatus)) ...[
                        const SizedBox(height: AppSizes.spacing20),
                        _buildHelpRow(context),
                      ],
                      const SizedBox(height: AppSizes.spacing20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Order Details",
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

  Widget _buildOrderItems(OrderHistory order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spacing12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DishImage(url: item.dishImage, size: 50),
                    const SizedBox(width: AppSizes.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: const TextStyle(
                              fontSize: AppTypography.fontSize14,
                              fontWeight: AppTypography.semiBold,
                              color: AppColors.textPrimary,
                              fontFamily: AppTypography.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            children: [
                              (item.nutritionalInfo?.kcal == 0.0)
                                  ? SizedBox.shrink()
                                  : Text(
                                      '• ${item.nutritionalInfo!.kcal.toStringAsFixed(0)} kcal ',
                                      style: const TextStyle(
                                        fontSize: AppTypography.fontSize12,
                                        color: AppColors.textSecondary,
                                        fontFamily: AppTypography.fontFamily,
                                      ),
                                    ),
                              (item.nutritionalInfo?.protein == 0.0)
                                  ? SizedBox.shrink()
                                  : Text(
                                      '• ${item.nutritionalInfo!.protein.toStringAsFixed(1)}g Protein',
                                      style: const TextStyle(
                                        fontSize: AppTypography.fontSize12,
                                        color: AppColors.textSecondary,
                                        fontFamily: AppTypography.fontFamily,
                                      ),
                                    ),
                              (item.nutritionalInfo?.fat == 0.0)
                                  ? SizedBox.shrink()
                                  : Text(
                                      '• ${item.nutritionalInfo!.fat.toStringAsFixed(1)}g Fat',
                                      style: const TextStyle(
                                        fontSize: AppTypography.fontSize12,
                                        color: AppColors.textSecondary,
                                        fontFamily: AppTypography.fontFamily,
                                      ),
                                    ),
                              (item.nutritionalInfo?.carbs == 0.0)
                                  ? SizedBox.shrink()
                                  : Text(
                                      '• ${item.nutritionalInfo!.carbs.toStringAsFixed(1)}g Carbs',
                                      style: const TextStyle(
                                        fontSize: AppTypography.fontSize12,
                                        color: AppColors.textSecondary,
                                        fontFamily: AppTypography.fontFamily,
                                      ),
                                    ),
                            ],
                          ),
                          if (item.specialInstructions != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Note: ${item.specialInstructions}',
                                style: const TextStyle(
                                  fontSize: AppTypography.fontSize12,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textSecondary,
                                  fontFamily: AppTypography.fontFamily,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'x${item.quantity}',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.textPrimary,
                            fontFamily: AppTypography.fontFamily,
                          ),
                        ),
                        // const SizedBox(height: 4),
                        // Text(
                        //   '₹${item.subtotal.toStringAsFixed(0)}',
                        //   style: const TextStyle(
                        //     fontSize: AppTypography.fontSize14,
                        //     fontWeight: AppTypography.bold,
                        //     color: AppColors.primaryGreen,
                        //     fontFamily: AppTypography.fontFamily,
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetails(OrderHistory order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Details',
            style: TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          if (order.deliveryDate.isNotEmpty) ...[
            _buildDetailRow(Icons.calendar_today, 'Delivery Date',
                _formatDeliveryDate(order.deliveryDate)),
            const SizedBox(height: AppSizes.spacing8),
          ],
          if (_formatDeliverySlot(order.deliverySlot).isNotEmpty) ...[
            _buildDetailRow(Icons.access_time, 'Delivery Slot',
                _formatDeliverySlot(order.deliverySlot)),
            const SizedBox(height: AppSizes.spacing8),
          ],
          _buildDetailRow(Icons.location_on, 'Address',
              '${order.deliveryAddress.buildingName}, ${order.deliveryAddress.street}'),
          const SizedBox(height: AppSizes.spacing8),
          _buildDetailRow(
              Icons.phone, 'Contact', order.deliveryAddress.contactNumber),
          if (order.deliveryAddress.deliveryInstructions != null) ...[
            const SizedBox(height: AppSizes.spacing8),
            _buildDetailRow(Icons.note, 'Delivery Instructions',
                order.deliveryAddress.deliveryInstructions!),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGreen),
        const SizedBox(width: AppSizes.spacing8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  color: AppColors.textSecondary,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.medium,
                  color: AppColors.textPrimary,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSummary(OrderHistory order) {
    final pricing = ref.watch(appConstantsProvider).valueOrNull?.pricing ??
        PricingConstants.defaults;

    final subtotal = order.subtotal;
    final platformCharge = pricing.platformFee;
    final deliveryCharge = pricing.deliveryCharge;
    final tax = (subtotal + platformCharge) * pricing.gstRate;
    final discount = order.discount;
    final total = subtotal + tax + platformCharge + deliveryCharge - discount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Summary',
            style: TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          _buildPriceRow('Subtotal', subtotal),
          const SizedBox(height: AppSizes.spacing8),
          _buildPriceRow(
              'Commission and taxes (${((pricing.gstRate) * 100).toStringAsFixed(0)}%)',
              tax),
          const SizedBox(height: AppSizes.spacing8),
          platformCharge == 0.0
              ? SizedBox.shrink()
              : _buildPriceRow('Platform Charge', platformCharge),
          const SizedBox(height: AppSizes.spacing8),
          _buildPriceRow('Delivery Charge', deliveryCharge),
          if (discount > 0) ...[
            const SizedBox(height: AppSizes.spacing8),
            _buildPriceRow('Discount', -discount, isDiscount: true),
          ],
          const Divider(height: AppSizes.spacing20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize18,
                  fontWeight: AppTypography.bold,
                  color: AppColors.primaryGreen,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing8),
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
            child: Row(
              children: [
                Icon(
                  _getPaymentIcon(order.paymentMethod),
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: AppSizes.spacing8),
                Text(
                  'Paid via ${_formatPaymentMethod(order.paymentMethod)}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.medium,
                    color: AppColors.primaryGreen,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount,
      {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            color: AppColors.textSecondary,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
        Text(
          isDiscount
              ? '- ₹${amount.abs().toStringAsFixed(2)}'
              : '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: AppTypography.medium,
            color: isDiscount ? AppColors.successColor : AppColors.textPrimary,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context, OrderHistory order) {
    final currentStatus = _normalizeOrderStatus(order.orderStatus);
    final steps = _getTimelineSteps(currentStatus);
    final currentStatusIndex = _getStatusIndex(currentStatus);
    final isNegativeTerminal = _isNegativeTerminalStatus(currentStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Progress',
            style: TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          const SizedBox(height: AppSizes.spacing16),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final stepStatus = _normalizeOrderStatus(step.status);
            final stepStatusIndex = _getStatusIndex(stepStatus);

            final isCurrent = currentStatus == stepStatus;

            final isCompleted = !isNegativeTerminal &&
                currentStatusIndex > stepStatusIndex &&
                stepStatusIndex >= 0;

            final isLast = index == steps.length - 1;

            return _TimelineTile(
              title: step.title,
              subtitle: step.subtitle,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              showConnector: !isLast,
              isError: isNegativeTerminal && isCurrent,
            );
          }),
        ],
      ),
    );
  }

  List<_OrderTimelineStep> _getTimelineSteps(String currentStatus) {
    if (currentStatus == 'cancelled') {
      return const [
        _OrderTimelineStep(
          status: 'pending',
          title: 'Order Placed',
          subtitle: 'We received your order',
        ),
        _OrderTimelineStep(
          status: 'cancelled',
          title: 'Order Cancelled',
          subtitle: 'This order has been cancelled',
        ),
      ];
    }

    if (currentStatus == 'rejected') {
      return const [
        _OrderTimelineStep(
          status: 'pending',
          title: 'Order Placed',
          subtitle: 'We received your order',
        ),
        _OrderTimelineStep(
          status: 'rejected',
          title: 'Order Rejected',
          subtitle: 'Kitchen rejected this order',
        ),
      ];
    }

    if (currentStatus == 'failed') {
      return const [
        _OrderTimelineStep(
          status: 'pending',
          title: 'Order Initiated',
          subtitle: 'Your order was initiated',
        ),
        _OrderTimelineStep(
          status: 'failed',
          title: 'Order Failed',
          subtitle: 'Something went wrong while placing this order',
        ),
      ];
    }

    return const [
      _OrderTimelineStep(
        status: 'pending',
        title: 'Order Placed',
        subtitle: 'We received your order',
      ),
      _OrderTimelineStep(
        status: 'confirmed',
        title: 'Order Confirmed',
        subtitle: 'Your order has been confirmed',
      ),
      _OrderTimelineStep(
        status: 'accepted_by_kitchen',
        title: 'Accepted by Kitchen',
        subtitle: 'Kitchen accepted your order',
      ),
      _OrderTimelineStep(
        status: 'preparing',
        title: 'Preparing Order',
        subtitle: 'Chef is preparing your meal',
      ),
      _OrderTimelineStep(
        status: 'prepared',
        title: 'Order Prepared',
        subtitle: 'Your meal is ready',
      ),
      _OrderTimelineStep(
        status: 'assigned',
        title: 'Rider Assigned',
        subtitle: 'Delivery partner has been assigned',
      ),
      _OrderTimelineStep(
        status: 'out_for_delivery',
        title: 'Out for Delivery',
        subtitle: 'Rider is on the way',
      ),
      _OrderTimelineStep(
        status: 'delivered',
        title: 'Delivered',
        subtitle: 'Enjoy your meal!',
      ),
    ];
  }

  String _normalizeOrderStatus(String status) {
    return status.trim().toLowerCase().replaceAll('-', '_');
  }

  bool _isNegativeTerminalStatus(String status) {
    final normalizedStatus = _normalizeOrderStatus(status);

    return normalizedStatus == 'cancelled' ||
        normalizedStatus == 'rejected' ||
        normalizedStatus == 'failed';
  }

  bool _shouldHideHelpActions(String status) {
    final normalizedStatus = _normalizeOrderStatus(status);

    return normalizedStatus == 'delivered' ||
        normalizedStatus == 'cancelled' ||
        normalizedStatus == 'rejected' ||
        normalizedStatus == 'failed';
  }

  int _getStatusIndex(String status) {
    switch (_normalizeOrderStatus(status)) {
      case 'pending':
        return 0;

      case 'confirmed':
        return 1;

      case 'accepted_by_kitchen':
        return 2;

      case 'preparing':
        return 3;

      case 'prepared':
        return 4;

      case 'assigned':
        return 5;

      case 'out_for_delivery':
        return 6;

      case 'delivered':
        return 7;

      case 'cancelled':
      case 'rejected':
      case 'failed':
        return 100;

      default:
        return -1;
    }
  }

  /// Subscription-slot orders are paid through the plan, not per order.
  bool _isSubscriptionOrder(OrderHistory order) {
    return order.orderSource.trim().toLowerCase() == 'subscription_slot';
  }

  /// Simple "covered by your subscription" note shown in place of the price
  /// summary + invoice for subscription-slot orders.
  Widget _buildSubscriptionPaidCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border:
            Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing8),
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: AppSizes.icon20,
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paid via subscription',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize15,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'This order is covered by your active subscription plan.',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: AppColors.textSecondary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceButton(OrderHistory order) {
    final isLoading = ref.watch(
      orderHistoryProvider.select((s) => s.isInvoiceLoading(order.id)),
    );

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : _handleViewInvoice,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
          side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
          foregroundColor: AppColors.primaryGreen,
        ),
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryGreen,
                ),
              )
            : const Icon(Icons.receipt_long_rounded, size: AppSizes.icon20),
        label: Text(
          isLoading ? 'Generating Invoice…' : 'View Invoice',
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: AppTypography.semiBold,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsError(String orderId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.errorColor),
            const SizedBox(height: AppSizes.spacing16),
            const Text(
              'Could not load order details. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            ElevatedButton(
              onPressed: () => ref.invalidate(orderDetailsProvider(orderId)),
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

  Future<void> _handleViewInvoice() async {
    final orderId = _orderId;
    try {
      final url = await ref
          .read(orderHistoryProvider.notifier)
          .fetchInvoiceUrl(orderId);

      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the invoice. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  Future<void> _openHelpEmail() async {
    final String subject = Uri.encodeComponent('Help & Support - FitKhao');
    final String body = Uri.encodeComponent(
      'Please tell me what is your problem and how can I help you ? ',
    );

    final Uri emailUri = Uri.parse(
      'mailto:Support@fitkhao.com?subject=$subject&body=$body',
    );

    if (!await launchUrl(emailUri)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open email app. Please email Support@fitkhao.com',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _callKitchen() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '9635139595');
    if (!await launchUrl(phoneUri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open phone dialer. Call: 96351 39595'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _canReview(OrderHistory order) {
    final status = _normalizeOrderStatus(order.orderStatus);
    return status == 'delivered' && !order.isReviewed;
  }

  Widget _buildReviewPrompt(BuildContext context, OrderHistory order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border:
            Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppSizes.opacity08),
            blurRadius: AppSizes.shadowBlur12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: AppColors.primaryGreen,
                  size: AppSizes.icon20,
                ),
              ),
              const SizedBox(width: AppSizes.spacing12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How was your meal?',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize15,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: AppTypography.fontFamily,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your feedback helps us serve you better',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary,
                        fontFamily: AppTypography.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openReviewSheet(context, order),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding:
                    const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Rate Your Order',
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
    );
  }

  void _openReviewSheet(BuildContext context, OrderHistory order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderReviewSheet(order: order),
    );
  }

  Widget _buildHelpRow(BuildContext context) {
    return Row(
      children: [
        // Expanded(
        //   child: OutlinedButton.icon(
        //     onPressed: _openHelpEmail,
        //     style: OutlinedButton.styleFrom(
        //       padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
        //       side: const BorderSide(color: AppColors.primaryGreen),
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(AppSizes.radius4),
        //       ),
        //     ),
        //     icon: const Icon(Icons.support_agent, color: AppColors.primaryGreen),
        //     label: const Text(
        //       'Help & Support',
        //       style: TextStyle(
        //         fontSize: AppTypography.fontSize14,
        //         fontWeight: AppTypography.semiBold,
        //         color: AppColors.primaryGreen,
        //         fontFamily: AppTypography.fontFamily,
        //       ),
        //     ),
        //   ),
        // ),
        // const SizedBox(width: AppSizes.spacing12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => ProfileMenuActions.showContactUs(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius4),
              ),
            ),
            icon: const Icon(Icons.call, color: Colors.white),
            label: const Text(
              'Contact Kitchen',
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
    );
  }

  // int _getStatusIndex(String status) {
  //   switch (status.toLowerCase()) {
  //     case 'pending':
  //       return 0;
  //     case 'confirmed':
  //       return 1;
  //     case 'prepared':
  //       return 2;
  //     case 'assigned':
  //       return 3;
  //     case 'out_for_delivery':
  //       return 4;
  //     case 'delivered':
  //       return 5;
  //     default:
  //       return 0;
  //   }
  // }

  String _formatDeliveryDate(String dateStr) {
    try {
      // Parse the UTC date
      final utcDate = DateTime.parse(dateStr).toUtc();

      // Convert UTC → IST (UTC + 5:30)
      final istDate = utcDate.add(const Duration(hours: 5, minutes: 30));

      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];

      return '${istDate.day} ${months[istDate.month - 1]} ${istDate.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDeliverySlot(DeliverySlot slot) {
    if (slot.slotStartTime.isNotEmpty && slot.slotEndTime.isNotEmpty) {
      return '${slot.slotName} (${slot.slotStartTime} - ${slot.slotEndTime})';
    }
    if (slot.slotName.isNotEmpty) return slot.slotName;
    return '';
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'wallet':
        return 'Wallet';
      case 'card':
        return 'Credit/Debit Card';
      case 'upi':
        return 'UPI';
      case 'cod':
        return 'Cash on Delivery';
      default:
        return method;
    }
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'card':
        return Icons.credit_card;
      case 'upi':
        return Icons.payment;
      case 'cod':
        return Icons.money;
      default:
        return Icons.payment;
    }
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final OrderHistory order;
  const _OrderSummaryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
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
      child: Row(
        children: [
          _DishImage(
            url: order.items.isNotEmpty ? order.items.first.dishImage : null,
            size: 70,
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Fitkhao ${order.kitchen.name}",
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize16,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order #${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    color: AppColors.textSecondary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spacing8,
                    vertical: AppSizes.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.orderStatus)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                  ),
                  child: Text(
                    _getStatusText(order.orderStatus),
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      fontWeight: AppTypography.semiBold,
                      color: _getStatusColor(order.orderStatus),
                      fontFamily: AppTypography.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
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
}

class _TimelineTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;
  final bool showConnector;
  final bool isError;

  const _TimelineTile({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isCurrent,
    required this.showConnector,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isError ? AppColors.errorColor : AppColors.primaryGreen;

    final dotColor =
        isCompleted || isCurrent ? activeColor : AppColors.borderColor;

    final innerIcon = isCompleted
        ? const Icon(Icons.check, size: 16, color: Colors.white)
        : isCurrent
            ? Icon(
                isError ? Icons.close : Icons.radio_button_checked,
                size: 16,
                color: Colors.white,
              )
            : const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isCompleted || isCurrent ? activeColor : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: 2),
              ),
              child: Center(child: innerIcon),
            ),
            if (showConnector)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? activeColor : AppColors.borderColor,
              ),
          ],
        ),
        const SizedBox(width: AppSizes.spacing12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight:
                        isCurrent ? AppTypography.bold : AppTypography.semiBold,
                    color: isError && isCurrent
                        ? AppColors.errorColor
                        : AppColors.textPrimary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize13,
                    color: AppColors.textSecondary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const SizedBox(height: AppSizes.spacing16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable cached dish image with a green icon placeholder fallback.
class _DishImage extends StatelessWidget {
  final String? url;
  final double size;

  const _DishImage({this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radius4),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        child: const Center(
          child:
              Icon(Icons.restaurant, color: AppColors.primaryGreen, size: 28),
        ),
      );
}

class _OrderTimelineStep {
  final String status;
  final String title;
  final String subtitle;

  const _OrderTimelineStep({
    required this.status,
    required this.title,
    required this.subtitle,
  });
}
