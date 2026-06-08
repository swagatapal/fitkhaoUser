import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/firebase_notification_service.dart';
import '../../profile/models/delivery_address_model.dart';
import '../../profile/providers/delivery_address_provider.dart';
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

  final bool notificationsEnabled;
  final bool notificationChecked;

  final bool isEvaluating;

  // User-dismissed info banners (per app session).
  final bool locationInfoDismissed;
  final bool notificationInfoDismissed;

  const DeliveryGateState({
    this.area = AreaServiceability.unknown,
    this.location = LocationAccess.unknown,
    this.zoneName,
    this.sourceLabel,
    this.notificationsEnabled = true,
    this.notificationChecked = false,
    this.isEvaluating = false,
    this.locationInfoDismissed = false,
    this.notificationInfoDismissed = false,
  });

  /// Only an explicit "not serviceable" blocks ordering. Unknown / in-flight /
  /// location-denied all keep food enabled (per product requirement).
  bool get areaBlocksOrdering => area == AreaServiceability.notServiceable;

  bool get showLocationInfo =>
      !locationInfoDismissed &&
      (location == LocationAccess.denied ||
          location == LocationAccess.serviceDisabled);

  bool get showNotificationInfo =>
      notificationChecked &&
      !notificationsEnabled &&
      !notificationInfoDismissed;

  DeliveryGateState copyWith({
    AreaServiceability? area,
    LocationAccess? location,
    String? zoneName,
    String? sourceLabel,
    bool? notificationsEnabled,
    bool? notificationChecked,
    bool? isEvaluating,
    bool? locationInfoDismissed,
    bool? notificationInfoDismissed,
  }) {
    return DeliveryGateState(
      area: area ?? this.area,
      location: location ?? this.location,
      zoneName: zoneName ?? this.zoneName,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationChecked: notificationChecked ?? this.notificationChecked,
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

  DeliveryGateNotifier(this._ref) : super(const DeliveryGateState());

  /// Full entry evaluation:
  ///   1. Resolve a coordinate — default address → first address → current
  ///      device location.
  ///   2. Check serviceability for that coordinate (skipped if the location is
  ///      unavailable, in which case food stays enabled with an info prompt).
  ///   3. Check whether notifications are enabled (for the soft prompt).
  Future<void> evaluate() async {
    if (_running) return;
    _running = true;
    state = state.copyWith(
      isEvaluating: true,
      area: AreaServiceability.checking,
    );

    try {
      // 1 ── Resolve coordinate from a saved address, if any.
      final chosen = await _resolveAddress();

      double? lat;
      double? lng;
      String? label;
      LocationAccess loc = LocationAccess.unknown;

      if (chosen != null &&
          (chosen.latitude != 0.0 || chosen.longitude != 0.0)) {
        lat = chosen.latitude;
        lng = chosen.longitude;
        label = _addressLabel(chosen);
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
        notificationsEnabled: notif,
        notificationChecked: true,
        isEvaluating: false,
      );
    } finally {
      _running = false;
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

  /// Triggered by the "Enable notifications" info box.
  Future<void> enableNotifications() async {
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

  void dismissLocationInfo() =>
      state = state.copyWith(locationInfoDismissed: true);

  void dismissNotificationInfo() =>
      state = state.copyWith(notificationInfoDismissed: true);

  // ── Internals ────────────────────────────────────────────────────────────────

  Future<DeliveryAddressModel?> _resolveAddress() async {
    try {
      final list = await _ref.read(deliveryAddressRepositoryProvider).getAddresses();
      if (list.isEmpty) return null;
      return list.firstWhere((a) => a.isDefault, orElse: () => list.first);
    } catch (e) {
      debugPrint('[DeliveryGate] loadAddresses error: $e');
      return null;
    }
  }

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
