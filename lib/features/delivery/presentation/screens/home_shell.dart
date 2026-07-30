import 'package:flutter/material.dart';
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

  void _showSubscription() {
    if (_index != 0) setState(() => _index = 0);
  }

  void _showOrder() {
    if (_index != 1) setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(authProvider.select((s) => s.activeSubscription));
    final hasActive = sub != null && sub.isActive;

    // No active plan → the delivery screen is the home, exactly as before.
    if (!hasActive) return const DeliveryScreen();

    return PopScope(
      // On the Order-Food view, the back gesture returns to the subscription
      // view rather than leaving the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showSubscription();
      },
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
