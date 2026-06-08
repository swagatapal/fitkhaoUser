import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/menu_item.dart';
import '../repository/menu_repository.dart';
import 'menu_provider.dart' show menuRepositoryProvider;

/// Lifecycle of a backend dish search.
enum DishSearchStatus { idle, loading, loadingMore, success, empty, error }

/// State for the delivery-screen search bar (server-side search).
class DishSearchState {
  final String query;
  final DishSearchStatus status;
  final List<MenuItem> results;
  final int page;
  final int totalPages;
  final String? error;

  const DishSearchState({
    this.query = '',
    this.status = DishSearchStatus.idle,
    this.results = const [],
    this.page = 0,
    this.totalPages = 1,
    this.error,
  });

  /// True whenever there is an active (non-blank) query — drives the screen to
  /// show search results instead of the browse view.
  bool get isActive => query.trim().isNotEmpty;
  bool get isLoading => status == DishSearchStatus.loading;
  bool get isLoadingMore => status == DishSearchStatus.loadingMore;

  bool get canLoadMore =>
      isActive &&
      status == DishSearchStatus.success &&
      page < totalPages - 1;

  DishSearchState copyWith({
    String? query,
    DishSearchStatus? status,
    List<MenuItem>? results,
    int? page,
    int? totalPages,
    String? error,
    bool clearError = false,
  }) {
    return DishSearchState(
      query: query ?? this.query,
      status: status ?? this.status,
      results: results ?? this.results,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DishSearchNotifier extends StateNotifier<DishSearchState> {
  final Ref _ref;
  static const int _pageSize = 20;

  /// Monotonic token — every new search bumps it so late-arriving responses
  /// from a previous query (or a cleared search) are ignored.
  int _requestId = 0;
  String? _kitchenId;

  DishSearchNotifier(this._ref) : super(const DishSearchState());

  MenuRepository get _repo => _ref.read(menuRepositoryProvider);

  /// Runs a fresh search for [query] (page 0). A blank query clears results.
  /// Debouncing is handled by the caller; this guards against stale responses.
  Future<void> search(String query, {String? kitchenId}) async {
    _kitchenId = kitchenId;
    final q = query.trim();

    if (q.isEmpty) {
      clear();
      return;
    }

    final reqId = ++_requestId;
    state = DishSearchState(query: q, status: DishSearchStatus.loading);

    try {
      final page = await _repo.searchDishes(
        query: q,
        kitchenId: kitchenId,
        pageIndex: 0,
        pageSize: _pageSize,
      );
      if (reqId != _requestId) return; // superseded
      state = DishSearchState(
        query: q,
        status: page.items.isEmpty
            ? DishSearchStatus.empty
            : DishSearchStatus.success,
        results: page.items,
        page: 0,
        totalPages: page.totalPages,
      );
    } catch (e) {
      if (reqId != _requestId) return;
      debugPrint('[DishSearch] error: $e');
      state = DishSearchState(
        query: q,
        status: DishSearchStatus.error,
        error: _msg(e),
      );
    }
  }

  /// Appends the next page for the current query.
  Future<void> loadMore() async {
    if (!state.canLoadMore) return;

    final reqId = _requestId; // same query token
    final next = state.page + 1;
    state = state.copyWith(status: DishSearchStatus.loadingMore);

    try {
      final page = await _repo.searchDishes(
        query: state.query,
        kitchenId: _kitchenId,
        pageIndex: next,
        pageSize: _pageSize,
      );
      if (reqId != _requestId) return; // query changed mid-flight
      state = state.copyWith(
        status: DishSearchStatus.success,
        results: [...state.results, ...page.items],
        page: next,
        totalPages: page.totalPages,
      );
    } catch (e) {
      if (reqId != _requestId) return;
      debugPrint('[DishSearch] loadMore error: $e');
      // Keep what we have; just stop the spinner.
      state = state.copyWith(status: DishSearchStatus.success);
    }
  }

  /// Clears the search and returns to the browse view.
  void clear() {
    _requestId++; // invalidate any in-flight request
    state = const DishSearchState();
  }

  /// Retries the current query (used by the error state).
  Future<void> retry() => search(state.query, kitchenId: _kitchenId);

  String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }
}

final dishSearchProvider =
    StateNotifierProvider<DishSearchNotifier, DishSearchState>(
        (ref) => DishSearchNotifier(ref));
