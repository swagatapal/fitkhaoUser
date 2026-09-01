import 'package:facebook_app_events/facebook_app_events.dart';

class MetaEventService {
  MetaEventService._();

  static final MetaEventService instance = MetaEventService._();

  final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  Future<void> logRegistration() async {
    await _facebookAppEvents.logCompletedRegistration(
      registrationMethod: 'email',
    );
  }

  Future<void> logAddToCart({
    required double price,
    required String currency,
    required String productId,
    required String productName,
  }) async {
    await _facebookAppEvents.logAddToCart(
      id: productId,
      type: 'product',
      currency: currency,
      price: price,
    );
  }

  Future<void> logInitiateCheckout({
    required double totalAmount,
    required String currency,
    required int numItems,
  }) async {
    await _facebookAppEvents.logInitiatedCheckout(
      totalPrice: totalAmount,
      currency: currency,
      numItems: numItems,
    );
  }

  Future<void> logPurchase({
    required double amount,
    required String currency,
  }) async {
    await _facebookAppEvents.logPurchase(
      amount: amount,
      currency: currency,
    );
  }
}