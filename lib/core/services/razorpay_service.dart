import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Configuration for a Razorpay payment.
class RazorpayPaymentConfig {
  /// Amount in paise (₹1 = 100 paise).
  final int amountInPaise;

  /// Razorpay order ID from your backend. Leave empty for test mode.
  final String orderId;

  final String description;
  final String customerName;
  final String customerEmail;
  final String customerContact;

  const RazorpayPaymentConfig({
    required this.amountInPaise,
    required this.orderId,
    required this.description,
    required this.customerName,
    required this.customerEmail,
    required this.customerContact,
  });
}

/// A reusable wrapper around [Razorpay] that uses direct callbacks.
///
/// **Usage — call [init] in `initState`, [dispose] in `dispose`:**
/// ```dart
/// late final RazorpayService _razorpay;
///
/// @override
/// void initState() {
///   super.initState();
///   _razorpay = RazorpayService(
///     onSuccess: (id, orderId, signature) { ... },
///     onFailure: (code, message) { ... },
///     onExternalWallet: (walletName) { ... },
///   );
/// }
///
/// @override
/// void dispose() {
///   _razorpay.dispose();
///   super.dispose();
/// }
///
/// // To open checkout:
/// _razorpay.open(config);
/// ```
class RazorpayService {
  // ── Test key — swap for live key before production release ───────────────
  //dev
 // static const String _KeyId = 'rzp_test_SsWU9Njz5MJdGK';
  //live
  static const String _KeyId = 'rzp_live_So8WdDY0fRhLfF';

  static String get _keyId => _KeyId;
  // ─────────────────────────────────────────────────────────────────────────

  final void Function(String paymentId, String? orderId, String? signature)
      onSuccess;
  final void Function(int code, String message) onFailure;
  final void Function(String walletName) onExternalWallet;

  late final Razorpay _razorpay;

  RazorpayService({
    required this.onSuccess,
    required this.onFailure,
    required this.onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    debugPrint('[RazorpayService] Initialised');
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    debugPrint('[RazorpayService] SUCCESS — paymentId=${response.paymentId}');
    debugPrint('[RazorpayService] SUCCESS — orderId=${response.orderId}');
    debugPrint('[RazorpayService] SUCCESS — signature=${response.signature}');
    onSuccess(
      response.paymentId ?? '',
      response.orderId,
      response.signature,
    );
  }

  void _handleFailure(PaymentFailureResponse response) {
    debugPrint(
        '[RazorpayService] FAILURE — code=${response.code} msg=${response.message}');
    onFailure(response.code ?? -1, _buildErrorMessage(response));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint(
        '[RazorpayService] EXTERNAL_WALLET — wallet=${response.walletName}');
    onExternalWallet(response.walletName ?? 'unknown');
  }

  String _buildErrorMessage(PaymentFailureResponse r) {
    switch (r.code) {
      case Razorpay.PAYMENT_CANCELLED:
        return 'Payment cancelled. Please try again.';
      case Razorpay.NETWORK_ERROR:
        return 'Network error. Please check your connection and try again.';
      case Razorpay.INVALID_OPTIONS:
        return 'Invalid payment configuration. Please contact support.';
      case Razorpay.TLS_ERROR:
        return 'Secure connection failed. Please update your device and try again.';
      case Razorpay.INCOMPATIBLE_PLUGIN:
        return 'App update required. Please update the app and try again.';
      default:
        final msg = r.message;
        return (msg != null && msg.isNotEmpty)
            ? msg
            : 'Payment failed. Please try again.';
    }
  }

  /// Opens the Razorpay checkout sheet.
  void open(RazorpayPaymentConfig config) {
    final options = <String, dynamic>{
      'key': _keyId,
      'amount': config.amountInPaise,
      if (config.orderId.isNotEmpty) 'order_id': config.orderId,
      'name': 'FitKhao',
      'description': config.description,
      'prefill': {
        'name': config.customerName,
        if (config.customerContact.isNotEmpty)
          'contact': config.customerContact,
        if (config.customerEmail.isNotEmpty) 'email': config.customerEmail,
      },
      'theme': {'color': '#4A7C3E'},
    };
    debugPrint(
        '[RazorpayService] Opening checkout — amount=${config.amountInPaise} paise');
    _razorpay.open(options);
  }

  /// Must be called in the owning widget's [State.dispose].
  void dispose() {
    _razorpay.clear();
    debugPrint('[RazorpayService] Disposed');
  }
}
