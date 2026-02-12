import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/order.dart';

class DeliveredOrderDetailsScreen extends StatelessWidget {
  final OrderModel order;
  const DeliveredOrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Order Details',
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.semiBold,
            color: AppColors.textPrimary,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: Column(
          children: [
            _buildSummary(context),
            const SizedBox(height: AppSizes.spacing16),
            _buildItems(context),
            const SizedBox(height: AppSizes.spacing16),
            _buildPriceBreakdown(context),
            const SizedBox(height: AppSizes.spacing16),
            _buildAddress(context),
            const SizedBox(height: AppSizes.spacing24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius12),
                  ),
                ),
                child: const Text(
                  'Reorder',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize16,
                    fontWeight: AppTypography.semiBold,
                    color: Colors.white,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.p10,
                  vertical: AppSizes.p6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                child: const Text(
                  'Delivered',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.successColor,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Order #${order.id}',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textPrimary,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          Text(
            order.restaurantName,
            style: const TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.bold,
              color: AppColors.textPrimary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Delivered on ${_formatDateTime(order.deliveredTime ?? order.orderTime)}',
            style: const TextStyle(
              fontSize: AppTypography.fontSize13,
              color: AppColors.textSecondary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItems(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items',
            style: TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          ...order.items.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${i.quantity} × ${i.name}',
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize14,
                          color: AppColors.textPrimary,
                          fontFamily: AppTypography.fontFamily,
                        ),
                      ),
                    ),
                    Text(
                      '₹${(i.price * i.quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: AppTypography.fontFamily,
                      ),
                    )
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          _kv('Subtotal', '₹${order.subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: AppSizes.spacing8),
          _kv('Delivery Fee', '₹${order.deliveryFee.toStringAsFixed(2)}'),
          const SizedBox(height: AppSizes.spacing8),
          _kv('Tax', '₹${order.tax.toStringAsFixed(2)}'),
          const Divider(height: AppSizes.spacing24),
          _kv('Total', '₹${order.total.toStringAsFixed(2)}', isBold: true),
        ],
      ),
    );
  }

  Widget _buildAddress(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on, color: AppColors.primaryGreen),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.address,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize13,
                    color: AppColors.textSecondary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime dateTime) {
    final d = dateTime;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day}/${d.month}/${d.year} • $h:$m $ampm';
  }

  Widget _kv(String k, String v, {bool isBold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textSecondary,
              fontWeight: isBold ? AppTypography.semiBold : AppTypography.regular,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            color: AppColors.textPrimary,
            fontWeight: isBold ? AppTypography.bold : AppTypography.semiBold,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
      ],
    );
  }
}

