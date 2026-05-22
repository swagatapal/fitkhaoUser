import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/services/razorpay_service.dart';
import '../../../../shared/widgets/logo_widget.dart';
import '../../../policy/models/app_constants_model.dart';
import '../../../policy/providers/app_constants_provider.dart';

class SubscriptionCheckoutScreen extends ConsumerStatefulWidget {
  final String planDays;
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
  bool _isProcessing = false;

  late final RazorpayService _razorpayService;

  String? _razorpayOrderId;

  double get _planPrice {
    final raw =
        widget.planPrice.replaceAll('₹', '').replaceAll(',', '').trim();
    return double.tryParse(raw) ?? 0.0;
  }

  // ─── Pricing helpers ───────────────────────────────────────────────────────

  /// Resolved at build time from the provider; stored here to be accessible
  /// in non-build methods (dialogs, button text).
  PricingConstants _pricing = PricingConstants.defaults;

  double get _platformFee => _pricing.platformFee;

  double get _gstAmount =>
      (_planPrice + _platformFee) * _pricing.gstRate / 100;

  double get _deliveryCharge => _pricing.deliveryCharge;

  double get _totalAmount =>
      _planPrice + _platformFee + _gstAmount + _deliveryCharge;

  String get _formattedTotal => '₹${_totalAmount.toStringAsFixed(0)}';

  // ── Razorpay lifecycle ─────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService(
      onSuccess: _onRazorpaySuccess,
      onFailure: _onRazorpayFailure,
      onExternalWallet: (_) {},
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  // ── Razorpay callbacks ─────────────────────────────────────────────────────

  void _onRazorpaySuccess(
    String paymentId,
    String? sdkOrderId,
    String? signature,
  ) {
    debugPrint(
        '[SubscriptionCheckout] Razorpay success — paymentId=$paymentId');
    _verifyAndFinalise(
      paymentId: paymentId,
      sdkOrderId: sdkOrderId,
      signature: signature,
    );
  }

  void _onRazorpayFailure(int code, String message) {
    debugPrint('[SubscriptionCheckout] Razorpay failure — $code $message');
    _razorpayOrderId = null;
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showError(message);
  }

  // ── Payment flow ───────────────────────────────────────────────────────────

  void _onPayTapped() {
    if (_isProcessing) return;
    _showConfirmationDialog();
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                'Proceed with payment of $_formattedTotal for the '
                '${widget.planDays}-day subscription plan?',
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
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radius4),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.spacing8),
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
                        Navigator.of(ctx).pop();
                        _initiateRazorpayFlow();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radius4),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.spacing8),
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

  Future<void> _initiateRazorpayFlow() async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final createResponse = await orderRepo.createRazorpaySubscriptionOrder(
        planCode: widget.planCode,
      );

      if (!createResponse.success || createResponse.data == null) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showError(createResponse.message.isNotEmpty
            ? createResponse.message
            : 'Could not initiate payment. Please try again.');
        return;
      }

      final orderData = createResponse.data!;
      _razorpayOrderId = orderData.razorpayOrderId;

      // Backend is authoritative for the amount; fall back to local total
      // only if the backend value is zero.
      final amountInPaise = orderData.amountInPaise > 0
          ? orderData.amountInPaise
          : (_totalAmount * 100).toInt();

      debugPrint(
        '[SubscriptionCheckout] Razorpay order created — '
        'orderId=${orderData.razorpayOrderId} paise=$amountInPaise',
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final localStorage = ref.read(localStorageProvider).value;
      final userName = localStorage?.getUserName() ?? 'FitKhao User';
      final userEmail = localStorage?.getUserEmail() ?? '';
      final userPhone = localStorage?.getUserPhone() ?? '';

      _razorpayService.open(
        RazorpayPaymentConfig(
          amountInPaise: amountInPaise,
          orderId: orderData.razorpayOrderId,
          description: 'FitKhao ${widget.planDays}-Day Subscription',
          customerName: userName,
          customerEmail: userEmail,
          customerContact: userPhone,
        ),
      );
    } catch (e) {
      debugPrint(
          '[SubscriptionCheckout] createRazorpaySubscriptionOrder error: $e');
      _razorpayOrderId = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Payment initiation failed. Please try again.');
    }
  }

  Future<void> _verifyAndFinalise({
    required String paymentId,
    required String? sdkOrderId,
    required String? signature,
  }) async {
    final razorpayOrderId = (_razorpayOrderId?.isNotEmpty == true)
        ? _razorpayOrderId!
        : (sdkOrderId ?? '');

    if (razorpayOrderId.isEmpty) {
      debugPrint(
          '[SubscriptionCheckout] verifyPayment: razorpayOrderId empty');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Payment verification failed. Please contact support.');
      return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final verifyResponse = await orderRepo.verifyRazorpayPayment(
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature ?? '',
        purpose: 'subscription',
        planCode: widget.planCode,
      );

      _razorpayOrderId = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (verifyResponse.success) {
        _showSuccessDialog();
      } else {
        _showError(verifyResponse.message.isNotEmpty
            ? verifyResponse.message
            : 'Payment verification failed. Please contact support.');
      }
    } catch (e) {
      debugPrint('[SubscriptionCheckout] verifyRazorpayPayment error: $e');
      _razorpayOrderId = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Payment verification failed. Please try again.');
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  onPressed: () =>
                      Navigator.of(ctx).popUntil((route) => route.isFirst),
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

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        title: const Text(
          'Payment Failed',
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: AppTypography.regular,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.medium,
                color: AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Resolve pricing from the cached provider — uses defaults while loading
    // or if the API failed, so the UI is always in a valid state.
    _pricing = ref
            .watch(appConstantsProvider)
            .valueOrNull
            ?.pricing ??
        PricingConstants.defaults;

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
                      LogoWidget(),
                      const SizedBox(height: AppSizes.spacing24),
                      _buildPaymentSummary(),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your purchase',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                Text(
                  'Review your plan and pay',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textSecondary,
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
            border: Border.all(color: AppColors.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Plan price
              _buildSummaryRow(
                '${widget.planDays} Days Plan',
                _formatAmount(_planPrice),
              ),

              // Platform fee — shown only when non-zero
              if (_platformFee > 0) ...[
                const SizedBox(height: AppSizes.spacing12),
                _buildSummaryRow(
                  'Platform Fee',
                  _formatAmount(_platformFee),
                ),
              ],

              // GST — shown only when non-zero
              if (_gstAmount > 0) ...[
                const SizedBox(height: AppSizes.spacing12),
                _buildSummaryRow(
                  'GST (${_pricing.gstRate.toStringAsFixed(0)}%)',
                  _formatAmount(_gstAmount),
                ),
              ],

              // Delivery charge — shown only when non-zero
              if (_deliveryCharge > 0) ...[
                const SizedBox(height: AppSizes.spacing12),
                _buildSummaryRow(
                  'Delivery Charge',
                  _formatAmount(_deliveryCharge),
                ),
              ],

              const SizedBox(height: AppSizes.spacing12),
              const Divider(height: 1, color: AppColors.borderColor),
              const SizedBox(height: AppSizes.spacing12),

              // Total
              _buildSummaryRow(
                'Total',
                _formatAmount(_totalAmount),
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
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: isBold ? AppTypography.bold : AppTypography.regular,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold
                ? AppTypography.fontSize16
                : AppTypography.fontSize14,
            fontWeight: isBold ? AppTypography.bold : AppTypography.regular,
            color: isBold ? AppColors.primaryGreen : AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
      ],
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
          onPressed: _isProcessing ? null : _onPayTapped,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppColors.primaryGreen.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius4),
            ),
            elevation: 2,
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Pay $_formattedTotal',
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

  static String _formatAmount(double amount) =>
      '₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
}
