import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/exercise_model.dart';

class ExerciseState {
  final List<ExerciseGroup> exercises;
  final bool isLoading;
  final String? errorMessage;

  const ExerciseState({
    this.exercises = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ExerciseState copyWith({
    List<ExerciseGroup>? exercises,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ExerciseState(
      exercises: exercises ?? this.exercises,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ExerciseNotifier extends StateNotifier<ExerciseState> {
  final Ref _ref;

  ExerciseNotifier(this._ref) : super(const ExerciseState());

  Future<void> loadExercises() async {
    if (state.exercises.isNotEmpty) return; // Already loaded

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final response = await authRepo.getExercises();

      final data = response['data'] as Map<String, dynamic>?;
      final exercisesList = data?['exercises'] as List<dynamic>?;

      if (exercisesList != null) {
        final exercises = exercisesList
            .map((e) => ExerciseGroup.fromJson(e as Map<String, dynamic>))
            .where((e) => e.isActive)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        state = state.copyWith(
          exercises: exercises,
          isLoading: false,
        );
        debugPrint(
            '[ExerciseNotifier] Loaded ${exercises.length} exercise groups');
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No exercises found',
        );
      }
    } catch (e) {
      debugPrint('[ExerciseNotifier] Error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final exerciseProvider =
    StateNotifierProvider<ExerciseNotifier, ExerciseState>((ref) {
  return ExerciseNotifier(ref);
});
