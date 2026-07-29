import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../repository/serviceability_repository.dart';

/// State for serviceability + kitchen open/close check
class ServiceabilityState {
  final bool? isServiceable;
  final String? kitchenId;
  final String? message;
  final bool isLoading;
  final String? error;

  /// null  = kitchen status not yet fetched
  /// true  = kitchen is open
  /// false = kitchen is closed
  final bool? isKitchenOpen;
  final String? kitchenClosedReason;

  const ServiceabilityState({
    this.isServiceable,
    this.kitchenId,
    this.message,
    this.isLoading = false,
    this.error,
    this.isKitchenOpen,
    this.kitchenClosedReason,
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
      // preserve kitchen status fields unchanged
      isKitchenOpen: isKitchenOpen,
      kitchenClosedReason: kitchenClosedReason,
    );
  }
}

/// Notifier for serviceability state
class ServiceabilityNotifier extends StateNotifier<ServiceabilityState> {
  final ServiceabilityRepository _serviceabilityRepository;

  ServiceabilityNotifier(this._serviceabilityRepository)
      : super(const ServiceabilityState());

  /// Check serviceability then — if serviceable — also check kitchen open status.
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

        // Base serviceability result
        state = ServiceabilityState(
          isServiceable: data.isServiceable,
          kitchenId: kitchenId,
          message: response.message,
          isLoading: false,
          error: null,
          isKitchenOpen: null,
          kitchenClosedReason: null,
        );

        debugPrint(
          '[ServiceabilityNotifier] Serviceable: ${data.isServiceable}, '
          'zone: ${data.zoneName}, kitchenId: $kitchenId',
        );

        // Only check kitchen status when location is serviceable and we have a kitchen ID
        if (data.isServiceable && kitchenId != null && kitchenId.isNotEmpty) {
          final kitchenStatus =
              await _serviceabilityRepository.checkKitchenOpenStatus(kitchenId);

          // null response → fail-open (treat kitchen as open)
          state = ServiceabilityState(
            isServiceable: data.isServiceable,
            kitchenId: kitchenId,
            message: response.message,
            isLoading: false,
            error: null,
            isKitchenOpen: kitchenStatus?.isOpen ?? true,
            kitchenClosedReason: kitchenStatus?.reason,
          );

          debugPrint(
            '[ServiceabilityNotifier] Kitchen isOpen: ${kitchenStatus?.isOpen}, '
            'reason: ${kitchenStatus?.reason}',
          );
        }
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

// ─── Per-coordinate serviceability (address selection) ───────────────────────

/// Immutable lat/lng key for a serviceability lookup. Value equality lets the
/// [addressServiceabilityProvider] family cache one result per coordinate, so
/// showing several addresses at once each resolves independently and re-renders
/// never refetch.
class ServiceabilityQuery {
  final double latitude;
  final double longitude;

  const ServiceabilityQuery(this.latitude, this.longitude);

  /// A coordinate is checkable only once a real point has been pinned.
  bool get hasCoordinates => latitude != 0.0 || longitude != 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceabilityQuery &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Whether a single coordinate falls inside a serviceable delivery zone.
///
/// Reuses [ServiceabilityRepository.checkServiceability]; unlike the order-flow
/// [serviceabilityProvider] notifier, this `family` resolves each address on its
/// own so the delivery wizard can gate address selection per row.
final addressServiceabilityProvider = FutureProvider.autoDispose
    .family<bool, ServiceabilityQuery>((ref, query) async {
  if (!query.hasCoordinates) return false;
  final repo = ref.watch(serviceabilityRepositoryProvider);
  final res = await repo.checkServiceability(
    latitude: query.latitude,
    longitude: query.longitude,
  );
  return res.success && (res.data?.isServiceable ?? false);
});
