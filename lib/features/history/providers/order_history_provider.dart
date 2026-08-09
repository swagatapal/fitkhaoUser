import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/order_history_model.dart';

/// Order source filter — maps to the `src` query param on /api/orders/history.
enum OrderHistorySource {
  outlet,
  subscription;

  String get query =>
      this == OrderHistorySource.subscription ? 'subscription' : 'outlet';
}

// ─── Paginated list (per source) ─────────────────────────────────────────────

/// Paginated list state for a single order source (outlet or subscription).
class OrderHistoryState {
  final List<OrderHistory> orders;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentOffset;

  const OrderHistoryState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentOffset = 0,
  });

  OrderHistoryState copyWith({
    List<OrderHistory>? orders,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentOffset,
  }) {
    return OrderHistoryState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentOffset: currentOffset ?? this.currentOffset,
    );
  }
}

/// Manages the paginated order list for one [source]. Each source keeps its own
/// offset / hasMore, so the two tabs paginate independently.
class OrderHistoryListNotifier extends StateNotifier<OrderHistoryState> {
  final Ref ref;
  final OrderHistorySource source;

  static const _pageSize = 20;

  OrderHistoryListNotifier(this.ref, this.source)
      : super(const OrderHistoryState());

  /// Load the first (or next, when [refresh] is false) page for this source.
  Future<void> loadOrderHistory({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = const OrderHistoryState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final repository = ref.read(orderHistoryRepositoryProvider);
      final response = await repository.getOrderHistory(
        limit: _pageSize,
        offset: refresh ? 0 : state.currentOffset,
        src: source.query,
      );

      if (response.success && response.data != null) {
        final newOrders = response.data!.orders;
        state = state.copyWith(
          orders: refresh ? newOrders : [...state.orders, ...newOrders],
          isLoading: false,
          error: null,
          hasMore: response.data!.hasMore,
          currentOffset: refresh
              ? newOrders.length
              : state.currentOffset + newOrders.length,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      debugPrint(
          '[OrderHistoryListNotifier] Error loading ${source.query}: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load order history. Please try again.',
      );
    }
  }

  /// Load the next page (pagination).
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    await loadOrderHistory(refresh: false);
  }

  /// Reload from the first page.
  Future<void> refresh() async {
    await loadOrderHistory(refresh: true);
  }
}

/// Paginated order list, one independent instance per [OrderHistorySource].
final orderHistoryListProvider = StateNotifierProvider.family<
    OrderHistoryListNotifier, OrderHistoryState, OrderHistorySource>(
  (ref, source) => OrderHistoryListNotifier(ref, source),
);

// ─── Per-order actions (invoice + review) ────────────────────────────────────

/// Per-order action state — invoice generation + review submission. Shared
/// across sources since it's keyed by orderId.
class OrderActionsState {
  /// Per-order invoice loading state (keyed by orderId).
  final Map<String, bool> invoiceLoading;

  /// Order IDs that have a review submission in-flight.
  final Set<String> reviewSubmitting;

  const OrderActionsState({
    this.invoiceLoading = const {},
    this.reviewSubmitting = const {},
  });

  bool isInvoiceLoading(String orderId) => invoiceLoading[orderId] == true;
  bool isReviewSubmitting(String orderId) => reviewSubmitting.contains(orderId);

  OrderActionsState copyWith({
    Map<String, bool>? invoiceLoading,
    Set<String>? reviewSubmitting,
  }) {
    return OrderActionsState(
      invoiceLoading: invoiceLoading ?? this.invoiceLoading,
      reviewSubmitting: reviewSubmitting ?? this.reviewSubmitting,
    );
  }
}

class OrderActionsNotifier extends StateNotifier<OrderActionsState> {
  final Ref ref;

  OrderActionsNotifier(this.ref) : super(const OrderActionsState());

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

  /// Submit per-dish ratings and optional overall feedback for a delivered order.
  /// Throws on failure so the UI can display an error snackbar.
  /// On success, invalidates the cached order details so the screen refreshes.
  Future<void> submitReview({
    required String orderId,
    required List<DishRatingInput> items,
    String? feedback,
  }) async {
    state = state.copyWith(
      reviewSubmitting: {...state.reviewSubmitting, orderId},
    );
    try {
      final repository = ref.read(orderHistoryRepositoryProvider);
      await repository.submitReview(
        orderId: orderId,
        items: items,
        feedback: feedback,
      );
      ref.invalidate(orderDetailsProvider(orderId));
    } finally {
      state = state.copyWith(
        reviewSubmitting: state.reviewSubmitting.difference({orderId}),
      );
    }
  }
}

/// Per-order actions provider (invoice + review). Kept under the historical
/// `orderHistoryProvider` name so the tracking / review screens are unchanged.
final orderHistoryProvider =
    StateNotifierProvider<OrderActionsNotifier, OrderActionsState>((ref) {
  return OrderActionsNotifier(ref);
});

/// Fetches the full, up-to-date details for a single order (GET /api/orders/:id).
///
/// Keyed by orderId, so each order's details are fetched and cached
/// independently. The tracking screen watches this and refreshes on entry.
final orderDetailsProvider =
    FutureProvider.family<OrderHistory, String>((ref, orderId) async {
  final repository = ref.read(orderHistoryRepositoryProvider);
  return repository.getOrderById(orderId);
});
