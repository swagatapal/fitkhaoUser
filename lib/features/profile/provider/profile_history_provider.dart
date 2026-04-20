import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/profile_history_model.dart';

class ProfileHistoryState {
  final List<ProfileHistory> histories;
  final bool isLoading;
  final String? errorMessage;

  const ProfileHistoryState({
    this.histories = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ProfileHistoryState copyWith({
    List<ProfileHistory>? histories,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileHistoryState(
      histories: histories ?? this.histories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ProfileHistoryNotifier extends StateNotifier<ProfileHistoryState> {
  final Ref _ref;

  ProfileHistoryNotifier(this._ref) : super(const ProfileHistoryState());

  Future<void> loadHistory(String userId) async {
    if (userId.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final response = await authRepo.getProfileHistory(userId);

      final data = response['data'] as Map<String, dynamic>?;
      final rawList = data?['histories'] as List<dynamic>? ?? [];

      final histories = rawList
          .whereType<Map<String, dynamic>>()
          .map(ProfileHistory.fromJson)
          .toList();

      // Sort newest first
      histories.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(histories: histories, isLoading: false);
      debugPrint('[ProfileHistoryNotifier] Loaded ${histories.length} entries');
    } catch (e) {
      debugPrint('[ProfileHistoryNotifier] Error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final profileHistoryProvider =
    StateNotifierProvider<ProfileHistoryNotifier, ProfileHistoryState>((ref) {
  return ProfileHistoryNotifier(ref);
});
