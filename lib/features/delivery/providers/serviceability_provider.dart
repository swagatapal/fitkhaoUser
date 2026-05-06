import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../repository/serviceability_repository.dart';

/// State for serviceability check
class ServiceabilityState {
  final bool? isServiceable;
  final String? kitchenId;
  final String? message;
  final bool isLoading;
  final String? error;

  const ServiceabilityState({
    this.isServiceable,
    this.kitchenId,
    this.message,
    this.isLoading = false,
    this.error,
  });

  ServiceabilityState copyWith({
    bool? isServiceable,
    String? kitchenId,
    String? message,
    bool? isLoading,
    String? error,
  }) {
    return ServiceabilityState(
      isServiceable: isServiceable ?? this.isServiceable,
      kitchenId: kitchenId ?? this.kitchenId,
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

  /// Check serviceability and populate kitchenId
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
        final data = response.data!;
        final kitchenId = data.primaryKitchenId;
        state = ServiceabilityState(
          isServiceable: data.isServiceable,
          kitchenId: kitchenId,
          message: response.message,
          isLoading: false,
          error: null,
        );
        debugPrint(
          '[ServiceabilityNotifier] Serviceable: ${data.isServiceable}, '
          'zone: ${data.zoneName}, kitchenId: $kitchenId',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty
              ? response.message
              : 'Failed to check serviceability',
        );
      }
    } catch (e) {
      debugPrint('[ServiceabilityNotifier] Error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to check serviceability',
      );
    }
  }

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
