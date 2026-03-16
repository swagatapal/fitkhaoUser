import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../repository/app_content_repository.dart';

class AppContentState {
  final String? termsContent;
  final String? privacyContent;
  final bool isLoading;
  final String? error;

  const AppContentState({
    this.termsContent,
    this.privacyContent,
    this.isLoading = false,
    this.error,
  });

  AppContentState copyWith({
    String? termsContent,
    String? privacyContent,
    bool? isLoading,
    String? error,
  }) {
    return AppContentState(
      termsContent: termsContent ?? this.termsContent,
      privacyContent: privacyContent ?? this.privacyContent,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AppContentNotifier extends StateNotifier<AppContentState> {
  final AppContentRepository _repository;

  AppContentNotifier(this._repository) : super(const AppContentState());

  Future<void> loadContent() async {
    debugPrint('[AppContentNotifier] Loading terms and privacy policy...');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repository.getContent('terms'),
        _repository.getContent('privacy_policy'),
      ]);
      state = state.copyWith(
        termsContent: results[0].data?.content.details ?? '',
        privacyContent: results[1].data?.content.details ?? '',
        isLoading: false,
      );
      debugPrint('[AppContentNotifier] Content loaded successfully');
    } catch (e) {
      debugPrint('[AppContentNotifier] Error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load content. Please try again.',
      );
    }
  }
}

final appContentProvider =
    StateNotifierProvider<AppContentNotifier, AppContentState>((ref) {
  final repo = ref.watch(appContentRepositoryProvider);
  return AppContentNotifier(repo);
});
