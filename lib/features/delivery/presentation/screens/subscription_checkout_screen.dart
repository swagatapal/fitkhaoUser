import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../../shared/widgets/logo_widget.dart';

class SubscriptionCheckoutScreen extends ConsumerStatefulWidget {
  final String planDays; // '7' or '30'
  final String planPrice;
  final String planCode;

  const SubscriptionCheckoutScreen({
    super.key,
    required this.planDays,
    required this.planPrice,
    required this.planCode,
  });

  @override
  ConsumerState<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends ConsumerState<SubscriptionCheckoutScreen> {
  final TextEditingController _couponController = TextEditingController();
  String _selectedPaymentMethod = 'UPI'; // 'UPI', 'Net Banking', 'Debit/Credit Card'
  double _discount = 0.0;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  double get _planPrice {
    // Remove ₹ symbol and parse
    final priceStr = widget.planPrice.replaceAll('₹', '').replaceAll(',', '');
    return double.tryParse(priceStr) ?? 0.0;
  }

  double get _gstAmount {
    // Calculate 1% GST approximately for display
    return _planPrice * 0.01;
  }

  double get _grandTotal {
    return _planPrice - _discount;
  }

  void _applyCoupon() {
    final couponCode = _couponController.text.trim().toUpperCase();

    if (couponCode.isEmpty) {
      _showMessage('Please enter a coupon code');
      return;
    }

    // Mock coupon validation
    if (couponCode == 'FITKHAO50') {
      setState(() {
        _discount = _planPrice * 0.5; // 50% discount
      });
      _showMessage('Coupon applied! 50% discount');
    } else if (couponCode == 'WELCOME10') {
      setState(() {
        _discount = _planPrice * 0.1; // 10% discount
      });
      _showMessage('Coupon applied! 10% discount');
    } else {
      _showMessage('Invalid coupon code');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Lato'),
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _processPayment() {
    if (_selectedPaymentMethod.isEmpty) {
      _showMessage('Please select a payment method');
      return;
    }

    // Show confirmation dialog first
    _showConfirmationDialog();
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Question Icon
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_outline,
                  size: AppSizes.icon60,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: AppSizes.spacing20),
              const Text(
                'Confirm Payment',
                style: TextStyle(
                  fontSize: AppTypography.fontSize20,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spacing12),
              Text(
                'Are you sure you want to proceed with payment of ₹${_grandTotal.toStringAsFixed(0)} via $_selectedPaymentMethod?',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.regular,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spacing24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.borderColor,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radius4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.spacing8,
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize16,
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
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmPayment();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radius4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.spacing8,
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize16,
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
    );
  }

  Future<void> _confirmPayment() async {
    _showMessage('Processing payment via $_selectedPaymentMethod...');

    try {
      // Get subscription repository
      final subscriptionRepo = ref.read(subscriptionRepositoryProvider);

      debugPrint('[SubscriptionCheckout] Creating subscription...');
      debugPrint('[SubscriptionCheckout] planCode: ${widget.planCode}');

      // Call API to create subscription
      final response = await subscriptionRepo.createSubscription(
        planCode: widget.planCode,
      );

      debugPrint('[SubscriptionCheckout] Response: ${response.success}');
      debugPrint('[SubscriptionCheckout] Message: ${response.message}');

      if (mounted) {
        if (response.success) {
          _showSuccessDialog();
        } else {
          _showMessage(response.message.isNotEmpty
            ? response.message
            : 'Subscription creation failed. Please try again.');
        }
      }
    } catch (e) {
      debugPrint('[SubscriptionCheckout] Error: $e');
      if (mounted) {
        _showMessage('Failed to create subscription. Please try again.');
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: AppSizes.icon80,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: AppSizes.spacing24),
              const Text(
                'Subscription Successful!',
                style: TextStyle(
                  fontSize: AppTypography.fontSize20,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spacing12),
              const Text(
                'Welcome to FitKhao Plus! Enjoy your premium benefits.',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.regular,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spacing24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize16,
                      fontWeight: AppTypography.semiBold,
                      color: Colors.white,
                      fontFamily: 'Lato',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPaddingHorizontal,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSizes.spacing16),
                      _buildFitKhaoLogo(),
                      const SizedBox(height: AppSizes.spacing24),
                      _buildPaymentSummary(),
                      const SizedBox(height: AppSizes.spacing16),
                      _buildApplyCoupon(),
                      const SizedBox(height: AppSizes.spacing16),
                      _buildPaymentMethod(),
                      const SizedBox(height: AppSizes.spacing24),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomButton(),
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
                  "Complete your purchase",
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                //const SizedBox(height: AppSizes.spacing2),
                Text(
                  "Make payment to recharge wallet",
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

  Widget _buildFitKhaoLogo() {
    return LogoWidget();
  }
  Widget _buildPaymentSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Summary',
          style: TextStyle(
            fontSize: AppTypography.fontSize20,
            fontWeight: AppTypography.semiBold,
            color: AppColors.primaryGreen,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing16),
        Container(
          padding: const EdgeInsets.all(AppSizes.spacing16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            border: Border.all(
              color: AppColors.borderColor,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                '${widget.planDays} Days Plan',
                widget.planPrice,
                isBold: false,
              ),
              const SizedBox(height: AppSizes.spacing8),
              _buildSummaryRow(
                'GST',
                '₹${_gstAmount.toStringAsFixed(2)}',
                isBold: false,
              ),
              if (_discount > 0) ...[
                const SizedBox(height: AppSizes.spacing8),
                _buildSummaryRow(
                  'Discount',
                  '-₹${_discount.toStringAsFixed(0)}',
                  isBold: false,
                  isDiscount: true,
                ),
              ],
              const SizedBox(height: AppSizes.spacing12),
              const Divider(height: 1, color: AppColors.borderColor),
              const SizedBox(height: AppSizes.spacing12),
              _buildSummaryRow(
                'Grand Total',
                '₹${_grandTotal.toStringAsFixed(0)}',
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    required bool isBold,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.fontSize16,
            fontWeight: isBold ? AppTypography.bold : AppTypography.regular,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTypography.fontSize16,
            fontWeight: isBold ? AppTypography.bold : AppTypography.regular,
            color: isDiscount ? AppColors.primaryGreen : AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }

  Widget _buildApplyCoupon() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Apply Coupon',
          style: TextStyle(
            fontSize: AppTypography.fontSize20,
            fontWeight: AppTypography.semiBold,
            color: AppColors.primaryGreen,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16,
            vertical: AppSizes.spacing4,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius4),
            border: Border.all(
              color: AppColors.borderColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  decoration: InputDecoration(
                    hintText: 'Enter Code',
                    hintStyle: const TextStyle(
                      fontSize: AppTypography.fontSize16,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSizes.spacing12,
                    ),
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize16,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
              TextButton(
                onPressed: _applyCoupon,
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize16,
                    fontWeight: AppTypography.bold,
                    color: AppColors.primaryGreen,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: AppTypography.fontSize20,
            fontWeight: AppTypography.semiBold,
            color: AppColors.primaryGreen,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing16),
        _buildPaymentOption('UPI'),
        const SizedBox(height: AppSizes.spacing12),
        _buildPaymentOption('Net Banking'),
        const SizedBox(height: AppSizes.spacing12),
        _buildPaymentOption('Debit/Credit Card'),
      ],
    );
  }

  Widget _buildPaymentOption(String method) {
    final isSelected = _selectedPaymentMethod == method;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius4),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected ? AppColors.primaryGreen : AppColors.borderColor,
                  width: 2,
                ),
                color: Colors.white,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSizes.spacing16),
            Text(
              method,
              style: TextStyle(
                fontSize: AppTypography.fontSize16,
                fontWeight:
                    isSelected ? AppTypography.semiBold : AppTypography.regular,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.buttonHeight,
        child: ElevatedButton(
          onPressed: _processPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius4),
            ),
            elevation: 2,
          ),
          child: Text(
            'Pay ${_grandTotal.toStringAsFixed(0)}/-',
            style: const TextStyle(
              fontSize: AppTypography.fontSize18,
              fontWeight: AppTypography.bold,
              fontFamily: 'Lato',
            ),
          ),
        ),
      ),
    );
  }
}
