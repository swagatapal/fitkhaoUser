import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../../shared/widgets/logo_widget.dart';
import '../../../main_navigation/main_navigation_screen.dart';
import '../../providers/meal_category_provider.dart';
import '../../providers/meal_plan_nutrition_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/serviceability_provider.dart';
import '../../providers/wallet_provider.dart';

class SubscriptionCheckoutScreen extends ConsumerStatefulWidget {
  final String planDays; // '7' or '30'
  final String planPrice;

  const SubscriptionCheckoutScreen({
    super.key,
    required this.planDays,
    required this.planPrice,
  });

  @override
  ConsumerState<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends ConsumerState<SubscriptionCheckoutScreen> {
  final TextEditingController _couponController = TextEditingController();
  String _selectedPaymentMethod =
      'UPI'; // 'UPI', 'Net Banking', 'Debit/Credit Card'
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

  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  void _navigateToRefreshedDeliveryScreen() {
    ref.read(mainNavIndexProvider.notifier).state = 0;

    final deliveryReloadNotifier =
        ref.read(deliveryScreenReloadProvider.notifier);
    deliveryReloadNotifier.state = deliveryReloadNotifier.state + 1;

    ref.invalidate(walletProvider);
    ref.invalidate(serviceabilityProvider);
    ref.invalidate(nutritionProgressProvider);
    ref.invalidate(mealPlanAvailableProvider);
    ref.invalidate(mealPlanNutritionProvider);
    ref.invalidate(mealCategoryListProvider);

    Navigator.of(context, rootNavigator: true).popUntil(
      (route) => route.isFirst,
    );
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
                      onPressed: () async {
                        final navigator = Navigator.of(context);

                        try {
                          await analytics.logEvent(
                            name: 'confirm_payment_click',
                            parameters: {
                              'screen': 'payment_dialog',
                              'button_name': 'confirm',
                            },
                          );
                        } catch (e) {
                          debugPrint('Analytics error: $e');
                        }

                        if (!mounted) return;
                        navigator.pop();
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

      // Determine plan type based on days
      final planType = widget.planDays == '7' ? 'weekly' : 'monthly';

      // Convert amount to integer
      final amount = _grandTotal.toInt();

      debugPrint('[SubscriptionCheckout] Creating subscription...');
      debugPrint('[SubscriptionCheckout] Plan Type: $planType');
      debugPrint('[SubscriptionCheckout] Amount: $amount');

      // Call API to create subscription
      final response = await subscriptionRepo.createSubscription(
        planType: planType,
        amount: amount,
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
                    _navigateToRefreshedDeliveryScreen();
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
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.borderColor,
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
          //onPressed: _processPayment,
          onPressed: (){
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (context) => const PayUStaticHashTestPage()),
            );

          },
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



class PayUStaticHashTestPage extends StatefulWidget {
  const PayUStaticHashTestPage({super.key});

  @override
  State<PayUStaticHashTestPage> createState() => _PayUStaticHashTestPageState();
}

class _PayUStaticHashTestPageState extends State<PayUStaticHashTestPage>
    implements PayUCheckoutProProtocol {
  late PayUCheckoutProFlutter _checkoutPro;

  // Your credentials
  static const String merchantKey = 'x4JE8Z';


  @override
  void initState() {
    super.initState();
    _checkoutPro = PayUCheckoutProFlutter(this);
  }

  // void _startPayment() {
  //   final additionalParam = {
  //     'payment_related_details_for_mobile_sdk': "C79yyUhbHnoH98ge9jLZZHfIMS8d1xdK",
  //     'vas_for_mobile_sdk': "C79yyUhbHnoH98ge9jLZZHfIMS8d1xdK",
  //     'payment': "C79yyUhbHnoH98ge9jLZZHfIMS8d1xdK",
  //     PayUAdditionalParamKeys.udf1: '',
  //     PayUAdditionalParamKeys.udf2: '',
  //     PayUAdditionalParamKeys.udf3: '',
  //     PayUAdditionalParamKeys.udf4: '',
  //     PayUAdditionalParamKeys.udf5: '',
  //   };
  //
  //   final payUPaymentParams = {
  //     PayUPaymentParamKey.key: merchantKey,
  //     PayUPaymentParamKey.amount: amount,
  //     PayUPaymentParamKey.productInfo: productInfo,
  //     PayUPaymentParamKey.firstName: firstName,
  //     PayUPaymentParamKey.email: email,
  //     PayUPaymentParamKey.phone: phone,
  //
  //     // Test URLs from PayU docs
  //     PayUPaymentParamKey.ios_surl: 'https://cbjs.payu.in/sdk/success',
  //     PayUPaymentParamKey.ios_furl: 'https://cbjs.payu.in/sdk/failure',
  //     PayUPaymentParamKey.android_surl: 'https://cbjs.payu.in/sdk/success',
  //     PayUPaymentParamKey.android_furl: 'https://cbjs.payu.in/sdk/failure',
  //
  //     // 1 = test, 0 = production
  //     PayUPaymentParamKey.environment: '1',
  //
  //     PayUPaymentParamKey.userCredential: userCredential,
  //     PayUPaymentParamKey.transactionId: txnId,
  //     PayUPaymentParamKey.additionalParam: additionalParam,
  //   };
  //
  //   final payUCheckoutProConfig = {
  //     PayUCheckoutProConfigKeys.merchantName: 'FitKhao',
  //     PayUCheckoutProConfigKeys.showExitConfirmationOnCheckoutScreen: true,
  //     PayUCheckoutProConfigKeys.showExitConfirmationOnPaymentScreen: true,
  //     PayUCheckoutProConfigKeys.autoSelectOtp: true,
  //   };
  //
  //   _checkoutPro.openCheckoutScreen(
  //     payUPaymentParams: payUPaymentParams,
  //     payUCheckoutProConfig: payUCheckoutProConfig,
  //   );
  // }


  final String payuMerchantKey = 'x4JE8Z';
  final String payuSalt = 'C79yyUhbHnoH98ge9jLZZHfIMS8d1xdK';
  final String payuBaseUrl = 'https://test.payu.in/_payment';

  // Generate PayU hash using SHA-512
  String generatePayUHash(String key, String command, String var1) {
    final input = '$key|$command|$var1|$payuSalt';
    final bytes = utf8.encode(input);
    final digest = sha512.convert(bytes);
    return digest.toString();
  }


  // Pay Now method
  Future<bool> payNow() async {
    // Payment details
    const String transactionId = 'txnid132735124320';
    const String amount = '10.00';
    const String firstName = 'Ashish';
    const String email = 'test@gmail.com';
    const String phone = '9876543210';
    const String productInfo = 'iPhone';
    const String pg = 'TESTPG';
    const String bankCode = 'TESTPGNB';
    const String surl =
        'https://test-payment-middleware.payu.in/simulatorResponse';
    const String furl =
        'https://test-payment-middleware.payu.in/simulatorResponse';

    // Use the command 'payment' for the payment process
    const String command = 'payment';

    // Generate the hash using the provided method
    final String hash = generatePayUHash(
      payuMerchantKey,
      command,
      transactionId, // Using transaction ID as var1
    );

    // Making the payment request
    final response = await http.post(
      Uri.parse('https://test.payu.in/_payment'),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'key': payuMerchantKey,
        'txnid': transactionId,
        'amount': amount,
        'firstname': firstName,
        'email': email,
        'phone': phone,
        'productinfo': productInfo,
        'pg': pg,
        'bankcode': bankCode,
        'surl': surl,
        'furl': furl,
        'hash': hash,
      },
    );

    // Handle the response
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  @override
  void generateHash(Map response) {
    debugPrint('Unexpected dynamic hash request: $response');
    // This static-hash demo is intended to avoid backend hashing for a quick test.
    // If PayU asks for more hashes for your flow, move to server-side dynamic hashing.
  }

  @override
  void onPaymentSuccess(dynamic response) {
    debugPrint('PAYMENT SUCCESS => $response');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment Success')),
    );
  }

  @override
  void onPaymentFailure(dynamic response) {
    debugPrint('PAYMENT FAILURE => $response');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment Failure')),
    );
  }

  @override
  void onPaymentCancel(Map? response) {
    debugPrint('PAYMENT CANCELLED => $response');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment Cancelled')),
    );
  }

  @override
  void onError(Map? response) {
    debugPrint('PAYMENT ERROR => $response');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Error: $response')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PayU Static Hash Test')),
      body: Center(
        child: ElevatedButton(
          onPressed: payNow,
          child: const Text('Pay 10'),
        ),
      ),
    );
  }
}
