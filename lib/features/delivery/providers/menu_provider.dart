import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/menu_item.dart';
import '../repository/menu_repository.dart';

export '../repository/menu_repository.dart' show MenuPageResult;

// ─── Repository provider ──────────────────────────────────────────────────────

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);
  if (localStorage == null) throw Exception('LocalStorage not initialized');
  return MenuRepository(localStorage: localStorage, apiClient: apiClient);
});

// ─── MenuNotifier (used by MenuListScreen) ────────────────────────────────────

class MenuNotifier extends StateNotifier<AsyncValue<List<MenuItem>>> {
  final MenuRepository _menuRepository;
  MenuNotifier(this._menuRepository) : super(const AsyncValue.loading());

  Future<void> loadMenuItems({String? mealType}) async {
    state = const AsyncValue.loading();
    try {
      final items = await _menuRepository.getMenuItems(mealType: mealType);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh({String? mealType}) async =>
      loadMenuItems(mealType: mealType);
}

final menuProvider =
    StateNotifierProvider<MenuNotifier, AsyncValue<List<MenuItem>>>(
  (ref) => MenuNotifier(ref.watch(menuRepositoryProvider)),
);

// ─── Models ───────────────────────────────────────────────────────────────────

/// One category section displayed in the "All" grouped view
class GroupedDishSection {
  final DishCategory category;
  final List<MenuItem> items;
  const GroupedDishSection({required this.category, required this.items});
}

// ─── AllDishesState ───────────────────────────────────────────────────────────

class AllDishesState {
  // ── Category tabs ──────────────────────────────────────────────────────────
  final List<DishCategory> categories;
  final bool areCategoriesLoading;

  // ── "All" view cache  (categoryId = null, paginated) ──────────────────────
  final List<MenuItem> allItems;
  final int allPage;
  final int allTotalPages;

  // ── Per-category view cache (categoryId set, paginated) ───────────────────
  final List<MenuItem> categoryItems;
  final int catPage;
  final int catTotalPages;

  // ── Active loading indicators ─────────────────────────────────────────────
  /// true while the first page of the active view is being fetched
  final bool isLoading;

  /// true while an additional page is being appended
  final bool isLoadingMore;

  // ── Shared state ──────────────────────────────────────────────────────────
  /// null  → "All" grouped view
  /// non-null → per-category flat view
  final String? selectedCategoryId;

  /// Selected dish-type filters (multi-select), each value normalized:
  /// 'veg' | 'nonveg' | 'eggetarian' | 'vegan' | 'beverage' | 'smoothie'.
  /// Empty set → no type filter (show all).
  final Set<String> selectedDishTypes;

  final String searchQuery;
  final String? error;

  const AllDishesState({
    this.categories = const [],
    this.areCategoriesLoading = false,
    this.allItems = const [],
    this.allPage = 0,
    this.allTotalPages = 1,
    this.categoryItems = const [],
    this.catPage = 0,
    this.catTotalPages = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.selectedCategoryId,
    this.selectedDishTypes = const {},
    this.searchQuery = '',
    this.error,
  });

  // ── Computed ───────────────────────────────────────────────────────────────

  bool get isAllView => selectedCategoryId == null;

  /// Active raw items depending on which view is shown
  List<MenuItem> get items => isAllView ? allItems : categoryItems;

  /// True when another page can be fetched in the active view
  bool get canLoadMore {
    if (isLoading || isLoadingMore) return false;
    final page = isAllView ? allPage : catPage;
    final total = isAllView ? allTotalPages : catTotalPages;
    return page < total - 1;
  }

  /// Dish-type + search filter applied to the active items list.
  ///
  /// [selectedDishTypes] holds normalized values from the UI chips:
  ///   'veg' | 'nonveg' | 'eggetarian' | 'vegan' | 'beverage' | 'smoothie'.
  /// Empty → no type filter. When multiple types are selected, an item is kept
  /// if ANY of its [MenuItem.menuTypes] matches ANY selected type (union/OR),
  /// so an egg dish tagged ['nonveg','eggetarian'] surfaces under both filters.
  List<MenuItem> get filteredItems {
    var list = items;

    // ── Search ──────────────────────────────────────────────────────────────
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where((i) =>
              i.name.toLowerCase().contains(q) ||
              i.categoryName.toLowerCase().contains(q))
          .toList();
    }

    // ── Dish-type filter (multi-select, OR semantics) ─────────────────────────
    if (selectedDishTypes.isEmpty) return list;

    return list
        .where((i) => i.menuTypes.any(selectedDishTypes.contains))
        .toList();
  }

  /// Group [filteredItems] by category preserving server order.
  /// Used in the "All" view only.
  List<GroupedDishSection> get groupedSections {
    final filtered = filteredItems;
    final seen = <String>{};
    final order = <String>[];
    final map = <String, List<MenuItem>>{};

    for (final item in filtered) {
      final key = item.categoryId.isNotEmpty ? item.categoryId : '__other__';
      if (seen.add(key)) order.add(key);
      map.putIfAbsent(key, () => []).add(item);
    }

    return order.map((key) {
      // Try to resolve the display name from the API category list first,
      // then fall back to the category data embedded in the item itself.
      final cat = categories.firstWhere(
        (c) => c.id == key,
        orElse: () {
          final first = map[key]!.first;
          final name = first.categoryName.isNotEmpty
              ? first.categoryName
              : first.category.isNotEmpty
                  ? first.category
                  : 'Other';
          return DishCategory(id: key, name: name);
        },
      );
      return GroupedDishSection(category: cat, items: map[key]!);
    }).toList();
  }

  AllDishesState copyWith({
    List<DishCategory>? categories,
    bool? areCategoriesLoading,
    List<MenuItem>? allItems,
    int? allPage,
    int? allTotalPages,
    List<MenuItem>? categoryItems,
    int? catPage,
    int? catTotalPages,
    bool? isLoading,
    bool? isLoadingMore,
    String? selectedCategoryId,
    bool clearCategoryFilter = false,
    Set<String>? selectedDishTypes,
    String? searchQuery,
    String? error,
    bool clearError = false,
  }) {
    return AllDishesState(
      categories: categories ?? this.categories,
      areCategoriesLoading: areCategoriesLoading ?? this.areCategoriesLoading,
      allItems: allItems ?? this.allItems,
      allPage: allPage ?? this.allPage,
      allTotalPages: allTotalPages ?? this.allTotalPages,
      categoryItems: categoryItems ?? this.categoryItems,
      catPage: catPage ?? this.catPage,
      catTotalPages: catTotalPages ?? this.catTotalPages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      selectedCategoryId: clearCategoryFilter
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      selectedDishTypes: selectedDishTypes ?? this.selectedDishTypes,
      searchQuery: searchQuery ?? this.searchQuery,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── AllDishesNotifier ────────────────────────────────────────────────────────

class AllDishesNotifier extends StateNotifier<AllDishesState> {
  final MenuRepository _repo;
  AllDishesNotifier(this._repo) : super(const AllDishesState());

  // ── Initial load ──────────────────────────────────────────────────────────

  /// Fetches categories and the first page of ALL items in parallel.
  /// Always resets to the "All" view.
  Future<void> loadMenuItems() async {
    state = const AllDishesState(
      areCategoriesLoading: true,
      isLoading: true,
    );

    // Kick off both requests immediately (parallel execution)
    final categoriesFuture = _repo.getCategories();
    final pageFuture = _repo.getMenuPage(
      categoryId: null,
      pageIndex: 0,
      pageSize: 10,
    );

    try {
      final categories = await categoriesFuture;
      final page = await pageFuture;

      state = AllDishesState(
        categories: categories,
        allItems: page.items,
        allPage: 0,
        allTotalPages: page.totalPages,
      );
    } catch (e) {
      state = AllDishesState(error: e.toString());
    }
  }

  // ── Category selection ────────────────────────────────────────────────────

  /// [categoryId] = null → switch back to "All" view (no API call, cache used).
  /// [categoryId] = id   → load first page for that category.
  Future<void> selectCategory(String? categoryId) async {
    if (categoryId == null) {
      // Restore All view instantly from cache
      state = state.copyWith(clearCategoryFilter: true, clearError: true);
      return;
    }

    // Per-category: reset category cache and fetch page 0
    state = state.copyWith(
      selectedCategoryId: categoryId,
      isLoading: true,
      categoryItems: [],
      catPage: 0,
      catTotalPages: 1,
      clearError: true,
    );

    try {
      final page = await _repo.getMenuPage(
        categoryId: categoryId,
        pageIndex: 0,
        pageSize: 10,
      );
      state = state.copyWith(
        categoryItems: page.items,
        catPage: 0,
        catTotalPages: page.totalPages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Scroll-triggered pagination ───────────────────────────────────────────

  /// Appends the next page. Works identically for both "All" and
  /// per-category views — the correct [categoryId] is always in state.
  Future<void> loadMore() async {
    if (!state.canLoadMore) return;

    final isAll = state.isAllView;
    final nextPage = (isAll ? state.allPage : state.catPage) + 1;

    state = state.copyWith(isLoadingMore: true);

    try {
      final page = await _repo.getMenuPage(
        categoryId: state.selectedCategoryId,
        pageIndex: nextPage,
        pageSize: 10,
      );

      if (isAll) {
        state = state.copyWith(
          allItems: [...state.allItems, ...page.items],
          allPage: nextPage,
          allTotalPages: page.totalPages,
          isLoadingMore: false,
        );
      } else {
        state = state.copyWith(
          categoryItems: [...state.categoryItems, ...page.items],
          catPage: nextPage,
          catTotalPages: page.totalPages,
          isLoadingMore: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  /// Toggle a single dish-type filter on/off (multi-select).
  /// [type] must already be normalized ('veg','nonveg','eggetarian', …).
  void toggleDishType(String type) {
    final next = Set<String>.from(state.selectedDishTypes);
    if (!next.add(type)) next.remove(type);
    state = state.copyWith(selectedDishTypes: next);
  }

  /// Clear all dish-type filters (back to "All").
  void clearDishTypes() =>
      state = state.copyWith(selectedDishTypes: const {});

  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  Future<void> refresh() => loadMenuItems();

  /// Cache-friendly refresh: re-fetches categories + the first "All" page
  /// WITHOUT flipping the loading flags, so the currently rendered items stay
  /// on screen (no skeleton flash) until fresh data swaps in. Used on re-entry
  /// when state already holds cached dishes.
  Future<void> silentRefresh() async {
    try {
      final categories = await _repo.getCategories();
      final page = await _repo.getMenuPage(
        categoryId: null,
        pageIndex: 0,
        pageSize: 10,
      );
      // Only swap if nothing else changed the view in the meantime.
      state = state.copyWith(
        categories: categories,
        allItems: page.items,
        allPage: 0,
        allTotalPages: page.totalPages,
        clearError: true,
      );
    } catch (_) {
      // Silent — keep showing cached data on failure.
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final allDishesProvider =
    StateNotifierProvider<AllDishesNotifier, AllDishesState>(
  (ref) => AllDishesNotifier(ref.watch(menuRepositoryProvider)),
);
