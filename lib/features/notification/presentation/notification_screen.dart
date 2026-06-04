import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_typography.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  // IDs currently checked in selection mode
  final Set<String> _selectedIds = {};

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).load(refresh: true);
    });
  }

  // ─── Selection helpers ────────────────────────────────────────────────────

  void _onLongPress(String id) {
    setState(() => _selectedIds.add(id));
  }

  void _onTileTap(String id, bool isRead) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      });
    } else if (!isRead) {
      ref.read(notificationProvider.notifier).markAsRead(id);
    }
  }

  void _cancelSelection() => setState(() => _selectedIds.clear());

  void _toggleSelectAll(List<AppNotification> all) {
    setState(() {
      if (_selectedIds.length == all.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(all.map((n) => n.id));
      }
    });
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final ids = List<String>.from(_selectedIds);
    final confirmed = await _showDeleteConfirm(context, ids.length);
    if (confirmed != true || !mounted) return;

    setState(() => _selectedIds.clear());
    await ref.read(notificationProvider.notifier).deleteMultiple(ids);
  }

  Future<void> _deleteSingle(BuildContext context, String id) async {
    final confirmed = await _showDeleteConfirm(context, 1);
    if (confirmed != true || !mounted) return;
    await ref.read(notificationProvider.notifier).deleteNotification(id);
  }

  Future<bool?> _showDeleteConfirm(BuildContext context, int count) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(count: count),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);
    final allIds = state.notifications.map((n) => n.id).toList();
    final allSelected =
        allIds.isNotEmpty && _selectedIds.length == allIds.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        body: SafeArea(
          child: Column(
            children: [
              _isSelectionMode
                  ? _SelectionHeader(
                      selectedCount: _selectedIds.length,
                      allSelected: allSelected,
                      onCancel: _cancelSelection,
                      onToggleSelectAll: () =>
                          _toggleSelectAll(state.notifications),
                      onDeleteSelected: _selectedIds.isEmpty
                          ? null
                          : () => _deleteSelected(context),
                    )
                  : _Header(
                      hasUnread: state.hasUnread,
                      unreadCount: state.unreadCount,
                      onMarkAllRead: notifier.markAllAsRead,
                    ),
              Expanded(child: _buildBody(state, allIds.length, allSelected)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
      NotificationState state, int totalCount, bool allSelected) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (state.error != null && state.notifications.isEmpty) {
      return _ErrorState(
        message: state.error!,
        onRetry: () => ref.read(notificationProvider.notifier).load(refresh: true),
      );
    }

    if (state.notifications.isEmpty) {
      return const _EmptyState();
    }

    final grouped = _groupByDate(state.notifications);

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      // Disable pull-to-refresh while in selection mode
      onRefresh: _isSelectionMode
          ? () async {}
          : () => ref.read(notificationProvider.notifier).load(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: AppSizes.spacing8,
          bottom: AppSizes.spacing32,
        ),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final section = grouped[index];
          if (section is _DateHeader) {
            return _SectionHeader(label: section.label);
          }
          final item = (section as _NotificationEntry).notification;
          final isSelected = _selectedIds.contains(item.id);

          return _NotificationTile(
            notification: item,
            isSelectionMode: _isSelectionMode,
            isSelected: isSelected,
            onTap: () => _onTileTap(item.id, item.isRead),
            onLongPress: () => _onLongPress(item.id),
            onDelete: () => _deleteSingle(context, item.id),
          );
        },
      ),
    );
  }

  // ─── Date grouping ────────────────────────────────────────────────────────

  List<Object> _groupByDate(List<AppNotification> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayList = <AppNotification>[];
    final yesterdayList = <AppNotification>[];
    final earlierList = <AppNotification>[];

    for (final n in notifications) {
      final d = _parseDate(n.createdAt);
      final dateOnly = DateTime(d.year, d.month, d.day);
      if (dateOnly == today) {
        todayList.add(n);
      } else if (dateOnly == yesterday) {
        yesterdayList.add(n);
      } else {
        earlierList.add(n);
      }
    }

    final result = <Object>[];

    void addSection(String label, List<AppNotification> list) {
      if (list.isEmpty) return;
      result.add(_DateHeader(label));
      result.addAll(list.map(_NotificationEntry.new));
    }

    addSection('Today', todayList);
    addSection('Yesterday', yesterdayList);
    addSection('Earlier', earlierList);

    return result;
  }

  static DateTime _parseDate(String raw) {
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }
}

// ─── Data wrappers ────────────────────────────────────────────────────────────

class _DateHeader {
  final String label;
  const _DateHeader(this.label);
}

class _NotificationEntry {
  final AppNotification notification;
  const _NotificationEntry(this.notification);
}

// ─── Normal header ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool hasUnread;
  final int unreadCount;
  final VoidCallback onMarkAllRead;

  const _Header({
    required this.hasUnread,
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.screenPaddingHorizontal,
        vertical: AppSizes.spacing12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.darkGreen,
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: AppSizes.icon18,
                color: AppColors.textWhite,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(width: AppSizes.spacing8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(AppSizes.radius50),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.bold,
                        color: Colors.white,
                        fontFamily: AppTypography.fontFamily,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasUnread)
            TextButton(
              onPressed: onMarkAllRead,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing8,
                  vertical: AppSizes.spacing4,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: AppTypography.fontSize13,
                  fontWeight: AppTypography.semiBold,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Selection mode header ────────────────────────────────────────────────────

class _SelectionHeader extends StatelessWidget {
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onCancel;
  final VoidCallback onToggleSelectAll;
  final VoidCallback? onDeleteSelected;

  const _SelectionHeader({
    required this.selectedCount,
    required this.allSelected,
    required this.onCancel,
    required this.onToggleSelectAll,
    required this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: AppSizes.spacing8,
      ),
      child: Row(
        children: [
          // Cancel
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            tooltip: 'Cancel',
          ),
          // Selected count
          Expanded(
            child: Text(
              '$selectedCount selected',
              style: const TextStyle(
                fontSize: AppTypography.fontSize16,
                fontWeight: AppTypography.semiBold,
                color: AppColors.textPrimary,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
          ),
          // Select all / Deselect all
          TextButton(
            onPressed: onToggleSelectAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing8),
            ),
            child: Text(
              allSelected ? 'Deselect all' : 'Select all',
              style: const TextStyle(
                fontSize: AppTypography.fontSize13,
                fontWeight: AppTypography.semiBold,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
          ),
          // Delete button
          IconButton(
            onPressed: onDeleteSelected,
            icon: Icon(
              Icons.delete_outline,
              color: onDeleteSelected != null
                  ? AppColors.errorColor
                  : AppColors.textTertiary,
            ),
            tooltip: 'Delete selected',
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSizes.screenPaddingHorizontal,
        right: AppSizes.screenPaddingHorizontal,
        top: AppSizes.spacing16,
        bottom: AppSizes.spacing8,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: AppTypography.fontSize12,
          fontWeight: AppTypography.semiBold,
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
          fontFamily: AppTypography.fontFamily,
        ),
      ),
    );
  }
}

// ─── Notification tile ────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.screenPaddingHorizontal,
          vertical: AppSizes.spacing4,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.08)
              : notification.isRead
                  ? Colors.white
                  : AppColors.primaryGreen.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
                : notification.isRead
                    ? AppColors.borderColor
                    : AppColors.primaryGreen.withValues(alpha: 0.2),
            width: isSelected ? AppSizes.borderThick : AppSizes.borderNormal,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: checkbox in selection mode, type icon otherwise
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isSelectionMode
                    ? SizedBox(
                        key: const ValueKey('checkbox'),
                        width: 44,
                        height: 44,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryGreen
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryGreen
                                    : AppColors.borderColor,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                      )
                    : _TypeIcon(
                        key: const ValueKey('icon'),
                        type: notification.data?.type,
                      ),
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: AppTypography.fontSize14,
                              fontWeight: notification.isRead
                                  ? AppTypography.regular
                                  : AppTypography.semiBold,
                              color: AppColors.textPrimary,
                              fontFamily: AppTypography.fontFamily,
                            ),
                          ),
                        ),
                        if (!notification.isRead && !isSelectionMode) ...[
                          const SizedBox(width: AppSizes.spacing8),
                          const _UnreadDot(),
                        ],
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.spacing4),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                          fontFamily: AppTypography.fontFamily,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSizes.spacing6),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textTertiary,
                        fontFamily: AppTypography.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Swipe to delete is only available in normal mode
    if (isSelectionMode) return card;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: _swipeDeleteBg(),
      // Don't auto-dismiss — let the confirmation modal decide
      confirmDismiss: (_) async => false,
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          onDelete();
        }
      },
      child: card,
    );
  }

  Widget _swipeDeleteBg() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.screenPaddingHorizontal,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorColor,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSizes.spacing20),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, color: Colors.white, size: AppSizes.icon24),
          SizedBox(height: AppSizes.spacing4),
          Text(
            'Delete',
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              color: Colors.white,
              fontWeight: AppTypography.semiBold,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(String raw) {
    try {
      final date = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(date);

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Delete confirmation dialog ───────────────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  final int count;
  const _DeleteConfirmDialog({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 notification' : '$count notifications';
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      title: const Text(
        'Delete notification?',
        style: TextStyle(
          fontSize: AppTypography.fontSize16,
          fontWeight: AppTypography.semiBold,
          fontFamily: AppTypography.fontFamily,
        ),
      ),
      content: Text(
        'Are you sure you want to delete $label? This cannot be undone.',
        style: const TextStyle(
          fontSize: AppTypography.fontSize14,
          color: AppColors.textSecondary,
          height: 1.5,
          fontFamily: AppTypography.fontFamily,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Delete',
            style: TextStyle(
              color: AppColors.errorColor,
              fontWeight: AppTypography.semiBold,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Type icon ────────────────────────────────────────────────────────────────

class _TypeIcon extends StatelessWidget {
  final String? type;
  const _TypeIcon({super.key, this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _resolve(type);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      child: Icon(icon, color: color, size: AppSizes.icon20),
    );
  }

  static (IconData, Color) _resolve(String? type) {
    switch (type?.toUpperCase()) {
      case 'ORDER_PLACED':
      case 'ORDER_UPDATE':
      case 'ORDER_CONFIRMED':
      case 'ORDER_CANCELLED':
      case 'ORDER_DELIVERED':
        return (Icons.receipt_long_outlined, AppColors.primaryGreen);
      case 'PROMOTIONAL':
      case 'PROMO':
      case 'OFFER':
        return (Icons.local_offer_outlined, AppColors.warningColor);
      case 'SYSTEM':
        return (Icons.info_outline, const Color(0xFF1976D2));
      default:
        return (Icons.notifications_outlined, AppColors.textSecondary);
    }
  }
}

// ─── Unread dot ───────────────────────────────────────────────────────────────

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(top: 4),
      decoration: const BoxDecoration(
        color: AppColors.primaryGreen,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: AppSizes.icon48,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: AppSizes.spacing20),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: AppTypography.fontSize18,
                fontWeight: AppTypography.semiBold,
                color: AppColors.textPrimary,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
            const SizedBox(height: AppSizes.spacing8),
            const Text(
              "You're all caught up! We'll notify you when something new arrives.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                height: 1.5,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: AppSizes.icon48,
              color: AppColors.errorColor,
            ),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                height: 1.5,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
            const SizedBox(height: AppSizes.spacing20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: AppSizes.icon18),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing24,
                  vertical: AppSizes.spacing12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                textStyle: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontWeight: AppTypography.semiBold,
                  fontSize: AppTypography.fontSize14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
