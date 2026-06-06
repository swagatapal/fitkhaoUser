import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/models/delivery_address_model.dart';
import '../../profile/providers/delivery_address_provider.dart';
import 'serviceability_provider.dart';

/// Serviceability status of the currently selected delivery address.
enum AddressServiceStatus { idle, checking, serviceable, notServiceable, error }

/// Drives the checkout's delivery-address selection and its serviceability
/// gate. The selected address resolves the kitchen that fulfils the order, so
/// an order can only be placed against a serviceable address.
class CheckoutDeliveryState {
  final List<DeliveryAddressModel> addresses;
  final bool isLoadingAddresses;
  final String? addressesError;

  final DeliveryAddressModel? selected;
  final AddressServiceStatus status;
  final String? kitchenId;
  final String? zoneName;
  final String? statusMessage;

  const CheckoutDeliveryState({
    this.addresses = const [],
    this.isLoadingAddresses = false,
    this.addressesError,
    this.selected,
    this.status = AddressServiceStatus.idle,
    this.kitchenId,
    this.zoneName,
    this.statusMessage,
  });

  bool get isChecking => status == AddressServiceStatus.checking;
  bool get isServiceable => status == AddressServiceStatus.serviceable;

  /// True only when an order may be placed: a serviceable address with a
  /// resolved kitchen.
  bool get canOrder =>
      selected != null &&
      isServiceable &&
      (kitchenId != null && kitchenId!.isNotEmpty);

  CheckoutDeliveryState copyWith({
    List<DeliveryAddressModel>? addresses,
    bool? isLoadingAddresses,
    String? addressesError,
    bool clearAddressesError = false,
  }) {
    return CheckoutDeliveryState(
      addresses: addresses ?? this.addresses,
      isLoadingAddresses: isLoadingAddresses ?? this.isLoadingAddresses,
      addressesError:
          clearAddressesError ? null : (addressesError ?? this.addressesError),
      selected: selected,
      status: status,
      kitchenId: kitchenId,
      zoneName: zoneName,
      statusMessage: statusMessage,
    );
  }

  /// Builds a new state that keeps the address list but swaps the selection +
  /// serviceability fields. Used for the check lifecycle (nullable resets).
  CheckoutDeliveryState withSelection({
    required DeliveryAddressModel? selected,
    required AddressServiceStatus status,
    String? kitchenId,
    String? zoneName,
    String? statusMessage,
  }) {
    return CheckoutDeliveryState(
      addresses: addresses,
      isLoadingAddresses: isLoadingAddresses,
      addressesError: addressesError,
      selected: selected,
      status: status,
      kitchenId: kitchenId,
      zoneName: zoneName,
      statusMessage: statusMessage,
    );
  }
}

class CheckoutDeliveryNotifier extends StateNotifier<CheckoutDeliveryState> {
  final Ref _ref;

  CheckoutDeliveryNotifier(this._ref) : super(const CheckoutDeliveryState());

  /// Loads addresses once and auto-selects the default (or first) address,
  /// then verifies its serviceability. Safe to call on every screen entry.
  Future<void> initialize() async {
    if (state.addresses.isNotEmpty || state.isLoadingAddresses) return;
    await loadAddresses(autoSelectDefault: true);
  }

  Future<void> loadAddresses({bool autoSelectDefault = false}) async {
    state = state.copyWith(isLoadingAddresses: true, clearAddressesError: true);
    try {
      final repo = _ref.read(deliveryAddressRepositoryProvider);
      final list = await repo.getAddresses();
      list.sort((a, b) {
        if (a.isDefault == b.isDefault) return 0;
        return a.isDefault ? -1 : 1;
      });
      state = state.copyWith(addresses: list, isLoadingAddresses: false);

      if (autoSelectDefault && list.isNotEmpty && state.selected == null) {
        final def = list.firstWhere((a) => a.isDefault, orElse: () => list.first);
        await selectAddress(def);
      }
    } catch (e) {
      debugPrint('[CheckoutDelivery] loadAddresses error: $e');
      state = state.copyWith(
        isLoadingAddresses: false,
        addressesError: 'Failed to load addresses. Please try again.',
      );
    }
  }

  /// Selects [address] and checks its serviceability.
  ///
  /// Returns `true` only when the address is serviceable. The selection is
  /// committed immediately (so the UI reflects the in-flight check), but
  /// [CheckoutDeliveryState.canOrder] stays false unless the check passes.
  Future<bool> selectAddress(DeliveryAddressModel address) async {
    state = state.withSelection(
      selected: address,
      status: AddressServiceStatus.checking,
    );

    try {
      final repo = _ref.read(serviceabilityRepositoryProvider);
      final res = await repo.checkServiceability(
        latitude: address.latitude,
        longitude: address.longitude,
      );

      // Ignore a stale result if the user switched address mid-flight.
      if (state.selected?.id != address.id) return false;

      final data = res.data;
      if (res.success && data != null && data.isServiceable) {
        state = state.withSelection(
          selected: address,
          status: AddressServiceStatus.serviceable,
          kitchenId: data.primaryKitchenId,
          zoneName: data.zoneName,
          statusMessage: res.message,
        );
        return true;
      }

      state = state.withSelection(
        selected: address,
        status: AddressServiceStatus.notServiceable,
        statusMessage: res.message.isNotEmpty
            ? res.message
            : 'We don’t deliver to this address yet.',
      );
      return false;
    } catch (e) {
      debugPrint('[CheckoutDelivery] selectAddress error: $e');
      if (state.selected?.id != address.id) return false;
      state = state.withSelection(
        selected: address,
        status: AddressServiceStatus.error,
        statusMessage: 'Could not verify serviceability. Please try again.',
      );
      return false;
    }
  }

  /// Attempts to switch to [address] from the picker. Unlike [selectAddress],
  /// the selection is committed **only when the address is serviceable** — a
  /// non-serviceable address is rejected and the previous selection restored,
  /// so an unserviceable address can never become the delivery address.
  ///
  /// Returns `true` if the address was accepted (serviceable).
  Future<bool> trySelect(DeliveryAddressModel address) async {
    final prevSelected = state.selected;
    final prevStatus = state.status;
    final prevKitchen = state.kitchenId;
    final prevZone = state.zoneName;
    final prevMsg = state.statusMessage;

    state = state.withSelection(
      selected: address,
      status: AddressServiceStatus.checking,
    );

    try {
      final repo = _ref.read(serviceabilityRepositoryProvider);
      final res = await repo.checkServiceability(
        latitude: address.latitude,
        longitude: address.longitude,
      );

      if (state.selected?.id != address.id) return false; // stale

      final data = res.data;
      if (res.success && data != null && data.isServiceable) {
        state = state.withSelection(
          selected: address,
          status: AddressServiceStatus.serviceable,
          kitchenId: data.primaryKitchenId,
          zoneName: data.zoneName,
          statusMessage: res.message,
        );
        return true;
      }

      // Reject — restore the previous (serviceable) selection.
      state = state.withSelection(
        selected: prevSelected,
        status: prevStatus,
        kitchenId: prevKitchen,
        zoneName: prevZone,
        statusMessage: prevMsg,
      );
      return false;
    } catch (e) {
      debugPrint('[CheckoutDelivery] trySelect error: $e');
      state = state.withSelection(
        selected: prevSelected,
        status: prevStatus,
        kitchenId: prevKitchen,
        zoneName: prevZone,
        statusMessage: prevMsg,
      );
      return false;
    }
  }

  /// Re-runs the serviceability check for the current selection.
  Future<bool> recheck() async {
    final current = state.selected;
    if (current == null) return false;
    return selectAddress(current);
  }
}

final checkoutDeliveryProvider =
    StateNotifierProvider<CheckoutDeliveryNotifier, CheckoutDeliveryState>(
        (ref) => CheckoutDeliveryNotifier(ref));
