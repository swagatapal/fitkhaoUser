import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers/providers.dart';
import '../models/consultation_models.dart';
import '../repository/consultation_repository.dart';

final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);
  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }
  return ConsultationRepository(
      apiClient: apiClient, localStorage: localStorage);
});

/// Nutritionists the user can book with (available ones first).
final nutritionistsProvider =
    FutureProvider.autoDispose<List<Nutritionist>>((ref) async {
  await ref.watch(localStorageProvider.future);
  final res = await ref.read(consultationRepositoryProvider).getNutritionists();
  final list = [...res.nutritionists]..sort((a, b) {
      if (a.isAvailable == b.isAvailable) return 0;
      return a.isAvailable ? -1 : 1;
    });
  return list;
});

/// Family key for a nutritionist's slots on a given date.
typedef SlotsQuery = ({String nutritionistId, String date});

/// Slot availability for (nutritionist, date). Auto-disposed and keyed so
/// switching nutritionist/date fetches fresh data; `invalidate` after booking.
final nutritionistSlotsProvider = FutureProvider.autoDispose
    .family<List<ConsultationAvailability>, SlotsQuery>((ref, query) async {
  await ref.watch(localStorageProvider.future);
  final res = await ref.read(consultationRepositoryProvider).getSlots(
        nutritionistId: query.nutritionistId,
        date: query.date,
      );
  return res.availabilities;
});

/// The user's active consultation, or `null` when nothing is booked yet.
///
/// Token-scoped via `active-subscription` (no stored id needed, so it works
/// across devices): the current consultation counts as a booking only while it
/// is `scheduled` — a `pending` / cancelled / completed one leaves the user
/// free to book. `invalidate` after book / cancel to re-sync.
final activeBookingProvider =
    FutureProvider.autoDispose<BookedSlotInfo?>((ref) async {
  await ref.watch(localStorageProvider.future);
  final res = await ref
      .read(consultationRepositoryProvider)
      .getActiveSubscriptionConsultation();
  final current = res.current;
  return (current != null && current.isBooked) ? current : null;
});

// ── Booking submission ──

class BookSlotState {
  final bool isSubmitting;
  final String? error;
  final String? consultationId; // set on success

  const BookSlotState({
    this.isSubmitting = false,
    this.error,
    this.consultationId,
  });
}

class BookSlotNotifier extends StateNotifier<BookSlotState> {
  BookSlotNotifier(this._ref) : super(const BookSlotState());

  final Ref _ref;

  /// Returns `true` when the slot was booked.
  Future<bool> book({
    required String availabilityId,
    required String consultationTimeId,
  }) async {
    if (state.isSubmitting) return false;
    state = const BookSlotState(isSubmitting: true);
    try {
      final res = await _ref.read(consultationRepositoryProvider).bookSlot(
            availabilityId: availabilityId,
            consultationTimeId: consultationTimeId,
          );
      if (res.success) {
        // active-subscription is the source of truth — just refresh the gate.
        _ref.invalidate(activeBookingProvider);
        state = BookSlotState(consultationId: res.consultationId);
        return true;
      }
      state = BookSlotState(
        error: res.message.isNotEmpty
            ? res.message
            : 'Could not book this slot. Please try again.',
      );
      return false;
    } on AppException catch (e) {
      state = BookSlotState(error: e.message);
      return false;
    } catch (_) {
      state = const BookSlotState(
          error: 'Could not book this slot. Please try again.');
      return false;
    }
  }
}

final bookSlotProvider =
    StateNotifierProvider.autoDispose<BookSlotNotifier, BookSlotState>(
        (ref) => BookSlotNotifier(ref));

// ── Cancellation ──

class CancelBookingState {
  final bool isCancelling;
  final String? error;

  const CancelBookingState({this.isCancelling = false, this.error});
}

class CancelBookingNotifier extends StateNotifier<CancelBookingState> {
  CancelBookingNotifier(this._ref) : super(const CancelBookingState());

  final Ref _ref;

  /// Cancels [consultationId]; on success refreshes the gate so the user can
  /// book again. Returns `true` on success.
  Future<bool> cancel({
    required String consultationId,
    String? reason,
  }) async {
    if (state.isCancelling) return false;
    state = const CancelBookingState(isCancelling: true);
    try {
      final res = await _ref.read(consultationRepositoryProvider).cancelSlot(
            consultationId: consultationId,
            reason: reason,
          );
      final ok = res['success'] == true;
      if (ok) {
        _ref.invalidate(activeBookingProvider);
        state = const CancelBookingState();
        return true;
      }
      state = CancelBookingState(
        error: (res['message'] as String?)?.isNotEmpty == true
            ? res['message'] as String
            : 'Could not cancel your booking. Please try again.',
      );
      return false;
    } on AppException catch (e) {
      state = CancelBookingState(error: e.message);
      return false;
    } catch (_) {
      state = const CancelBookingState(
          error: 'Could not cancel your booking. Please try again.');
      return false;
    }
  }
}

final cancelBookingProvider = StateNotifierProvider.autoDispose<
    CancelBookingNotifier,
    CancelBookingState>((ref) => CancelBookingNotifier(ref));
