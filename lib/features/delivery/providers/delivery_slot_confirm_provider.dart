import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/delivery_slot_model.dart';

enum SlotConfirmStatus { idle, submitting, success, error }

/// State of the "confirm delivery schedule" submission.
class SlotConfirmState {
  final SlotConfirmStatus status;
  final String? message;

  const SlotConfirmState({this.status = SlotConfirmStatus.idle, this.message});

  bool get isSubmitting => status == SlotConfirmStatus.submitting;
}

/// Drives POST /api/delivery-slots/confirm. The Plan Manager builds the
/// request from its local selections and calls [submit]; this notifier owns
/// only the in-flight / result state so the UI stays declarative.
class DeliverySlotConfirmNotifier extends StateNotifier<SlotConfirmState> {
  DeliverySlotConfirmNotifier(this._ref) : super(const SlotConfirmState());

  final Ref _ref;

  /// Returns `true` on success. Guards against double-submits while in flight.
  Future<bool> submit(ConfirmDeliveryScheduleRequest request) async {
    if (state.isSubmitting) return false;
    state = const SlotConfirmState(status: SlotConfirmStatus.submitting);
    try {
      final repo = _ref.read(deliverySlotRepositoryProvider);
      final res = await repo.confirmDeliverySchedule(request);
      if (res.success) {
        state = SlotConfirmState(
          status: SlotConfirmStatus.success,
          message: res.message.isNotEmpty
              ? res.message
              : 'Delivery schedule confirmed.',
        );
        return true;
      }
      state = SlotConfirmState(
        status: SlotConfirmStatus.error,
        message: res.message.isNotEmpty
            ? res.message
            : 'Could not confirm your delivery schedule.',
      );
      return false;
    } catch (_) {
      state = const SlotConfirmState(
        status: SlotConfirmStatus.error,
        message: 'Could not confirm your delivery schedule. Please try again.',
      );
      return false;
    }
  }

  void reset() => state = const SlotConfirmState();
}

final deliverySlotConfirmProvider = StateNotifierProvider.autoDispose<
    DeliverySlotConfirmNotifier,
    SlotConfirmState>((ref) => DeliverySlotConfirmNotifier(ref));
