import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../models/transaction_model.dart';

/// State for the wallet transaction-history screen.
class TransactionHistoryState {
  final List<Transaction> transactions;
  final bool isLoading; // first page / full refresh
  final bool isLoadingMore; // appending a page
  final String? error;
  final bool hasMore;
  final int offset;

  /// Per-subscription invoice-fetch loading, keyed by subscriptionId.
  final Map<String, bool> invoiceLoading;

  const TransactionHistoryState({
    this.transactions = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = false,
    this.offset = 0,
    this.invoiceLoading = const {},
  });

  bool get isEmpty => transactions.isEmpty;
  bool isInvoiceLoading(String subscriptionId) =>
      invoiceLoading[subscriptionId] == true;

  TransactionHistoryState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    bool? hasMore,
    int? offset,
    Map<String, bool>? invoiceLoading,
  }) {
    return TransactionHistoryState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      invoiceLoading: invoiceLoading ?? this.invoiceLoading,
    );
  }
}

class TransactionHistoryNotifier
    extends StateNotifier<TransactionHistoryState> {
  final Ref _ref;
  static const int _limit = 50;

  TransactionHistoryNotifier(this._ref)
      : super(const TransactionHistoryState());

  /// Loads the first page. [refresh] resets the list; otherwise keeps the
  /// current data on screen while reloading from offset 0.
  Future<void> load({bool refresh = false}) async {
    if (state.isLoading) return;
    state = refresh
        ? const TransactionHistoryState(isLoading: true)
        : state.copyWith(isLoading: true, clearError: true);

    try {
      final repo = _ref.read(walletRepositoryProvider);
      final res = await repo.getTransactionHistory(limit: _limit, offset: 0);
      final data = res.data;
      state = state.copyWith(
        transactions: data.transactions,
        isLoading: false,
        clearError: true,
        hasMore: data.pagination.hasMore,
        offset: data.transactions.length,
      );
    } catch (e) {
      debugPrint('[TransactionHistory] load error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load transaction history. Please try again.',
      );
    }
  }

  /// Appends the next page when more are available.
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);

    try {
      final repo = _ref.read(walletRepositoryProvider);
      final res =
          await repo.getTransactionHistory(limit: _limit, offset: state.offset);
      final data = res.data;
      state = state.copyWith(
        transactions: [...state.transactions, ...data.transactions],
        isLoadingMore: false,
        hasMore: data.pagination.hasMore,
        offset: state.offset + data.transactions.length,
      );
    } catch (e) {
      debugPrint('[TransactionHistory] loadMore error: $e');
      // Keep existing data; just stop the spinner.
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> refresh() => load(refresh: true);

  /// Fetches the subscription invoice URL for [subscriptionId], tracking a
  /// per-subscription loading flag. Returns the URL, or null if none is found.
  /// Throws on a network failure so the caller can show an error.
  Future<String?> fetchInvoiceUrl(String subscriptionId) async {
    state = state.copyWith(
      invoiceLoading: {...state.invoiceLoading, subscriptionId: true},
    );
    try {
      final data = await _ref
          .read(subscriptionRepositoryProvider)
          .getInvoice(subscriptionId);
      return _firstUrl(data);
    } finally {
      state = state.copyWith(
        invoiceLoading: {...state.invoiceLoading, subscriptionId: false},
      );
    }
  }

  String? _firstUrl(Map<String, dynamic> data) {
    for (final key in ['url', 'invoiceUrl', 'pdfUrl', 'invoicePdf', 'link']) {
      final v = data[key];
      if (v is String && v.startsWith('http')) return v;
    }
    return null;
  }
}

final transactionHistoryProvider = StateNotifierProvider<
    TransactionHistoryNotifier, TransactionHistoryState>(
  (ref) => TransactionHistoryNotifier(ref),
);
