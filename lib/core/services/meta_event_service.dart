import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

/// Meta (Facebook) app-events tracking.
///
/// Every method is fire-and-forget and **never throws**: a failure in the Meta
/// SDK must not be able to break a checkout or block a login, so each call is
/// isolated behind [_safe] and only logged. Call sites can therefore `await`
/// these freely without a try/catch of their own.
class MetaEventService {
  MetaEventService._();

  static final MetaEventService instance = MetaEventService._();

  final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  /// Default currency — the app prices everything in rupees.
  static const String defaultCurrency = 'INR';

  /// Content type reported for outlet (food) orders.
  static const String contentTypeOutletOrder = 'outlet_order';

  /// Content type reported for subscription purchases.
  static const String contentTypeSubscription = 'subscription';

  /// Runs [action], swallowing and logging anything it throws.
  Future<void> _safe(String event, Future<void> Function() action) async {
    try {
      await action();
      debugPrint('[MetaEvent] $event logged');
    } catch (e) {
      // Analytics is never allowed to surface as a user-visible failure.
      debugPrint('[MetaEvent] $event failed: $e');
    }
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// A brand-new user finished signing up.
  Future<void> logRegistration({String method = 'phone_otp'}) {
    return _safe(
      'CompletedRegistration',
      () => _facebookAppEvents.logCompletedRegistration(
        registrationMethod: method,
      ),
    );
  }

  /// An existing user signed in. Meta has no standard login event, so this is
  /// sent as the conventional custom `Login` event.
  Future<void> logLogin({String method = 'phone_otp'}) {
    return _safe(
      'Login',
      () => _facebookAppEvents.logEvent(
        name: 'Login',
        parameters: {'method': method},
      ),
    );
  }

  // ── Commerce ───────────────────────────────────────────────────────────────

  Future<void> logAddToCart({
    required double price,
    required String currency,
    required String productId,
    required String productName,
  }) {
    return _safe(
      'AddToCart($productId)',
      () => _facebookAppEvents.logAddToCart(
        id: productId,
        type: 'product',
        currency: currency,
        price: price,
        // Carries the readable name through — without this the event reaches
        // Meta with an id only, which is unusable in reporting.
        content: {
          'id': productId,
          'name': productName,
          'quantity': 1,
          'item_price': price,
        },
      ),
    );
  }

  /// The user started paying. [contentType] separates outlet orders from
  /// subscriptions in Events Manager.
  Future<void> logInitiateCheckout({
    required double totalAmount,
    required int numItems,
    String currency = defaultCurrency,
    String? contentType,
    String? contentId,
  }) {
    return _safe(
      'InitiateCheckout(${contentType ?? 'generic'})',
      () => _facebookAppEvents.logInitiatedCheckout(
        totalPrice: totalAmount,
        currency: currency,
        numItems: numItems,
        contentType: contentType,
        contentId: contentId,
      ),
    );
  }

  /// A payment completed. Used for both outlet orders and subscriptions so
  /// revenue stays in one event; [contentType] and [orderId] keep them
  /// separable in reporting.
  Future<void> logPurchase({
    required double amount,
    String currency = defaultCurrency,
    String? contentType,
    String? orderId,
    int? numItems,
  }) {
    return _safe(
      'Purchase(${contentType ?? 'generic'}, $amount $currency)',
      () => _facebookAppEvents.logPurchase(
        amount: amount,
        currency: currency,
        parameters: {
          if (contentType != null) 'fb_content_type': contentType,
          if (orderId != null && orderId.isNotEmpty) 'fb_order_id': orderId,
          if (numItems != null) 'fb_num_items': numItems,
        },
      ),
    );
  }
}
