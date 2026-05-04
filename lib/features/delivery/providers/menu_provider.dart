import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/menu_item.dart';
import '../repository/menu_repository.dart';

export '../repository/menu_repository.dart' show MenuPageResult;

/// Provider for MenuRepository
final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return MenuRepository(localStorage: localStorage, apiClient: apiClient);
});

// ─── MenuNotifier (used by MenuListScreen) ───────────────────────────────────

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

  Future<void> refresh({String? mealType}) async => loadMenuItems(mealType: mealType);
}

final menuProvider =
    StateNotifierProvider<MenuNotifier, AsyncValue<List<MenuItem>>>((ref) {
  return MenuNotifier(ref.watch(menuRepositoryProvider));
});

// ─── AllDishesState (used by DeliveryScreen) ─────────────────────────────────

class DishCategory {
  final String id;
  final String name;
  const DishCategory({required this.id, required this.name});
}

class AllDishesState {
  final List<MenuItem> allItems;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final String? selectedCategoryId;
  final String selectedDishType; // 'all' | 'veg' | 'non-veg'

  const AllDishesState({
    this.allItems = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 0,
    this.totalPages = 1,
    this.totalCount = 0,
    this.selectedCategoryId,
    this.selectedDishType = 'all',
  });

  bool get canLoadMore =>
      !isLoading && !isLoadingMore && currentPage < totalPages;

  List<MenuItem> get filteredItems {
    var items = allItems;
    if (selectedCategoryId != null && selectedCategoryId!.isNotEmpty) {
      items = items.where((i) => i.categoryId == selectedCategoryId).toList();
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

  List<DishCategory> get categories {
    final seen = <String>{};
    final result = <DishCategory>[];
    for (final item in allItems) {
      if (item.categoryId.isNotEmpty && seen.add(item.categoryId)) {
        result.add(DishCategory(id: item.categoryId, name: item.categoryName));
      }
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  AllDishesState copyWith({
    List<MenuItem>? allItems,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    int? currentPage,
    int? totalPages,
    int? totalCount,
    String? selectedCategoryId,
    bool clearCategoryFilter = false,
    String? selectedDishType,
  }) {
    return AllDishesState(
      allItems: allItems ?? this.allItems,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      selectedCategoryId: clearCategoryFilter
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      selectedDishType: selectedDishType ?? this.selectedDishType,
    );
  }
}

class AllDishesNotifier extends StateNotifier<AllDishesState> {
  final MenuRepository _repo;

  AllDishesNotifier(this._repo) : super(const AllDishesState());

  Future<void> loadMenuItems({String? mealType}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.getMenuPage(mealType: mealType, page: 1);
      state = AllDishesState(
        allItems: result.items,
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        totalCount: result.totalCount,
        selectedCategoryId: state.selectedCategoryId,
        selectedDishType: state.selectedDishType,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore({String? mealType}) async {
    if (!state.canLoadMore) return;
    final nextPage = state.currentPage + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getMenuPage(
        mealType: mealType,
        page: nextPage,
      );
      state = state.copyWith(
        allItems: [...state.allItems, ...result.items],
        currentPage: nextPage,
        totalPages: result.totalPages,
        totalCount: result.totalCount,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void setCategoryFilter(String? categoryId) {
    state = categoryId == null
        ? state.copyWith(clearCategoryFilter: true)
        : state.copyWith(selectedCategoryId: categoryId);
  }

  void setDishTypeFilter(String dishType) {
    state = state.copyWith(selectedDishType: dishType);
  }

  Future<void> refresh() => loadMenuItems();
}

/// Separate provider for the DeliveryScreen — supports filtering + pagination.
final allDishesProvider =
    StateNotifierProvider<AllDishesNotifier, AllDishesState>((ref) {
  return AllDishesNotifier(ref.watch(menuRepositoryProvider));
});
