import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/kitchen_model.dart';
import '../repository/kitchen_repository.dart';

/// State for kitchen discovery + selection + open/close status.
class KitchenState {
  final List<KitchenModel> kitchens;
  final KitchenModel? selectedKitchen;
  final bool isLoading;
  final String? error;

  /// null  = open status not yet resolved
  /// true  = kitchen is open
  /// false = kitchen is closed
  final bool? isKitchenOpen;
  final String? kitchenClosedReason;

  const KitchenState({
    this.kitchens = const [],
    this.selectedKitchen,
    this.isLoading = false,
    this.error,
    this.isKitchenOpen,
    this.kitchenClosedReason,
  });

  String? get selectedKitchenId => selectedKitchen?.id;

  KitchenState copyWith({
    List<KitchenModel>? kitchens,
    KitchenModel? selectedKitchen,
    bool? isLoading,
    String? error,
    bool? isKitchenOpen,
    String? kitchenClosedReason,
    bool clearError = false,
  }) {
    return KitchenState(
      kitchens: kitchens ?? this.kitchens,
      selectedKitchen: selectedKitchen ?? this.selectedKitchen,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isKitchenOpen: isKitchenOpen ?? this.isKitchenOpen,
      kitchenClosedReason: kitchenClosedReason,
    );
  }
}

class KitchenNotifier extends StateNotifier<KitchenState> {
  final KitchenRepository _repository;

  KitchenNotifier(this._repository) : super(const KitchenState());

  /// Loads the active kitchen list, preserves the current selection if it is
  /// still present (otherwise defaults to the first kitchen), then resolves the
  /// selected kitchen's open status.
  Future<void> loadKitchens() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _repository.getActiveKitchens();

      if (!response.success || response.kitchens.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty
              ? response.message
              : 'No kitchens available right now',
        );
        return;
      }

      final kitchens = response.kitchens;

      // Keep the current selection if it still exists; else default to first.
      final current = state.selectedKitchen;
      final selected = (current != null &&
              kitchens.any((k) => k.id == current.id))
          ? kitchens.firstWhere((k) => k.id == current.id)
          : kitchens.first;

      state = KitchenState(
        kitchens: kitchens,
        selectedKitchen: selected,
        isLoading: false,
        // Seed open status from the list payload; the dedicated call refines it.
        isKitchenOpen: selected.isOpen,
      );

      await _refreshOpenStatus(selected);
    } catch (e) {
      debugPrint('[KitchenNotifier] loadKitchens error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load kitchens',
      );
    }
  }

  /// Switches the active kitchen and refreshes its open status.
  Future<void> selectKitchen(KitchenModel kitchen) async {
    if (kitchen.id == state.selectedKitchen?.id) return;
    state = state.copyWith(
      selectedKitchen: kitchen,
      isKitchenOpen: kitchen.isOpen,
    );
    await _refreshOpenStatus(kitchen);
  }

  /// Resolves the authoritative open status for [kitchen] via the open-status
  /// endpoint. Fail-open: a null response keeps the list-reported flag.
  Future<void> _refreshOpenStatus(KitchenModel kitchen) async {
    final status = await _repository.getKitchenOpenStatus(kitchen.id);
    // Guard against a stale response if the selection changed mid-flight.
    if (state.selectedKitchen?.id != kitchen.id) return;

    state = state.copyWith(
      isKitchenOpen: status?.isOpen ?? kitchen.isOpen,
      kitchenClosedReason: status?.reason,
    );
  }

  void reset() => state = const KitchenState();
}

final kitchenRepositoryProvider = Provider<KitchenRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return KitchenRepository(apiClient: apiClient, localStorage: localStorage);
});

final kitchenProvider =
    StateNotifierProvider<KitchenNotifier, KitchenState>((ref) {
  return KitchenNotifier(ref.watch(kitchenRepositoryProvider));
});
