import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/order_history_model.dart';

class OrderTrackingScreen extends StatelessWidget {
  final OrderHistory order;
  const OrderTrackingScreen({super.key, required this.order});

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
                    _OrderSummaryCard(order: order),
                    const SizedBox(height: AppSizes.spacing16),
                    _buildOrderItems(),
                    const SizedBox(height: AppSizes.spacing16),
                    _buildDeliveryDetails(),
                    const SizedBox(height: AppSizes.spacing16),
                    _buildPriceSummary(),
                    const SizedBox(height: AppSizes.spacing16),
                    if (order.orderStatus != 'delivered' && order.orderStatus != 'cancelled')
                      _buildTimeline(context),
                    if (order.orderStatus != 'delivered' && order.orderStatus != 'cancelled')
                      const SizedBox(height: AppSizes.spacing20),
                    if (order.orderStatus != 'delivered' && order.orderStatus != 'cancelled')
                      _buildHelpRow(context),
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
          CircleAvatar(
            radius: AppSizes.spacing24,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
            backgroundImage: const NetworkImage(
              "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTFcyssMbcvEkMiCDu8zrO9VuN-Yy1aW1vycA&s",
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
          ...order.items.map((item) => Padding(
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
                              '${item.nutritionalInfo!.kcal} kcal • ${item.nutritionalInfo!.protein}g Protein',
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
              '${order.deliveryAddress.buildingName}, ${order.deliveryAddress.street}'),
          const SizedBox(height: AppSizes.spacing8),
          _buildDetailRow(Icons.calendar_today, 'Delivery Date',
              _formatDeliveryDate(order.deliveryDate)),
          const SizedBox(height: AppSizes.spacing8),
          _buildDetailRow(
              Icons.access_time, 'Delivery Slot', _formatDeliverySlot(order.deliverySlot)),
          const SizedBox(height: AppSizes.spacing8),
          _buildDetailRow(Icons.phone, 'Contact', order.deliveryAddress.contactNumber),
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

  Widget _buildPriceSummary() {
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
          _buildPriceRow('Subtotal', order.subtotal),
          const SizedBox(height: AppSizes.spacing8),
          _buildPriceRow('Delivery Charge', order.deliveryCharge),
          const SizedBox(height: AppSizes.spacing8),
          _buildPriceRow('Tax & Fees', order.tax),
          if (order.discount > 0) ...[
            const SizedBox(height: AppSizes.spacing8),
            _buildPriceRow('Discount', -order.discount, isDiscount: true),
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
                '₹${order.total.toStringAsFixed(2)}',
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
      ('preparing', 'Preparing Order', 'Chef is preparing your meal'),
      ('out-for-delivery', 'Out for Delivery', 'Rider is on the way'),
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
            final currentStatusIndex = _getStatusIndex(order.orderStatus);
            final stepIndex = _getStatusIndex(stepStatus);
            final isCompleted = currentStatusIndex > stepIndex;
            final isCurrent = order.orderStatus.toLowerCase() == stepStatus.toLowerCase();
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
      case 'preparing':
        return 2;
      case 'out-for-delivery':
      case 'out_for_delivery':
        return 3;
      case 'delivered':
        return 4;
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
