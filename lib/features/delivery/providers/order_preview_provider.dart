import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/order_placement_model.dart';
import '../models/order_preview_model.dart';

/// State of the server-computed order preview that drives the checkout summary.
class OrderPreviewState {
  final OrderPreview? preview;
  final bool isLoading;
  final String? error;

  const OrderPreviewState({
    this.preview,
    this.isLoading = false,
    this.error,
  });

  /// Authoritative payable total, or null until a preview has loaded.
  double? get total => preview?.pricing.total;

  OrderPreviewState copyWith({
    OrderPreview? preview,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OrderPreviewState(
      preview: preview ?? this.preview,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Fetches `/api/orders/preview` whenever the cart, coupons or kitchen change.
///
/// • Debounced (300 ms) so rapid quantity taps fire a single request.
/// • Sequence-guarded so a slow earlier response can't overwrite a newer one.
/// • Signature-deduped so identical inputs never refetch.
class OrderPreviewNotifier extends StateNotifier<OrderPreviewState> {
  OrderPreviewNotifier(this._ref) : super(const OrderPreviewState());

  final Ref _ref;
  Timer? _debounce;
  int _seq = 0;
  String _lastSig = '';

  void request({
    required String kitchenId,
    required List<OrderItem> items,
    required List<String> couponIds,
  }) {
    final sig = _signature(kitchenId, items, couponIds);
    if (sig == _lastSig) return; // inputs unchanged
    _lastSig = sig;

    _debounce?.cancel();

    if (kitchenId.isEmpty || items.isEmpty) {
      // Nothing to price yet (no serviceable kitchen / empty cart).
      _seq++; // invalidate any in-flight response
      state = const OrderPreviewState();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300),
        () => _fetch(kitchenId, items, couponIds));
  }

  /// Force a refetch with the same inputs (used by the summary's retry button).
  void retry({
    required String kitchenId,
    required List<OrderItem> items,
    required List<String> couponIds,
  }) {
    _lastSig = '';
    request(kitchenId: kitchenId, items: items, couponIds: couponIds);
  }

  Future<void> _fetch(
      String kitchenId, List<OrderItem> items, List<String> couponIds) async {
    final id = ++_seq;
    // Keep the previous preview visible while refreshing.
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(orderRepositoryProvider);
      final res = await repo.previewOrder(
        kitchenId: kitchenId,
        items: items,
        couponIds: couponIds,
      );
      if (id != _seq) return; // a newer request superseded this one
      if (res.success && res.data != null) {
        state = OrderPreviewState(preview: res.data, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: res.message.isNotEmpty
              ? res.message
              : 'Could not calculate pricing. Please try again.',
        );
      }
    } catch (_) {
      if (id != _seq) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not calculate pricing. Please try again.',
      );
    }
  }

  String _signature(
      String kitchenId, List<OrderItem> items, List<String> couponIds) {
    final itemsSig = (items
            .map((e) => '${e.dishId}:${e.quantity}:${e.dishServing}')
            .toList()
          ..sort())
        .join(',');
    final couponSig = ([...couponIds]..sort()).join(',');
    return '$kitchenId|$itemsSig|$couponSig';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// Auto-disposed so each checkout entry starts with a fresh preview.
final orderPreviewProvider = StateNotifierProvider.autoDispose<
    OrderPreviewNotifier, OrderPreviewState>((ref) => OrderPreviewNotifier(ref));
