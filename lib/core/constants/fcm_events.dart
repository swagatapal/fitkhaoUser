class FcmEvent {
  FcmEvent._();

  static const String orderPlaced = 'ORDER_PLACED';
  static const String newOrder = 'NEW_ORDER';
  static const String orderAccepted = 'ORDER_ACCEPTED';
  static const String orderRejected = 'ORDER_REJECTED';
  static const String orderStatusUpdate = 'ORDER_STATUS_UPDATE';

  static const String deliveryAssigned = 'DELIVERY_ASSIGNED';
  static const String ordersAssigned = 'ORDERS_ASSIGNED';
  static const String deliveryStatusUpdate = 'DELIVERY_STATUS_UPDATE';

  static const String subscriptionActivated = 'SUBSCRIPTION_ACTIVATED';
  static const String subscriptionUpgraded = 'SUBSCRIPTION_UPGRADED';
  static const String subscriptionExpiryReminder =
      'SUBSCRIPTION_EXPIRY_REMINDER';

  static const String walletTopup = 'WALLET_TOPUP';

  static const Set<String> orderEvents = {
    orderPlaced,
    newOrder,
    orderAccepted,
    orderRejected,
    orderStatusUpdate,
  };

  static const Set<String> deliveryEvents = {
    deliveryAssigned,
    ordersAssigned,
    deliveryStatusUpdate,
  };

  static const Set<String> subscriptionEvents = {
    subscriptionActivated,
    subscriptionUpgraded,
    subscriptionExpiryReminder,
  };

  static const Set<String> walletEvents = {
    walletTopup,
  };
}
