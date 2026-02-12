import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../models/nutrition_summary_model.dart';
import '../models/nutrition_progress_model.dart';
import '../repository/nutrition_repository.dart';

/// State for daily nutrition summary
class NutritionState {
  final NutritionTotals? totals;
  final String? date;
  final bool isLoading;
  final String? error;

  const NutritionState({
    this.totals,
    this.date,
    this.isLoading = false,
    this.error,
  });

  NutritionState copyWith({
    NutritionTotals? totals,
    String? date,
    bool? isLoading,
    String? error,
  }) {
    return NutritionState(
      totals: totals ?? this.totals,
      date: date ?? this.date,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// State for daily nutrition progress
class NutritionProgressState {
  final NutritionProgressData? progressData;
  final bool isLoading;
  final String? error;

  const NutritionProgressState({
    this.progressData,
    this.isLoading = false,
    this.error,
  });

  NutritionProgressState copyWith({
    NutritionProgressData? progressData,
    bool? isLoading,
    String? error,
  }) {
    return NutritionProgressState(
      progressData: progressData ?? this.progressData,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for nutrition state
class NutritionNotifier extends StateNotifier<NutritionState> {
  final NutritionRepository _nutritionRepository;

  NutritionNotifier(this._nutritionRepository)
      : super(const NutritionState());

  /// Get daily nutrition summary
  Future<void> getDailyNutritionSummary({String? date}) async {
    // Use tomorrow's date (current date + 1 day) if not provided
    final targetDate = DateFormat('yyyy-MM-dd').format(
      DateTime.now().add(const Duration(days: 1)),
    );

    debugPrint('[NutritionNotifier] Fetching nutrition summary for: $targetDate');

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _nutritionRepository.getDailyNutritionSummary(
        date: targetDate,
      );

      if (response.success && response.data != null) {
        state = NutritionState(
          totals: response.data!.totals,
          date: targetDate,
          isLoading: false,
          error: null,
        );
        debugPrint('[NutritionNotifier] Nutrition summary loaded: ${response.data!.totals.protein}g protein');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty
              ? response.message
              : 'Failed to load nutrition summary',
        );
      }
    } catch (e) {
      debugPrint('[NutritionNotifier] Error loading nutrition summary: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load nutrition summary',
      );
    }
  }

  /// Reset state
  void reset() {
    state = const NutritionState();
  }
}

/// Notifier for nutrition progress state
class NutritionProgressNotifier extends StateNotifier<NutritionProgressState> {
  final NutritionRepository _nutritionRepository;

  NutritionProgressNotifier(this._nutritionRepository)
      : super(const NutritionProgressState());

  /// Get daily nutrition progress
  Future<void> getDailyNutritionProgress({String? date}) async {
    // Use current date if not provided
    final targetDate = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    debugPrint('[NutritionProgressNotifier] Fetching nutrition progress for: $targetDate');

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _nutritionRepository.getDailyNutritionProgress(
        date: targetDate,
      );

      if (response.success && response.data != null) {
        state = NutritionProgressState(
          progressData: response.data,
          isLoading: false,
          error: null,
        );
        debugPrint('[NutritionProgressNotifier] Progress loaded successfully');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty
              ? response.message
              : 'Failed to load nutrition progress',
        );
      }
    } catch (e) {
      debugPrint('[NutritionProgressNotifier] Error loading nutrition progress: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load nutrition progress',
      );
    }
  }

  /// Reset state
  void reset() {
    state = const NutritionProgressState();
  }
}

/// Repository provider
final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return NutritionRepository(
    apiClient: apiClient,
    localStorage: localStorage,
  );
});

/// Provider for nutrition state
final nutritionProvider =
    StateNotifierProvider<NutritionNotifier, NutritionState>((ref) {
  final nutritionRepo = ref.watch(nutritionRepositoryProvider);
  return NutritionNotifier(nutritionRepo);
});

/// Provider for nutrition progress state
final nutritionProgressProvider =
    StateNotifierProvider<NutritionProgressNotifier, NutritionProgressState>((ref) {
  final nutritionRepo = ref.watch(nutritionRepositoryProvider);
  return NutritionProgressNotifier(nutritionRepo);
});
