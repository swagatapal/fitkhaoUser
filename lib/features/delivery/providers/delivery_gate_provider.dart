import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/firebase_notification_service.dart';
import '../../profile/models/delivery_address_model.dart';
import 'selected_address_provider.dart';
import 'serviceability_provider.dart';

/// Whether the delivery area (resolved from the default/first address, or the
/// device's current location) is serviceable.
///
/// * [unknown]        — not yet checked, check failed, or location unavailable.
///                      Treated as NON-blocking (food stays enabled).
/// * [checking]       — a check is in flight.
/// * [serviceable]    — orders allowed.
/// * [notServiceable] — food shown greyed-out & disabled.
enum AreaServiceability { unknown, checking, serviceable, notServiceable }

/// Result of resolving the device location (only relevant when there is no
/// saved address to check against).
enum LocationAccess { unknown, granted, denied, serviceDisabled }

/// Aggregated entry-gate state for the delivery screen: serviceability +
/// location-permission + notification-permission, evaluated once on entry.
class DeliveryGateState {
  final AreaServiceability area;
  final LocationAccess location;
  final String? zoneName;

  /// Source the serviceability check was run against ("Home", "Current
  /// location"…) — purely informational.
  final String? sourceLabel;

  /// Human-readable address the availability was resolved against. For a saved
  /// address it is its formatted address; for the device location it is the
  /// reverse-geocoded address. Shown in the header.
  final String? resolvedAddress;

  /// Coordinate the availability was resolved against (used by the map sheet).
  final double? latitude;
  final double? longitude;

  final bool notificationsEnabled;
  final bool notificationChecked;

  /// True when the user has explicitly toggled notifications OFF from the
  /// drawer switch. Decoupled from the OS permission so the toggle persists
  /// independently of what the system reports.
  final bool notifUserDisabled;

  final bool isEvaluating;

  // User-dismissed info banners (per app session).
  final bool locationInfoDismissed;
  final bool notificationInfoDismissed;

  const DeliveryGateState({
    this.area = AreaServiceability.unknown,
    this.location = LocationAccess.unknown,
    this.zoneName,
    this.sourceLabel,
    this.resolvedAddress,
    this.latitude,
    this.longitude,
    this.notificationsEnabled = true,
    this.notificationChecked = false,
    this.notifUserDisabled = false,
    this.isEvaluating = false,
    this.locationInfoDismissed = false,
    this.notificationInfoDismissed = false,
  });

  /// Only an explicit "not serviceable" blocks ordering. Unknown / in-flight /
  /// location-denied all keep food enabled (per product requirement).
  bool get areaBlocksOrdering => area == AreaServiceability.notServiceable;

  /// The value the drawer switch reflects: OS permission AND no explicit
  /// user-disable. Loading state (notificationChecked == false) returns false.
  bool get effectiveNotifEnabled =>
      notificationChecked && notificationsEnabled && !notifUserDisabled;

  bool get showLocationInfo =>
      !locationInfoDismissed &&
      (location == LocationAccess.denied ||
          location == LocationAccess.serviceDisabled);

  /// Show the nudge banner only when the OS has denied permission AND the user
  /// hasn't explicitly disabled it themselves from the drawer toggle.
  bool get showNotificationInfo =>
      notificationChecked &&
      !notificationsEnabled &&
      !notifUserDisabled &&
      !notificationInfoDismissed;

  DeliveryGateState copyWith({
    AreaServiceability? area,
    LocationAccess? location,
    String? zoneName,
    String? sourceLabel,
    String? resolvedAddress,
    double? latitude,
    double? longitude,
    bool? notificationsEnabled,
    bool? notificationChecked,
    bool? notifUserDisabled,
    bool? isEvaluating,
    bool? locationInfoDismissed,
    bool? notificationInfoDismissed,
  }) {
    return DeliveryGateState(
      area: area ?? this.area,
      location: location ?? this.location,
      zoneName: zoneName ?? this.zoneName,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      resolvedAddress: resolvedAddress ?? this.resolvedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,

      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationChecked: notificationChecked ?? this.notificationChecked,
      notifUserDisabled: notifUserDisabled ?? this.notifUserDisabled,
      isEvaluating: isEvaluating ?? this.isEvaluating,
      locationInfoDismissed:
          locationInfoDismissed ?? this.locationInfoDismissed,
      notificationInfoDismissed:
          notificationInfoDismissed ?? this.notificationInfoDismissed,
    );
  }
}

class DeliveryGateNotifier extends StateNotifier<DeliveryGateState> {
  final Ref _ref;
  bool _running = false;
  bool _pending = false;

  DeliveryGateNotifier(this._ref) : super(const DeliveryGateState());

  /// Full entry evaluation:
  ///   1. Resolve a coordinate — selected address → current device location.
  ///   2. Check serviceability for that coordinate (skipped if the location is
  ///      unavailable, in which case food stays enabled with an info prompt).
  ///   3. Check whether notifications are enabled (for the soft prompt).
  ///
  /// Coalesced: if called while a pass is already running, the in-flight pass
  /// is allowed to finish and then re-runs once. This guarantees the final pass
  /// reads the latest [selectedDeliveryAddressProvider] — without it, a rapid
  /// "address list changed → selection changed" sequence could finish on the
  /// stale address and never refresh.
  Future<void> evaluate() async {
    if (_running) {
      _pending = true;
      return;
    }
    _running = true;
    try {
      do {
        _pending = false;
        await _evaluateOnce();
      } while (_pending);
    } finally {
      _running = false;
    }
  }

  Future<void> _evaluateOnce() async {
    state = state.copyWith(
      isEvaluating: true,
      area: AreaServiceability.checking,
    );

    try {
      // 1 ── Use the shared, app-wide selected address (single source of
      //      truth). It is resolved by the delivery screen before this runs;
      //      null only when the user has no saved addresses.
      final chosen = _ref.read(selectedDeliveryAddressProvider);

      double? lat;
      double? lng;
      String? label;
      String? resolvedAddress;
      LocationAccess loc = LocationAccess.unknown;

      if (chosen != null &&
          (chosen.latitude != 0.0 || chosen.longitude != 0.0)) {
        lat = chosen.latitude;
        lng = chosen.longitude;
        label = _addressLabel(chosen);
        // Saved addresses already carry a decoded, formatted address.
        resolvedAddress = chosen.formattedAddress.isNotEmpty
            ? chosen.formattedAddress
            : await _reverseGeocode(lat, lng);
      } else {
        // 1b ── No usable address → fall back to the device location.
        final resolved = await _resolveCurrentLocation();
        loc = resolved.access;

        if (loc != LocationAccess.granted || resolved.position == null) {
          // Location unavailable → DON'T gate; enable food + show info box.
          final notif = await _notificationsEnabled();
          state = state.copyWith(
            area: AreaServiceability.unknown,
            location: loc,
            sourceLabel: 'Current location',
            notificationsEnabled: notif,
            notificationChecked: true,
            isEvaluating: false,
          );
          return;
        }

        lat = resolved.position!.latitude;
        lng = resolved.position!.longitude;
        label = 'Current location';
        // Decode the device coordinate into a readable address for the header.
        resolvedAddress = await _reverseGeocode(lat, lng);
      }

      // 2 ── Serviceability check for the resolved coordinate.
      AreaServiceability area = AreaServiceability.unknown;
      String? zone;
      try {
        final res = await _ref
            .read(serviceabilityRepositoryProvider)
            .checkServiceability(latitude: lat, longitude: lng);
        final data = res.data;
        if (res.success && data != null && data.isServiceable) {
          area = AreaServiceability.serviceable;
          zone = data.zoneName;
        } else {
          area = AreaServiceability.notServiceable;
        }
      } catch (e) {
        // Fail-open: a transient error never blocks ordering.
        debugPrint('[DeliveryGate] serviceability error: $e');
        area = AreaServiceability.unknown;
      }

      // 3 ── Notification status.
      final notif = await _notificationsEnabled();

      state = state.copyWith(
        area: area,
        location: loc == LocationAccess.unknown ? state.location : loc,
        zoneName: zone,
        sourceLabel: label,
        resolvedAddress: resolvedAddress,
        latitude: lat,
        longitude: lng,
        notificationsEnabled: notif,
        notificationChecked: true,
        isEvaluating: false,
      );
    } finally {
      if (state.isEvaluating) {
        state = state.copyWith(isEvaluating: false);
      }
    }
  }

  // ── Public actions ──────────────────────────────────────────────────────────

  /// Triggered by the "Enable location" info box. Requests permission / opens
  /// the relevant settings screen, then re-evaluates on success.
  Future<void> enableLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    if (permission == LocationPermission.denied) return;

    // Granted → reset the dismiss flag and re-run the full evaluation.
    state = state.copyWith(locationInfoDismissed: false);
    await evaluate();
  }

  /// Triggered by the "Enable notifications" info box or drawer toggle.
  /// Clears any explicit user-disable flag, then (re-)requests OS permission.
  Future<void> enableNotifications() async {
    // Clear user-preference override first so the switch reflects OS state.
    state = state.copyWith(notifUserDisabled: false);

    final granted =
        await FirebaseNotificationService.getInstance().requestPermission();
    if (!granted) {
      // The OS won't re-prompt after a prior denial — send the user to settings.
      await openAppSettings();
    }
    final notif = await _notificationsEnabled();
    state = state.copyWith(
      notificationsEnabled: notif,
      notificationChecked: true,
    );
  }

  /// Triggered from the drawer toggle when the user chooses to disable.
  /// Sets the explicit user-preference flag; no OS settings change is needed
  /// because we control the effective state independently of the OS permission.
  void disableNotifications() {
    state = state.copyWith(notifUserDisabled: true);
  }

  void dismissLocationInfo() =>
      state = state.copyWith(locationInfoDismissed: true);

  void dismissNotificationInfo() =>
      state = state.copyWith(notificationInfoDismissed: true);

  // ── Internals ────────────────────────────────────────────────────────────────

  Future<({LocationAccess access, Position? position})>
      _resolveCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (access: LocationAccess.serviceDisabled, position: null);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (access: LocationAccess.denied, position: null);
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        return (access: LocationAccess.granted, position: pos);
      } on TimeoutException {
        final last = await Geolocator.getLastKnownPosition();
        return (access: LocationAccess.granted, position: last);
      }
    } catch (e) {
      debugPrint('[DeliveryGate] location error: $e');
      return (access: LocationAccess.denied, position: null);
    }
  }

  /// Reverse-geocodes a coordinate into a compact, readable address.
  /// Returns null on any failure — callers fall back to a generic label.
  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;

      // Build "name, subLocality, locality, postalCode", skipping blanks and
      // consecutive duplicates (geocoding often repeats parts).
      final raw = <String?>[
        p.name,
        p.subLocality,
        p.locality,
        p.postalCode,
      ];
      final parts = <String>[];
      for (final value in raw) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) continue;
        if (parts.isNotEmpty && parts.last == v) continue;
        parts.add(v);
      }
      return parts.isEmpty ? null : parts.join(', ');
    } catch (e) {
      debugPrint('[DeliveryGate] reverseGeocode error: $e');
      return null;
    }
  }

  Future<bool> _notificationsEnabled() async {
    try {
      return await FirebaseNotificationService.getInstance()
          .areNotificationsEnabled();
    } catch (_) {
      return true; // fail-open: never nag on an error.
    }
  }

  String _addressLabel(DeliveryAddressModel a) {
    switch (a.label.toLowerCase()) {
      case 'work':
        return 'Work';
      case 'other':
        return 'Other';
      default:
        return 'Home';
    }
  }
}

final deliveryGateProvider =
    StateNotifierProvider<DeliveryGateNotifier, DeliveryGateState>(
        (ref) => DeliveryGateNotifier(ref));
