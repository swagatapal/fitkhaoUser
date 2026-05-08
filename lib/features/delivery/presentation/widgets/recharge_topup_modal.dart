import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/services/razorpay_service.dart';
import '../../providers/wallet_provider.dart';

class RechargeTopupModal extends ConsumerStatefulWidget {
  const RechargeTopupModal({super.key});

  @override
  ConsumerState<RechargeTopupModal> createState() => _RechargeTopupModalState();
}

class _RechargeTopupModalState extends ConsumerState<RechargeTopupModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  bool _isProcessing = false;

  late final RazorpayService _razorpayService;

  // Stored after create-order so the success callback can reference them.
  String? _razorpayOrderId;
  int _amountInRupees = 0;

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
    _amountController.dispose();
    _razorpayService.dispose();
    super.dispose();
  }

  // ── Razorpay callbacks ────────────────────────────────────────────────────

  void _onRazorpaySuccess(
    String paymentId,
    String? sdkOrderId,
    String? signature,
  ) {
    debugPrint('[RechargeTopupModal] Razorpay success — paymentId=$paymentId');
    _verifyAndFinalise(
      paymentId: paymentId,
      sdkOrderId: sdkOrderId,
      signature: signature,
    );
  }

  void _onRazorpayFailure(int code, String message) {
    debugPrint('[RechargeTopupModal] Razorpay failure — $code $message');
    _razorpayOrderId = null;
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showError(message);
  }

  // ── Pay Now flow ──────────────────────────────────────────────────────────

  Future<void> _initiatePayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountController.text.trim());

    setState(() => _isProcessing = true);

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final createResponse = await orderRepo.createRazorpayWalletTopup(
        amountInRupees: amount,
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
      _amountInRupees = amount;

      // amountInPaise from backend is authoritative; fall back to user input.
      final amountInPaise =
          orderData.amountInPaise > 0 ? orderData.amountInPaise : amount * 100;

      debugPrint(
        '[RechargeTopupModal] Razorpay order created — '
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
          description: 'FitKhao Wallet Top-up ₹$amount',
          customerName: userName,
          customerEmail: userEmail,
          customerContact: userPhone,
        ),
      );
    } catch (e) {
      debugPrint('[RechargeTopupModal] createRazorpayWalletTopup error: $e');
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
      debugPrint('[RechargeTopupModal] verifyPayment: razorpayOrderId empty');
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
        purpose: 'wallet_topup',
        amount: _amountInRupees,
      );

      _razorpayOrderId = null;
      if (!mounted) return;

      if (verifyResponse.success) {
        await ref.read(walletProvider.notifier).loadWalletBalance();
        if (!mounted) return;
        setState(() => _isProcessing = false);
        Navigator.of(context).pop();
        _showSuccessDialog();
      } else {
        setState(() => _isProcessing = false);
        _showError(verifyResponse.message.isNotEmpty
            ? verifyResponse.message
            : 'Payment verification failed. Please contact support.');
      }
    } catch (e) {
      debugPrint('[RechargeTopupModal] verifyRazorpayPayment error: $e');
      _razorpayOrderId = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Payment verification failed. Please try again.');
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.primaryGreen,
                size: AppSizes.icon60,
              ),
            ),
            const SizedBox(height: AppSizes.spacing20),
            const Text(
              'Top-up Successful!',
              style: TextStyle(
                fontSize: AppTypography.fontSize20,
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              '₹$_amountInRupees has been added to your wallet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.regular,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.bold,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ),
        ],
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
          'Top-up Failed',
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

  // ── Build ─────────────────────────────────────────────────────────────────

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
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radius8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.primaryGreen,
                        size: AppSizes.icon24,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    const Expanded(
                      child: Text(
                        'Recharge Wallet',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize20,
                          fontWeight: AppTypography.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _isProcessing ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing24),

                // Amount field
                const Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !_isProcessing,
                  decoration: InputDecoration(
                    hintText: 'Enter amount (min ₹1000)',
                    prefixIcon: const Icon(Icons.currency_rupee),
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
                      borderSide:
                          const BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing16,
                      vertical: AppSizes.spacing12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    final parsed = int.tryParse(value);
                    if (parsed == null) return 'Please enter a valid amount';
                    if (parsed < 1000) return 'Minimum amount is ₹1000';
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.spacing24),

                // Pay Now button
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _initiatePayment,
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
                        : const Text(
                            'Pay Now',
                            style: TextStyle(
                              fontSize: AppTypography.fontSize16,
                              fontWeight: AppTypography.bold,
                              fontFamily: 'Lato',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
