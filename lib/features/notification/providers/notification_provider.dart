import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../models/notification_model.dart';
import '../repository/notification_repository.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;
  bool get hasUnread => notifications.any((n) => !n.isRead);

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class NotificationNotifier extends StateNotifier<NotificationState> {
  final Ref _ref;

  NotificationNotifier(this._ref) : super(const NotificationState());

  NotificationRepository get _repo => _ref.read(notificationRepositoryProvider);

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading) return;
    state = refresh
        ? const NotificationState(isLoading: true)
        : state.copyWith(isLoading: true, error: null);

    try {
      final list = await _repo.getNotifications();
      state = state.copyWith(
        notifications: list,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      debugPrint('[NotificationNotifier] load error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Optimistically mark a single notification as read, then sync with API.
  /// Rolls back on failure.
  Future<void> markAsRead(String id) async {
    final previous = state.notifications;
    if (previous.firstWhere((n) => n.id == id, orElse: _empty).isRead) return;

    state = state.copyWith(
      notifications: previous
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList(),
    );

    try {
      await _repo.updateNotifications(readNotiList: [id]);
    } catch (_) {
      state = state.copyWith(notifications: previous);
    }
  }

  /// Optimistically mark all unread notifications as read, then sync.
  Future<void> markAllAsRead() async {
    final unreadIds =
        state.notifications.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    final previous = state.notifications;
    state = state.copyWith(
      notifications: previous.map((n) => n.copyWith(isRead: true)).toList(),
    );

    try {
      await _repo.updateNotifications(readNotiList: unreadIds);
    } catch (_) {
      state = state.copyWith(notifications: previous);
    }
  }

  /// Optimistically remove a single notification from the list, then sync.
  Future<void> deleteNotification(String id) async {
    await deleteMultiple([id]);
  }

  /// Optimistically remove multiple notifications at once, then sync.
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    final previous = state.notifications;
    final idSet = ids.toSet();

    state = state.copyWith(
      notifications: previous.where((n) => !idSet.contains(n.id)).toList(),
    );

    try {
      await _repo.updateNotifications(deleteNotiList: ids);
    } catch (_) {
      state = state.copyWith(notifications: previous);
    }
  }

  static AppNotification _empty() => const AppNotification(
        id: '',
        title: '',
        body: '',
        isRead: true,
        isDeleted: false,
        createdAt: '',
      );
}

// ─── Providers ───────────────────────────────────────────────────────────────

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;
  final apiClient = ref.watch(apiClientProvider);
  if (localStorage == null) throw Exception('LocalStorage not initialized');
  return NotificationRepository(apiClient: apiClient, localStorage: localStorage);
});

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref);
});
