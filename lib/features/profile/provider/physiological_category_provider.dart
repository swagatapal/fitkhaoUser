import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/physiological_category_model.dart';

class PhysiologicalCategoryState {
  final List<PhysiologicalCategory> categories;
  final bool isLoading;
  final String? errorMessage;

  const PhysiologicalCategoryState({
    this.categories = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  PhysiologicalCategoryState copyWith({
    List<PhysiologicalCategory>? categories,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PhysiologicalCategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PhysiologicalCategoryNotifier
    extends StateNotifier<PhysiologicalCategoryState> {
  final Ref _ref;

  PhysiologicalCategoryNotifier(this._ref)
      : super(const PhysiologicalCategoryState());

  Future<void> loadCategories() async {
    if (state.categories.isNotEmpty) return; // Already loaded

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final response = await authRepo.getPhysiologicalCategories();

      final data = response['data'] as Map<String, dynamic>?;
      final categoriesList =
          data?['physiologicalCategories'] as List<dynamic>?;

      if (categoriesList != null) {
        final categories = categoriesList
            .map((e) =>
                PhysiologicalCategory.fromJson(e as Map<String, dynamic>))
            .toList();

        state = state.copyWith(
          categories: categories,
          isLoading: false,
        );
        debugPrint(
            '[PhysiologicalCategoryNotifier] Loaded ${categories.length} categories');
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No categories found',
        );
      }
    } catch (e) {
      debugPrint('[PhysiologicalCategoryNotifier] Error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final physiologicalCategoryProvider = StateNotifierProvider<
    PhysiologicalCategoryNotifier, PhysiologicalCategoryState>((ref) {
  return PhysiologicalCategoryNotifier(ref);
});
