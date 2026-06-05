import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/order_history_model.dart';

/// State for order history
class OrderHistoryState {
  final List<OrderHistory> orders;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentOffset;

  /// Per-order invoice loading state (keyed by orderId).
  final Map<String, bool> invoiceLoading;

  const OrderHistoryState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentOffset = 0,
    this.invoiceLoading = const {},
  });

  bool isInvoiceLoading(String orderId) => invoiceLoading[orderId] == true;

  OrderHistoryState copyWith({
    List<OrderHistory>? orders,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentOffset,
    Map<String, bool>? invoiceLoading,
  }) {
    return OrderHistoryState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentOffset: currentOffset ?? this.currentOffset,
      invoiceLoading: invoiceLoading ?? this.invoiceLoading,
    );
  }
}

/// Order history notifier
class OrderHistoryNotifier extends StateNotifier<OrderHistoryState> {
  final Ref ref;

  OrderHistoryNotifier(this.ref) : super(const OrderHistoryState());

  /// Load initial order history
  Future<void> loadOrderHistory({bool refresh = false}) async {
    if (state.isLoading) return;

    // If refreshing, reset state
    if (refresh) {
      state = const OrderHistoryState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final repository = ref.read(orderHistoryRepositoryProvider);
      final response = await repository.getOrderHistory(
        limit: 20,
        offset: refresh ? 0 : state.currentOffset,
      );

      if (response.success && response.data != null) {
        final newOrders = response.data!.orders;

        state = state.copyWith(
          orders: refresh ? newOrders : [...state.orders, ...newOrders],
          isLoading: false,
          error: null,
          hasMore: response.data!.hasMore,
          currentOffset: refresh ? newOrders.length : state.currentOffset + newOrders.length,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
      }
    } catch (e) {
      debugPrint('[OrderHistoryNotifier] Error loading order history: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load order history. Please try again.',
      );
    }
  }

  /// Load more orders (pagination)
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    await loadOrderHistory(refresh: false);
  }

  /// Refresh order history
  Future<void> refresh() async {
    await loadOrderHistory(refresh: true);
  }

  /// Generates the invoice for [orderId] and returns the PDF URL.
  /// Tracks per-order loading state so the caller can show a spinner.
  /// Throws on error so the UI can show a snackbar.
  Future<String> fetchInvoiceUrl(String orderId) async {
    state = state.copyWith(
      invoiceLoading: {...state.invoiceLoading, orderId: true},
    );
    try {
      final repository = ref.read(orderHistoryRepositoryProvider);
      final url = await repository.getInvoiceUrl(orderId);
      return url;
    } finally {
      state = state.copyWith(
        invoiceLoading: {...state.invoiceLoading, orderId: false},
      );
    }
  }

  /// Get upcoming orders
  List<OrderHistory> get upcomingOrders {
    return state.orders.where((order) {
      return order.orderStatus != 'delivered' && order.orderStatus != 'cancelled';
    }).toList();
  }

  /// Get delivered orders
  List<OrderHistory> get deliveredOrders {
    return state.orders.where((order) {
      return order.orderStatus == 'delivered';
    }).toList();
  }
}

/// Provider for order history
final orderHistoryProvider = StateNotifierProvider<OrderHistoryNotifier, OrderHistoryState>((ref) {
  return OrderHistoryNotifier(ref);
});
