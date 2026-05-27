import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/menu_item.dart';
import '../repository/menu_repository.dart';

export '../repository/menu_repository.dart' show MenuPageResult;

// ─── Repository provider ──────────────────────────────────────────────────────

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

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
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh({String? mealType}) async =>
      loadMenuItems(mealType: mealType);
}

final menuProvider =
    StateNotifierProvider<MenuNotifier, AsyncValue<List<MenuItem>>>((ref) {
  return MenuNotifier(ref.watch(menuRepositoryProvider));
});

// ─── Models for DeliveryScreen ─────────────────────────────────────────────────

/// One category section in the "All" grouped view
class GroupedDishSection {
  final DishCategory category;
  final List<MenuItem> items;

  const GroupedDishSection({required this.category, required this.items});
}

// ─── AllDishesState ───────────────────────────────────────────────────────────

class AllDishesState {
  // ── Category list (from API) ───────────────────────────────────────────────
  final List<DishCategory> categories;
  final bool areCategoriesLoading;

  // ── "All" grouped view ────────────────────────────────────────────────────
  final List<GroupedDishSection> sections;
  final bool isAllViewLoading;

  // ── Per-category paginated view ───────────────────────────────────────────
  final List<MenuItem> categoryItems;
  final bool isLoading;
  final bool isLoadingMore;
  final int currentPage;
  final int totalPages;
  final int totalCount;

  // ── Shared ────────────────────────────────────────────────────────────────
  /// null → "All" grouped view; non-null → per-category view
  final String? selectedCategoryId;

  /// 'all' | 'veg' | 'non-veg'
  final String selectedDishType;

  final String searchQuery;
  final String? error;

  const AllDishesState({
    this.categories = const [],
    this.areCategoriesLoading = false,
    this.sections = const [],
    this.isAllViewLoading = false,
    this.categoryItems = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.currentPage = 0,
    this.totalPages = 1,
    this.totalCount = 0,
    this.selectedCategoryId,
    this.selectedDishType = 'all',
    this.searchQuery = '',
    this.error,
  });

  /// True when showing the "All" grouped view
  bool get isAllView => selectedCategoryId == null;

  /// Only valid / meaningful in per-category view
  bool get canLoadMore =>
      !isAllView &&
      !isLoading &&
      !isLoadingMore &&
      currentPage < totalPages - 1;

  // ── Filtered accessors ────────────────────────────────────────────────────

  List<GroupedDishSection> get filteredSections {
    var src = sections;
    return src
        .map((section) {
          var items = section.items;
          if (searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            items = items
                .where((i) =>
                    i.name.toLowerCase().contains(q) ||
                    i.category.toLowerCase().contains(q))
                .toList();
          }
          switch (selectedDishType) {
            case 'veg':
              items = items.where((i) => i.isVeg).toList();
              break;
            case 'non-veg':
              items = items.where((i) => !i.isVeg).toList();
              break;
          }
          return GroupedDishSection(category: section.category, items: items);
        })
        .where((s) => s.items.isNotEmpty)
        .toList();
  }

  List<MenuItem> get filteredCategoryItems {
    var items = categoryItems;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      items = items
          .where((i) =>
              i.name.toLowerCase().contains(q) ||
              i.category.toLowerCase().contains(q))
          .toList();
    }
    switch (selectedDishType) {
      case 'veg':
        items = items.where((i) => i.isVeg).toList();
        break;
      case 'non-veg':
        items = items.where((i) => !i.isVeg).toList();
        break;
    }
    return items;
  }

  AllDishesState copyWith({
    List<DishCategory>? categories,
    bool? areCategoriesLoading,
    List<GroupedDishSection>? sections,
    bool? isAllViewLoading,
    List<MenuItem>? categoryItems,
    bool? isLoading,
    bool? isLoadingMore,
    int? currentPage,
    int? totalPages,
    int? totalCount,
    String? selectedCategoryId,
    bool clearCategoryFilter = false,
    String? selectedDishType,
    String? searchQuery,
    String? error,
    bool clearError = false,
  }) {
    return AllDishesState(
      categories: categories ?? this.categories,
      areCategoriesLoading: areCategoriesLoading ?? this.areCategoriesLoading,
      sections: sections ?? this.sections,
      isAllViewLoading: isAllViewLoading ?? this.isAllViewLoading,
      categoryItems: categoryItems ?? this.categoryItems,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      selectedCategoryId: clearCategoryFilter
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      selectedDishType: selectedDishType ?? this.selectedDishType,
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

  /// Fetch categories → then load "All" grouped view in parallel.
  Future<void> loadMenuItems() async {
    state = state.copyWith(
      areCategoriesLoading: true,
      isAllViewLoading: true,
      clearCategoryFilter: true,
      categoryItems: [],
      sections: [],
      clearError: true,
    );

    // 1. Fetch categories
    final categories = await _repo.getCategories();
    state = state.copyWith(
      categories: categories,
      areCategoriesLoading: false,
    );

    if (categories.isEmpty) {
      state = state.copyWith(isAllViewLoading: false);
      return;
    }

    // 2. Load items for each category in parallel.
    //    Use an indexed buffer so ordering matches the category list even if
    //    futures resolve out of order.
    await _loadAllViewSections(categories);
  }

  /// Re-fetches and rebuilds the "All" grouped view for [categories].
  Future<void> _loadAllViewSections(List<DishCategory> categories) async {
    state = state.copyWith(isAllViewLoading: true, sections: [], clearError: true);

    final buffer = List<GroupedDishSection?>.filled(categories.length, null);
    await Future.wait(
      List.generate(categories.length, (i) async {
        try {
          final result = await _repo.getMenuPage(
            categoryId: categories[i].id,
            pageIndex: 0,
            pageSize: 50,
          );
          if (result.items.isNotEmpty) {
            buffer[i] = GroupedDishSection(
              category: categories[i],
              items: result.items,
            );
          }
        } catch (_) {
          // Skip failing categories — do not block the whole view
        }
      }),
    );

    final sections = buffer.whereType<GroupedDishSection>().toList();
    state = state.copyWith(sections: sections, isAllViewLoading: false);
  }

  // ── Category selection ────────────────────────────────────────────────────

  /// Pass [categoryId] = null to switch back to the "All" grouped view.
  Future<void> selectCategory(String? categoryId) async {
    if (categoryId == null) {
      // Sections are already in state — just switch the view
      state = state.copyWith(
        clearCategoryFilter: true,
        categoryItems: [],
        clearError: true,
      );
      return;
    }

    // Switch to per-category paginated view
    state = state.copyWith(
      selectedCategoryId: categoryId,
      isLoading: true,
      categoryItems: [],
      clearError: true,
      currentPage: 0,
      totalPages: 1,
      totalCount: 0,
    );

    try {
      final result = await _repo.getMenuPage(
        categoryId: categoryId,
        pageIndex: 0,
        pageSize: 20,
      );
      state = state.copyWith(
        categoryItems: result.items,
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        totalCount: result.totalCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Pagination (per-category view only) ───────────────────────────────────

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final nextPage = state.currentPage + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getMenuPage(
        categoryId: state.selectedCategoryId,
        pageIndex: nextPage,
        pageSize: 20,
      );
      state = state.copyWith(
        categoryItems: [...state.categoryItems, ...result.items],
        currentPage: nextPage,
        totalPages: result.totalPages,
        totalCount: result.totalCount,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  void setDishTypeFilter(String dishType) {
    state = state.copyWith(selectedDishType: dishType);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> refresh() => loadMenuItems();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Separate provider for the DeliveryScreen — categories + grouped / paginated.
final allDishesProvider =
    StateNotifierProvider<AllDishesNotifier, AllDishesState>((ref) {
  return AllDishesNotifier(ref.watch(menuRepositoryProvider));
});
