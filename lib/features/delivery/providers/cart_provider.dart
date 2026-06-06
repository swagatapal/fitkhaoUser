import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../repository/cart_repository.dart';

/// Lifecycle of the server cart, kept alongside the item list so the UI can
/// show first-load spinners, mutation activity and errors without changing the
/// shape of [cartProvider] (which stays a plain `List<CartItem>`).
enum CartSyncStatus { idle, loading, ready, error }

class CartStatus {
  final CartSyncStatus status;

  /// True while at least one add/remove/update network call is in flight.
  final bool isMutating;

  /// Set when the most recent operation failed. Consumed transiently (e.g. to
  /// show a SnackBar) — the optimistic state is always rolled back on failure.
  final String? error;

  const CartStatus({
    this.status = CartSyncStatus.idle,
    this.isMutating = false,
    this.error,
  });

  bool get isLoading => status == CartSyncStatus.loading;
  bool get isError => status == CartSyncStatus.error;

  CartStatus copyWith({
    CartSyncStatus? status,
    bool? isMutating,
    String? error,
    bool clearError = false,
  }) {
    return CartStatus(
      status: status ?? this.status,
      isMutating: isMutating ?? this.isMutating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Companion status for [cartProvider]. The notifier is the only writer.
final cartStatusProvider =
    StateProvider<CartStatus>((ref) => const CartStatus());

/// Server-backed cart.
///
/// Mutations are optimistic: the local list updates immediately for a snappy
/// UI, the change is pushed to `/cart`, and once no further mutations are in
/// flight the authoritative server cart is re-fetched to reconcile. On failure
/// the list is rolled back to the pre-mutation snapshot.
class CartNotifier extends StateNotifier<List<CartItem>> {
  final Ref _ref;

  /// Count of in-flight mutations — used so overlapping rapid taps reconcile /
  /// roll back only on the last settled call, never mid-sequence.
  int _pending = 0;
  String? _lastError;

  CartNotifier(this._ref) : super(const []) {
    loadCart();
  }

  CartRepository get _repo => _ref.read(cartRepositoryProvider);

  void _setStatus(CartStatus status) =>
      _ref.read(cartStatusProvider.notifier).state = status;

  String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  int _qtyOf(String dishId) {
    for (final c in state) {
      if (c.menuItem.id == dishId) return c.quantity;
    }
    return 0;
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Fetches the authoritative cart. Safe to call on every screen entry.
  Future<void> loadCart() async {
    _setStatus(const CartStatus(status: CartSyncStatus.loading));
    try {
      final res = await _repo.getCart();
      state = res.data?.items ?? const [];
      _setStatus(const CartStatus(status: CartSyncStatus.ready));
    } catch (e) {
      debugPrint('[CartNotifier] loadCart error: $e');
      _setStatus(CartStatus(status: CartSyncStatus.error, error: _msg(e)));
    }
  }

  // ── Mutations (optimistic) ───────────────────────────────────────────────────

  /// Adds one unit of [item] (or increments it if already present).
  void addItem(MenuItem item) {
    final snapshot = state;
    final nextQty = _qtyOf(item.id) + 1;
    state = _withQuantity(item, nextQty);
    _push(() => _repo.setItemQuantity(outletDishId: item.id, quantity: nextQty),
        rollback: snapshot);
  }

  /// Sets [dishId] to an absolute [quantity]; `<= 0` removes it.
  void updateQuantity(String dishId, int quantity) {
    if (quantity <= 0) {
      removeItem(dishId);
      return;
    }
    final snapshot = state;
    state = [
      for (final c in state)
        if (c.menuItem.id == dishId) c.copyWith(quantity: quantity) else c,
    ];
    _push(
        () =>
            _repo.setItemQuantity(outletDishId: dishId, quantity: quantity),
        rollback: snapshot);
  }

  /// Removes [dishId] from the cart.
  void removeItem(String dishId) {
    final snapshot = state;
    state = state.where((c) => c.menuItem.id != dishId).toList();
    _push(() => _repo.setItemQuantity(outletDishId: dishId, quantity: 0),
        rollback: snapshot);
  }

  /// Clears every line (no bulk endpoint — removes each on the server).
  void clearCart() {
    final snapshot = state;
    final ids = state.map((c) => c.menuItem.id).toList();
    if (ids.isEmpty) return;
    state = const [];
    _push(
      () async {
        for (final id in ids) {
          await _repo.setItemQuantity(outletDishId: id, quantity: 0);
        }
        return _repo.getCart();
      },
      rollback: snapshot,
    );
  }

  /// Re-fetches and surfaces errors via the status provider; used by retry.
  Future<void> refresh() => loadCart();

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Applies [quantity] for [item] over the current list, adding the line if
  /// it isn't present yet.
  List<CartItem> _withQuantity(MenuItem item, int quantity) {
    final exists = state.any((c) => c.menuItem.id == item.id);
    if (exists) {
      return [
        for (final c in state)
          if (c.menuItem.id == item.id) c.copyWith(quantity: quantity) else c,
      ];
    }
    return [...state, CartItem(menuItem: item, quantity: quantity)];
  }

  /// Runs a mutation network call, reconciling with the server (or rolling
  /// back) only once it is the last in-flight call.
  Future<void> _push(
    Future<dynamic> Function() call, {
    required List<CartItem> rollback,
  }) async {
    _pending++;
    _setStatus(_ref.read(cartStatusProvider).copyWith(
          status: CartSyncStatus.ready,
          isMutating: true,
          clearError: true,
        ));
    try {
      await call();
      // Reconcile with authoritative server state only when settled, so an
      // in-progress tap sequence isn't interrupted by a stale snapshot.
      if (_pending == 1) {
        final res = await _repo.getCart();
        state = res.data?.items ?? state;
      }
    } catch (e) {
      debugPrint('[CartNotifier] mutation error: $e');
      _lastError = _msg(e);
      if (_pending == 1) state = rollback;
    } finally {
      _pending--;
      if (_pending == 0) {
        _setStatus(CartStatus(
          status: CartSyncStatus.ready,
          isMutating: false,
          error: _lastError,
        ));
        _lastError = null;
      }
    }
  }
}

/// Provider for cart management. State is the list of cart items so all
/// existing consumers (`select`, totals, steppers) keep working unchanged.
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier(ref);
});

/// Provider for total items count
final cartTotalItemsProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

/// Provider for total price
final cartTotalPriceProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.totalPrice);
});
