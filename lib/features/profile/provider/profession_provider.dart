import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/profession_model.dart';

class ProfessionState {
  final List<ProfessionGroup> professions;
  final bool isLoading;
  final String? errorMessage;

  const ProfessionState({
    this.professions = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ProfessionState copyWith({
    List<ProfessionGroup>? professions,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfessionState(
      professions: professions ?? this.professions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ProfessionNotifier extends StateNotifier<ProfessionState> {
  final Ref _ref;

  ProfessionNotifier(this._ref) : super(const ProfessionState());

  Future<void> loadProfessions() async {
    if (state.professions.isNotEmpty) return; // Already loaded

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final response = await authRepo.getProfessions();

      final data = response['data'] as Map<String, dynamic>?;
      final professionsList = data?['professions'] as List<dynamic>?;

      if (professionsList != null) {
        final professions = professionsList
            .map((e) => ProfessionGroup.fromJson(e as Map<String, dynamic>))
            .where((p) => p.isActive)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        state = state.copyWith(
          professions: professions,
          isLoading: false,
        );
        debugPrint(
            '[ProfessionNotifier] Loaded ${professions.length} profession groups');
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No professions found',
        );
      }
    } catch (e) {
      debugPrint('[ProfessionNotifier] Error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final professionProvider =
    StateNotifierProvider<ProfessionNotifier, ProfessionState>((ref) {
  return ProfessionNotifier(ref);
});
