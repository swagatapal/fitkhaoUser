// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:intl/intl.dart';
// import '../../../core/providers/providers.dart';
// import '../models/nutrition_progress_model.dart';
// import '../repository/nutrition_repository.dart';
//
// /// State for daily nutrition progress
// class NutritionProgressState {
//   final NutritionProgressData? progressData;
//   final bool isLoading;
//   final String? error;
//
//   const NutritionProgressState({
//     this.progressData,
//     this.isLoading = false,
//     this.error,
//   });
//
//   NutritionProgressState copyWith({
//     NutritionProgressData? progressData,
//     bool? isLoading,
//     String? error,
//   }) {
//     return NutritionProgressState(
//       progressData: progressData ?? this.progressData,
//       isLoading: isLoading ?? this.isLoading,
//       error: error,
//     );
//   }
// }
//
// /// Notifier for nutrition progress state
// class NutritionProgressNotifier extends StateNotifier<NutritionProgressState> {
//   final NutritionRepository _nutritionRepository;
//
//   NutritionProgressNotifier(this._nutritionRepository)
//       : super(const NutritionProgressState());
//
//   /// Get daily nutrition progress
//   Future<void> getDailyNutritionProgress({String? date}) async {
//     // Use current date if not provided
//     final targetDate = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
//
//     debugPrint('[NutritionProgressNotifier] Fetching nutrition progress for: $targetDate');
//
//     state = state.copyWith(isLoading: true, error: null);
//
//     try {
//       final response = await _nutritionRepository.getDailyNutritionProgress(
//         date: targetDate,
//       );
//
//       if (response.success && response.data != null) {
//         state = NutritionProgressState(
//           progressData: response.data,
//           isLoading: false,
//           error: null,
//         );
//         debugPrint('[NutritionProgressNotifier] Progress loaded successfully');
//       } else {
//         state = state.copyWith(
//           isLoading: false,
//           error: response.message.isNotEmpty
//               ? response.message
//               : 'Failed to load nutrition progress',
//         );
//       }
//     } catch (e) {
//       debugPrint('[NutritionProgressNotifier] Error loading nutrition progress: $e');
//       state = state.copyWith(
//         isLoading: false,
//         error: 'Failed to load nutrition progress',
//       );
//     }
//   }
//
//   /// Reset state
//   void reset() {
//     state = const NutritionProgressState();
//   }
// }
//
// /// Repository provider
// final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
//   final localStorage = ref.watch(localStorageProvider).value;
//   final apiClient = ref.watch(apiClientProvider);
//
//   if (localStorage == null) {
//     throw Exception('LocalStorage not initialized');
//   }
//
//   return NutritionRepository(
//     apiClient: apiClient,
//     localStorage: localStorage,
//   );
// });
//
// /// Provider for nutrition progress state
// final nutritionProgressProvider =
//     StateNotifierProvider<NutritionProgressNotifier, NutritionProgressState>((ref) {
//   final nutritionRepo = ref.watch(nutritionRepositoryProvider);
//   return NutritionProgressNotifier(nutritionRepo);
// });
