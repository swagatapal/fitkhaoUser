import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/menu_item.dart';
import '../repository/menu_repository.dart';

/// Provider for MenuRepository
final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return MenuRepository(localStorage: localStorage, apiClient: apiClient);
});

/// State notifier for menu items
class MenuNotifier extends StateNotifier<AsyncValue<List<MenuItem>>> {
  final MenuRepository _menuRepository;

  MenuNotifier(this._menuRepository) : super(const AsyncValue.loading());

  /// Load menu items from API
  Future<void> loadMenuItems({String? mealType}) async {
    state = const AsyncValue.loading();

    try {
      final items = await _menuRepository.getMenuItems(mealType: mealType);
      state = AsyncValue.data(items);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Refresh menu items
  Future<void> refresh({String? mealType}) async {
    await loadMenuItems(mealType: mealType);
  }
}

/// Provider for MenuNotifier
final menuProvider =
    StateNotifierProvider<MenuNotifier, AsyncValue<List<MenuItem>>>((ref) {
  final menuRepository = ref.watch(menuRepositoryProvider);
  return MenuNotifier(menuRepository);
});
