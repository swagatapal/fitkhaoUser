import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/models/delivery_address_model.dart';

/// Single source of truth for the delivery address the user is currently
/// ordering against.
///
/// Both the delivery screen (header / area gate) and the checkout screen read
/// from and write to this provider, so a selection made on one screen is always
/// reflected on the other. `null` means "no address chosen yet" — callers then
/// fall back to auto-resolution (default → first → device GPS).
class SelectedDeliveryAddressNotifier
    extends StateNotifier<DeliveryAddressModel?> {
  SelectedDeliveryAddressNotifier() : super(null);

  /// Commits an explicit user pick. De-duplicated: re-selecting the same
  /// address (same id + coordinates) is a no-op so dependent listeners don't
  /// fire — and re-run serviceability — for nothing.
  void select(DeliveryAddressModel address) => _setIfChanged(address);

  /// Resolves an initial selection from [list] when the user hasn't explicitly
  /// chosen one — or when their prior choice was deleted.
  ///
  /// * Empty list                  → clears the selection (caller uses GPS).
  /// * Prior selection still exists → keeps it (refreshed to the latest model).
  /// * Otherwise                    → the default address, else the first.
  ///
  /// Returns the resolved selection (or `null` when there are no addresses).
  DeliveryAddressModel? resolveFrom(List<DeliveryAddressModel> list) {
    if (list.isEmpty) {
      if (state != null) state = null;
      return null;
    }

    final current = state;
    if (current != null) {
      final matches = list.where((a) => a.id == current.id);
      if (matches.isNotEmpty) {
        _setIfChanged(matches.first);
        return state;
      }
    }

    final def = list.firstWhere((a) => a.isDefault, orElse: () => list.first);
    _setIfChanged(def);
    return state;
  }

  void clear() {
    if (state != null) state = null;
  }

  void _setIfChanged(DeliveryAddressModel address) {
    final s = state;
    if (s != null &&
        s.id == address.id &&
        s.latitude == address.latitude &&
        s.longitude == address.longitude) {
      return;
    }
    state = address;
  }
}

final selectedDeliveryAddressProvider =
    StateNotifierProvider<SelectedDeliveryAddressNotifier,
        DeliveryAddressModel?>((ref) => SelectedDeliveryAddressNotifier());
