import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../models/order_history_model.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final OrderHistory order;
  const OrderTrackingScreen({super.key, required this.order});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  bool _isCancelling = false;

  /// Check if cancel button should be shown
  bool get _shouldShowCancelButton {
    // Only show for confirmed orders
    if (widget.order.orderStatus.toLowerCase() != 'confirmed') {
      return false;
    }

    try {
      final deliveryDate = DateTime.parse(widget.order.deliveryDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final dayAfterTomorrow = today.add(const Duration(days: 2));

      final deliveryDay = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);

      // If delivery is tomorrow, show button only today
      if (deliveryDay == tomorrow) {
        return true;
      }

      // If delivery is day after tomorrow, show button up to tomorrow
      if (deliveryDay == dayAfterTomorrow && (now.isBefore(tomorrow.add(const Duration(days: 1))))) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[OrderTrackingScreen] Error checking cancel button visibility: $e');
      return false;
    }
  }

  void _showCancelOrderModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CancelOrderModal(
        order: widget.order,
        onCancel: (reason) => _cancelOrder(reason),
      ),
    );
  }

  Future<void> _cancelOrder(String reason) async {
    if (_isCancelling) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final response = await orderRepo.cancelOrder(
        orderId: widget.order.id,
        reason: reason,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Order cancelled successfully'),
            backgroundColor: AppColors.successColor,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate back to history screen
        Navigator.of(context).pop();
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to cancel order'),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[OrderTrackingScreen] Cancel order error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to cancel order. Please try again.'),
          backgroundColor: AppColors.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.screenPaddingHorizontal,
                  vertical: AppSizes.screenPaddingVertical,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OrderSummaryCard(order: widget.order),
                    const SizedBox(height: AppSizes.spacing16),
                    _buildOrderItems(),
                    const SizedBox(height: AppSizes.spacing16),
                    _buildDeliveryDetails(),
                    const SizedBox(height: AppSizes.spacing16),
                    _buildPriceSummary(),
                    const SizedBox(height: AppSizes.spacing16),
                    if (widget.order.orderStatus != 'delivered' && widget.order.orderStatus != 'cancelled')
                      _buildTimeline(context),
                    if (widget.order.orderStatus != 'delivered' && widget.order.orderStatus != 'cancelled')
                      const SizedBox(height: AppSizes.spacing20),
                    if (widget.order.orderStatus != 'delivered' && widget.order.orderStatus != 'cancelled')
                      _buildHelpRow(context),
                    if (_shouldShowCancelButton) ...[
                      const SizedBox(height: AppSizes.spacing16),
                      _buildCancelButton(),
                    ],
                    const SizedBox(height: AppSizes.spacing20),
                  ],
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


  Widget _buildOrderItems() {
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
          ...widget.order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spacing12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                      ),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppSizes.radius4),
                          child: Image.network("https://arthurmillerfoundation.org/wp-content/uploads/2018/06/default-placeholder.png"))
                    ),
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
                          if (item.nutritionalInfo != null)
                            Text(
                              '${item.nutritionalInfo!.energyKcal.toStringAsFixed(0)} kcal • ${item.nutritionalInfo!.proteinGm.toStringAsFixed(1)}g Protein',
                              style: const TextStyle(
                                fontSize: AppTypography.fontSize12,
                                color: AppColors.textSecondary,
                                fontFamily: AppTypography.fontFamily,
                              ),
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
                        const SizedBox(height: 4),
                        Text(
                          '₹${item.subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.bold,
                            color: AppColors.primaryGreen,
                            fontFamily: AppTypography.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetails() {
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
          _buildDetailRow(Icons.location_on, 'Address',
              '${widget.order.deliveryAddress.buildingName}, ${widget.order.deliveryAddress.street}'),
          const SizedBox(height: AppSizes.spacing8),
          _buildDetailRow(Icons.calendar_today, 'Delivery Date',
              _formatDeliveryDate(widget.order.deliveryDate)),
          const SizedBox(height: AppSizes.spacing8),
          _buildDetailRow(
              Icons.access_time, 'Delivery Slot', _formatDeliverySlot(widget.order.deliverySlot)),
          const SizedBox(height: AppSizes.spacing8),
          _buildDetailRow(Icons.phone, 'Contact', widget.order.deliveryAddress.contactNumber),
          if (widget.order.deliveryAddress.deliveryInstructions != null) ...[
            const SizedBox(height: AppSizes.spacing8),
            _buildDetailRow(Icons.note, 'Delivery Instructions',
                widget.order.deliveryAddress.deliveryInstructions!),
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

  Widget _buildPriceSummary() {
    // Calculate charges
    final subtotal = widget.order.subtotal;
    final tax = subtotal * 0.05; // 5% of subtotal
    final platformCharge = 7.0;
    final deliveryCharge = 0.0;
    final discount = widget.order.discount;
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
          _buildPriceRow('GST (5%)', tax),
          const SizedBox(height: AppSizes.spacing8),
          _buildPriceRow('Platform Charge', platformCharge),
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
                  _getPaymentIcon(widget.order.paymentMethod),
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: AppSizes.spacing8),
                Text(
                  'Paid via ${_formatPaymentMethod(widget.order.paymentMethod)}',
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

  Widget _buildPriceRow(String label, double amount, {bool isDiscount = false}) {
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


  Widget _buildTimeline(BuildContext context) {
    final steps = [
      ('pending', 'Order Placed', 'We received your order'),
      ('confirmed', 'Order Confirmed', 'Kitchen confirmed your order'),
      ('prepared', 'Preparing Order', 'Chef is preparing your meal'),
      ('out_for_delivery', 'Out for Delivery', 'Rider is on the way'),
      ('delivered', 'Delivered', 'Enjoy your meal!'),
    ];

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
            final s = steps[index];
            final stepStatus = s.$1;
            final currentStatusIndex = _getStatusIndex(widget.order.orderStatus);
            final stepIndex = _getStatusIndex(stepStatus);
            print(currentStatusIndex);
            print(stepIndex);
            final isCompleted = currentStatusIndex > stepIndex;
            final isCurrent = widget.order.orderStatus.toLowerCase() == stepStatus.toLowerCase();
            final isLast = index == steps.length - 1;

            return _TimelineTile(
              title: s.$2,
              subtitle: s.$3,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              showConnector: !isLast,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHelpRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
              side: const BorderSide(color: AppColors.primaryGreen),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius4),
              ),
            ),
            icon: const Icon(Icons.support_agent, color: AppColors.primaryGreen),
            label: const Text(
              'Help & Support',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.semiBold,
                color: AppColors.primaryGreen,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spacing12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
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

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isCancelling ? null : _showCancelOrderModal,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.errorColor,
          disabledBackgroundColor: AppColors.errorColor.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius4),
          ),
        ),
        icon: _isCancelling
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.cancel, color: Colors.white),
        label: Text(
          _isCancelling ? 'Cancelling...' : 'Cancel Order',
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: AppTypography.semiBold,
            color: Colors.white,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
      ),
    );
  }

  String _getEtaText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'ETA ~ 40-45 mins';
      case 'confirmed':
        return 'ETA ~ 35-40 mins';
      case 'preparing':
        return 'ETA ~ 20-25 mins';
      case 'out-for-delivery':
      case 'out_for_delivery':
        return 'Arriving in ~ 10 mins';
      default:
        return 'Processing...';
    }
  }

  int _getStatusIndex(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'confirmed':
        return 1;
      case 'prepared':
        return 2;
      case 'assigned':
        return 3;
      case 'out_for_delivery':
        return 4;
      case 'delivered':
        return 5;
      default:
        return 0;
    }
  }

  String _formatDeliveryDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
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
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDeliverySlot(String slot) {
    switch (slot.toLowerCase()) {
      case 'morning':
        return 'Morning (8-9 AM)';
      case 'afternoon':
        return 'Afternoon (12-1 PM)';
      case 'evening':
        return 'Evening (8-9 PM)';
      default:
        return slot;
    }
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
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radius4),
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radius4),
                child: Image.network("https://arthurmillerfoundation.org/wp-content/uploads/2018/06/default-placeholder.png")),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.kitchen.name,
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
                    color: _getStatusColor(order.orderStatus).withValues(alpha: 0.1),
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
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
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
        return AppColors.primaryGreen;
      case 'out_for_delivery':
      case 'out-for-delivery':
        return Colors.blue;
      case 'delivered':
        return AppColors.successColor;
      case 'cancelled':
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

  const _TimelineTile({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isCurrent,
    required this.showConnector,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isCompleted || isCurrent ? AppColors.primaryGreen : AppColors.borderColor;
    final innerIcon = isCompleted
        ? const Icon(Icons.check, size: 16, color: Colors.white)
        : isCurrent
            ? const Icon(Icons.radio_button_checked, size: 16, color: Colors.white)
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
                color: (isCompleted || isCurrent) ? AppColors.primaryGreen : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: 2),
              ),
              child: Center(child: innerIcon),
            ),
            if (showConnector)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? AppColors.primaryGreen : AppColors.borderColor,
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
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: isCurrent ? AppTypography.bold : AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
        )
      ],
    );
  }
}

class _CancelOrderModal extends StatefulWidget {
  final OrderHistory order;
  final Function(String reason) onCancel;

  const _CancelOrderModal({
    required this.order,
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Close the modal and trigger cancellation
    Navigator.of(context).pop();
    widget.onCancel(_reasonController.text.trim());
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
                // Header
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
                          fontFamily: 'Lato',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing16),

                // Order info
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
                          'Order #${widget.order.orderNumber}',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spacing20),

                // Warning message
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                      width: 1,
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
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spacing20),

                // Cancellation reason
                const Text(
                  'Reason for Cancellation',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 4,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    hintText: 'Please tell us why you want to cancel this order (minimum 10 characters)',
                    hintStyle: const TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: AppColors.textTertiary,
                      fontFamily: 'Lato',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: AppColors.errorColor),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: AppColors.errorColor, width: 2),
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

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                          side: const BorderSide(color: AppColors.borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radius4),
                          ),
                        ),
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
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
                          disabledBackgroundColor: AppColors.errorColor.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radius4),
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
        ),
      ),
    );
  }
}
