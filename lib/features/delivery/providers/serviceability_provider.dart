import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/serviceability_model.dart';
import '../repository/serviceability_repository.dart';

/// State for serviceability check
class ServiceabilityState {
  final bool? isServiceable;
  final String? message;
  final bool isLoading;
  final String? error;

  const ServiceabilityState({
    this.isServiceable,
    this.message,
    this.isLoading = false,
    this.error,
  });

  ServiceabilityState copyWith({
    bool? isServiceable,
    String? message,
    bool? isLoading,
    String? error,
  }) {
    return ServiceabilityState(
      isServiceable: isServiceable ?? this.isServiceable,
      message: message ?? this.message,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for serviceability state
class ServiceabilityNotifier extends StateNotifier<ServiceabilityState> {
  final ServiceabilityRepository _serviceabilityRepository;

  ServiceabilityNotifier(this._serviceabilityRepository)
      : super(const ServiceabilityState());

  /// Check serviceability
  Future<void> checkServiceability({
    required double latitude,
    required double longitude,
  }) async {
    debugPrint('[ServiceabilityNotifier] Checking serviceability...');

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _serviceabilityRepository.checkServiceability(
        latitude: latitude,
        longitude: longitude,
      );

      if (response.success && response.data != null) {
        state = ServiceabilityState(
          isServiceable: response.data!.isServiceable,
          message: response.message,
          isLoading: false,
          error: null,
        );
        debugPrint('[ServiceabilityNotifier] Serviceability check successful: ${response.data!.isServiceable}');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty
              ? response.message
              : 'Failed to check serviceability',
        );
      }
    } catch (e) {
      debugPrint('[ServiceabilityNotifier] Error checking serviceability: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to check serviceability',
      );
    }
  }

  /// Reset state
  void reset() {
    state = const ServiceabilityState();
  }
}

/// Repository provider
final serviceabilityRepositoryProvider =
    Provider<ServiceabilityRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return ServiceabilityRepository(
    apiClient: apiClient,
    localStorage: localStorage,
  );
});

/// Provider for serviceability state
final serviceabilityProvider =
    StateNotifierProvider<ServiceabilityNotifier, ServiceabilityState>((ref) {
  final serviceabilityRepo = ref.watch(serviceabilityRepositoryProvider);
  return ServiceabilityNotifier(serviceabilityRepo);
});
