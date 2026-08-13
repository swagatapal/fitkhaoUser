import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import 'delivery_screen.dart';
import 'my_subscription_screen.dart';

/// Post-login home.
///
/// With an active subscription the user lands on [MySubscriptionScreen] and can
/// switch to the food-ordering [DeliveryScreen] and back. Both live in an
/// [IndexedStack] so switching is instant and each keeps its scroll/tab state.
/// Without an active subscription the delivery screen is shown as usual.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // 0 = My Subscription, 1 = Order Food (delivery).
  int _index = 0;

  /// Timestamp of the last back press on the subscription (home) view — used to
  /// require a second back within [_exitWindow] to actually leave the app.
  DateTime? _lastBackAt;
  static const _exitWindow = Duration(seconds: 2);

  void _showSubscription() {
    if (_index != 0) setState(() => _index = 0);
  }

  void _showOrder() {
    if (_index != 1) setState(() => _index = 1);
  }

  /// Handles the system back gesture. On the Order-Food view it returns to the
  /// subscription view; on the subscription (home) view it requires a
  /// double-back within [_exitWindow] to exit, showing a toast on the first tap.
  void _handleBack(bool didPop) {
    if (didPop) return;

    if (_index != 0) {
      _showSubscription();
      return;
    }

    final now = DateTime.now();
    if (_lastBackAt != null && now.difference(_lastBackAt!) <= _exitWindow) {
      SystemNavigator.pop();
      return;
    }

    _lastBackAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: _exitWindow,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(authProvider.select((s) => s.activeSubscription));
    final hasActive = sub != null && sub.isActive;

    // No active plan → the delivery screen is the home, exactly as before.
    if (!hasActive) return const DeliveryScreen();

    return PopScope(
      // We intercept every back: on Order-Food it returns to the subscription
      // view; on the subscription view a double-back exits the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
      child: IndexedStack(
        index: _index,
        children: [
          MySubscriptionScreen(
            planName: sub.planName,
            subscriptionId: sub.id,
            onSwitchToOrder: _showOrder,
          ),
          DeliveryScreen(onSwitchToSubscription: _showSubscription),
        ],
      ),
    );
  }
}
