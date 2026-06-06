import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/delivery_address_model.dart';
import '../repository/delivery_address_repository.dart';

class AddressState {
  final List<DeliveryAddressModel> addresses;
  final bool isLoading;
  final String? error;

  const AddressState({
    this.addresses = const [],
    this.isLoading = false,
    this.error,
  });

  bool get isEmpty => addresses.isEmpty;

  AddressState copyWith({
    List<DeliveryAddressModel>? addresses,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AddressState(
      addresses: addresses ?? this.addresses,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AddressNotifier extends StateNotifier<AddressState> {
  final DeliveryAddressRepository _repository;

  AddressNotifier(this._repository) : super(const AddressState());

  /// Fetches the address list. [silent] keeps the existing list visible while
  /// refreshing (used after a mutation) instead of flashing the loader.
  Future<void> loadAddresses({bool silent = false}) async {
    state = state.copyWith(isLoading: !silent, clearError: true);
    try {
      final addresses = await _repository.getAddresses();
      // Default address first, then the rest as returned by the server.
      addresses.sort((a, b) {
        if (a.isDefault == b.isDefault) return 0;
        return a.isDefault ? -1 : 1;
      });
      state = state.copyWith(addresses: addresses, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load addresses. Please try again.',
      );
    }
  }

  Future<AddressMutationResult> addAddress(
      DeliveryAddressModel address) async {
    final result = await _repository.addAddress(address);
    if (result.success) await loadAddresses(silent: true);
    return result;
  }

  Future<AddressMutationResult> updateAddress(
      String id, DeliveryAddressModel address) async {
    final result = await _repository.updateAddress(id, address);
    if (result.success) await loadAddresses(silent: true);
    return result;
  }

  Future<AddressMutationResult> deleteAddress(String id) async {
    final result = await _repository.deleteAddress(id);
    if (result.success) await loadAddresses(silent: true);
    return result;
  }

  /// Promotes an existing address to default by re-saving it with the flag set.
  Future<AddressMutationResult> setDefault(DeliveryAddressModel address) {
    return updateAddress(address.id, address.copyWith(isDefault: true));
  }
}

final deliveryAddressRepositoryProvider =
    Provider<DeliveryAddressRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);
  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }
  return DeliveryAddressRepository(
      apiClient: apiClient, localStorage: localStorage);
});

final addressProvider =
    StateNotifierProvider<AddressNotifier, AddressState>((ref) {
  return AddressNotifier(ref.watch(deliveryAddressRepositoryProvider));
});
