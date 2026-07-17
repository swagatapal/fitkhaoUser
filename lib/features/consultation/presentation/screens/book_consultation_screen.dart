import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/consultation_models.dart';
import '../../providers/consultation_providers.dart';

const _kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _kMonthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Book a consultation: pick a nutritionist, a date, an available time slot,
/// then confirm. Wired to /api/user/nutritionists, the slots endpoint and
/// /api/user/consultations/book-slot.
class BookConsultationScreen extends ConsumerStatefulWidget {
  const BookConsultationScreen({super.key});

  @override
  ConsumerState<BookConsultationScreen> createState() =>
      _BookConsultationScreenState();
}

class _BookConsultationScreenState
    extends ConsumerState<BookConsultationScreen> {
  static const int _dateWindowDays = 14;

  Nutritionist? _nutritionist;
  late DateTime _date = _dateOnly(DateTime.now());

  // The chosen slot — availabilityId is what the booking API wants alongside
  // the consultationTimeId.
  String? _availabilityId;
  String? _timeId;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _selectNutritionist(Nutritionist n) {
    setState(() {
      _nutritionist = n;
      _availabilityId = null;
      _timeId = null;
    });
  }

  void _selectDate(DateTime d) {
    setState(() {
      _date = _dateOnly(d);
      _availabilityId = null;
      _timeId = null;
    });
  }

  void _selectTime(ConsultationTime t) {
    setState(() {
      _availabilityId = t.availabilityId;
      _timeId = t.id;
    });
  }

  Future<void> _confirm() async {
    final availabilityId = _availabilityId;
    final timeId = _timeId;
    if (availabilityId == null || timeId == null) return;

    final ok = await ref.read(bookSlotProvider.notifier).book(
          availabilityId: availabilityId,
          consultationTimeId: timeId,
        );
    if (!mounted) return;
    final state = ref.read(bookSlotProvider);
    if (ok) {
      // Free the slot list for this date and drop the local selection; the
      // active-booking gate (invalidated by the notifier) flips the screen to
      // the booked view.
      ref.invalidate(nutritionistSlotsProvider((
        nutritionistId: _nutritionist!.id,
        date: _apiDate(_date),
      )));
      setState(() {
        _availabilityId = null;
        _timeId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Consultation slot booked successfully.'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(state.error ?? 'Could not book this slot.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeBookingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: activeAsync.when(
                loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryGreen),
                ),
                error: (_, __) => _CenterMessage(
                  icon: Icons.error_outline_rounded,
                  message: 'Could not check your consultation status.',
                  onRetry: () => ref.invalidate(activeBookingProvider),
                ),
                // Already booked → show the booking + cancel; otherwise the
                // full picker flow.
                data: (booking) => booking != null
                    ? _BookedConsultationView(info: booking)
                    : _buildBookingFlow(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingFlow(BuildContext context) {
    final nutritionistsAsync = ref.watch(nutritionistsProvider);
    final submitting =
        ref.watch(bookSlotProvider.select((s) => s.isSubmitting));

    return Column(
      children: [
        Expanded(
          child: nutritionistsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
            error: (_, __) => _CenterMessage(
              icon: Icons.error_outline_rounded,
              message: 'Could not load nutritionists.',
              onRetry: () => ref.invalidate(nutritionistsProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const _CenterMessage(
                  icon: Icons.person_off_rounded,
                  message: 'No nutritionists are available right now.',
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenPaddingHorizontal,
                    AppSizes.spacing16,
                    AppSizes.screenPaddingHorizontal,
                    AppSizes.spacing32),
                children: [
                  const _SectionLabel('Choose a nutritionist'),
                  const SizedBox(height: AppSizes.spacing12),
                  for (final n in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
                      child: _NutritionistCard(
                        nutritionist: n,
                        selected: _nutritionist?.id == n.id,
                        onTap: () => _selectNutritionist(n),
                      ),
                    ),
                  if (_nutritionist != null) ...[
                    const SizedBox(height: AppSizes.spacing16),
                    const _SectionLabel('Select a date'),
                    const SizedBox(height: AppSizes.spacing12),
                    _DateStrip(
                      selected: _date,
                      days: _dateWindowDays,
                      onSelect: _selectDate,
                    ),
                    const SizedBox(height: AppSizes.spacing16),
                    const _SectionLabel('Available time slots'),
                    const SizedBox(height: AppSizes.spacing12),
                    _SlotsView(
                      nutritionistId: _nutritionist!.id,
                      date: _date,
                      selectedTimeId: _timeId,
                      onSelect: _selectTime,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        _ConfirmBar(
          enabled: _timeId != null && !submitting,
          submitting: submitting,
          onConfirm: _confirm,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p20,
        vertical: AppSizes.spacing12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: AppSizes.shadowBlur10,
            offset: const Offset(0, AppSizes.spacing2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.spacing8),
              decoration: BoxDecoration(
                color: AppColors.darkGreen,
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.textWhite, size: AppSizes.icon24),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book Consultation',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                Text(
                  'Pick a nutritionist and time slot',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the user already has an active booking: the details + a cancel
/// action. Cancelling frees them to book again.
class _BookedConsultationView extends ConsumerStatefulWidget {
  const _BookedConsultationView({required this.info});

  final BookedSlotInfo info;

  @override
  ConsumerState<_BookedConsultationView> createState() =>
      _BookedConsultationViewState();
}

class _BookedConsultationViewState
    extends ConsumerState<_BookedConsultationView> {
  String _formatDate(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${_kWeekdayShort[d.weekday - 1]}, ${d.day} ${_kMonthShort[d.month - 1]} ${d.year}';
  }

  Future<void> _cancel() async {
    final reason = await _askReason();
    if (reason == null || !mounted) return;

    final ok = await ref.read(cancelBookingProvider.notifier).cancel(
          consultationId: widget.info.consultationId,
          reason: reason,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Consultation cancelled. You can book a new slot.'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(cancelBookingProvider).error ??
            'Could not cancel your booking.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<String?> _askReason() {
    final controller = TextEditingController(text: 'Change of plans');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel consultation?',
            style:
                TextStyle(fontFamily: 'Lato', fontWeight: AppTypography.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cancelling frees up this slot so you can book another one.',
              style: TextStyle(fontFamily: 'Lato'),
            ),
            const SizedBox(height: AppSizes.spacing12),
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 2,
              style: const TextStyle(
                  fontFamily: 'Lato', fontSize: AppTypography.fontSize14),
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep booking',
                style: TextStyle(fontFamily: 'Lato')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Cancel it',
                style:
                    TextStyle(fontFamily: 'Lato', color: AppColors.errorColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final cancelling =
        ref.watch(cancelBookingProvider.select((s) => s.isCancelling));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing16,
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing32),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.spacing16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSizes.radius16),
            border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.spacing8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                    child: const Icon(Icons.event_available_rounded,
                        color: AppColors.primaryGreen, size: AppSizes.icon24),
                  ),
                  const SizedBox(width: AppSizes.spacing12),
                  const Expanded(
                    child: Text(
                      'Consultation booked',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacing12),
              if (info.nutritionistName.isNotEmpty)
                _InfoRow(
                    icon: Icons.person_rounded, label: info.nutritionistName),
              if (info.date.isNotEmpty)
                _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: _formatDate(info.date)),
              if (info.timeRange.isNotEmpty)
                _InfoRow(icon: Icons.schedule_rounded, label: info.timeRange),
              if (info.statusLabel.isNotEmpty)
                _InfoRow(
                    icon: Icons.info_outline_rounded, label: info.statusLabel),
            ],
          ),
        ),
        if (info.isRescheduleRequested) ...[
          const SizedBox(height: AppSizes.spacing12),
          _RescheduleNotice(
            requestedBy: info.rescheduleRequestedBy,
            reason: info.rescheduleReason,
          ),
        ],
        const SizedBox(height: AppSizes.spacing16),
        Text(
          info.isRescheduleRequested
              ? 'A reschedule has been requested for this consultation. Cancel '
                  'it to pick a new slot yourself.'
              : 'You already have a consultation booked. Cancel it to choose a '
                  'different slot.',
          style: TextStyle(
            fontSize: AppTypography.fontSize12,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing16),
        SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: cancelling ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.errorColor,
              side: BorderSide(
                  color: AppColors.errorColor.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
            ),
            icon: cancelling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.errorColor),
                  )
                : const Icon(Icons.close_rounded, size: AppSizes.icon20),
            label: Text(
              cancelling ? 'Cancelling…' : 'Cancel consultation',
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.bold,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.icon16, color: AppColors.primaryGreen),
          const SizedBox(width: AppSizes.spacing8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.semiBold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Amber notice shown when a reschedule has been requested on a booking.
class _RescheduleNotice extends StatelessWidget {
  const _RescheduleNotice({required this.requestedBy, required this.reason});

  final String requestedBy;
  final String reason;

  static const Color _amber = Color(0xFFC66301);
  static const Color _amberBg = Color(0xFFFFF8E1);

  @override
  Widget build(BuildContext context) {
    final by = requestedBy.isEmpty
        ? 'A reschedule has been requested'
        : 'Reschedule requested by ${requestedBy[0].toUpperCase()}${requestedBy.substring(1)}';

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: _amberBg,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: _amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_repeat_rounded,
              color: _amber, size: AppSizes.icon20),
          const SizedBox(width: AppSizes.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  by,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize13,
                    fontWeight: AppTypography.bold,
                    color: _amber,
                    fontFamily: 'Lato',
                  ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Reason: $reason',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                      height: 1.35,
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: AppTypography.fontSize16,
        fontWeight: AppTypography.bold,
        color: AppColors.textPrimary,
        fontFamily: 'Lato',
      ),
    );
  }
}

class _NutritionistCard extends StatelessWidget {
  const _NutritionistCard({
    required this.nutritionist,
    required this.selected,
    required this.onTap,
  });

  final Nutritionist nutritionist;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = nutritionist;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryGreen.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          border: Border.all(
            color: selected
                ? AppColors.primaryGreen
                : AppColors.borderColor.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
              child: Text(
                n.name.isNotEmpty ? n.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize18,
                  fontWeight: AppTypography.bold,
                  color: AppColors.primaryGreen,
                  fontFamily: 'Lato',
                ),
              ),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.name.isEmpty ? 'Nutritionist' : n.name,
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                      _StatusDot(available: n.isAvailable),
                    ],
                  ),
                  if (n.specializationLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.specializationLabel,
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.spacing6),
                  Row(
                    children: [
                      _MetaChip(
                        icon: Icons.workspace_premium_rounded,
                        label: '${n.yearsOfExperience} yr'
                            '${n.yearsOfExperience == 1 ? '' : 's'} exp',
                      ),
                      const SizedBox(width: AppSizes.spacing8),
                      _MetaChip(
                        icon: Icons.event_available_rounded,
                        label: '${n.totalConsultations} consults',
                      ),
                    ],
                  ),
                  if (n.bio.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.spacing6),
                    Text(
                      n.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        height: 1.35,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primaryGreen : AppColors.textTertiary,
              size: AppSizes.icon20,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.available});
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.primaryGreen : AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
      ),
      child: Text(
        available ? 'Available' : 'Busy',
        style: TextStyle(
          fontSize: AppTypography.fontSize10,
          fontWeight: AppTypography.bold,
          color: color,
          fontFamily: 'Lato',
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.icon14, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.fontSize10,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.selected,
    required this.days,
    required this.onSelect,
  });

  final DateTime selected;
  final int days;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days,
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.spacing8),
        itemBuilder: (_, i) {
          final date = DateTime(today.year, today.month, today.day + i);
          final isSelected = date.year == selected.year &&
              date.month == selected.month &&
              date.day == selected.day;
          return GestureDetector(
            onTap: () => onSelect(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radius8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.borderColor.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _kWeekdayShort[date.weekday - 1],
                    style: TextStyle(
                      fontSize: AppTypography.fontSize10,
                      fontWeight: AppTypography.semiBold,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize16,
                      fontWeight: AppTypography.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  Text(
                    _kMonthShort[date.month - 1],
                    style: TextStyle(
                      fontSize: AppTypography.fontSize10,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Time slots for the chosen nutritionist + date.
class _SlotsView extends ConsumerWidget {
  const _SlotsView({
    required this.nutritionistId,
    required this.date,
    required this.selectedTimeId,
    required this.onSelect,
  });

  final String nutritionistId;
  final DateTime date;
  final String? selectedTimeId;
  final ValueChanged<ConsultationTime> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (nutritionistId: nutritionistId, date: _apiDate(date));
    final async = ref.watch(nutritionistSlotsProvider(query));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.spacing24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      ),
      error: (_, __) => _CenterMessage(
        icon: Icons.error_outline_rounded,
        message: 'Could not load slots for this date.',
        onRetry: () => ref.invalidate(nutritionistSlotsProvider(query)),
        compact: true,
      ),
      data: (availabilities) {
        final hasAny = availabilities.any((a) => a.times.isNotEmpty);
        if (!hasAny) {
          return const _CenterMessage(
            icon: Icons.event_busy_rounded,
            message: 'No slots available on this date.',
            compact: true,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final a in availabilities)
              if (a.times.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spacing12),
                  child: Wrap(
                    spacing: AppSizes.spacing8,
                    runSpacing: AppSizes.spacing8,
                    children: [
                      for (final t in a.times)
                        _SlotChip(
                          label: t.label,
                          selected: !t.isBooked && t.id == selectedTimeId,
                          disabled: t.isBooked,
                          onTap: t.isBooked ? null : () => onSelect(t),
                        ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.disabled,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    if (disabled) {
      bg = AppColors.borderColor.withValues(alpha: 0.15);
      fg = AppColors.textTertiary;
      border = AppColors.borderColor.withValues(alpha: 0.4);
    } else if (selected) {
      bg = AppColors.primaryGreen;
      fg = Colors.white;
      border = AppColors.primaryGreen;
    } else {
      bg = Colors.white;
      fg = AppColors.textPrimary;
      border = AppColors.borderColor.withValues(alpha: 0.7);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing12, vertical: AppSizes.spacing8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(color: border, width: selected ? 1.5 : 1),
        ),
        child: Text(
          label.isEmpty ? 'Slot' : label,
          style: TextStyle(
            fontSize: AppTypography.fontSize12,
            fontWeight: AppTypography.semiBold,
            color: fg,
            fontFamily: 'Lato',
            decoration: disabled ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.enabled,
    required this.submitting,
    required this.onConfirm,
  });

  final bool enabled;
  final bool submitting;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing12,
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.buttonHeight,
        child: ElevatedButton(
          onPressed: enabled ? onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppColors.borderColor.withValues(alpha: 0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
          ),
          child: submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Confirm booking',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.bold,
                    fontFamily: 'Lato',
                  ),
                ),
        ),
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({
    required this.icon,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: compact ? 32 : 44,
            color: AppColors.textTertiary.withValues(alpha: 0.7)),
        const SizedBox(height: AppSizes.spacing8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSizes.spacing8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(
                    fontFamily: 'Lato', color: AppColors.primaryGreen)),
          ),
        ],
      ],
    );
    return compact
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing20),
            child: Center(child: content))
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spacing24),
              child: content,
            ),
          );
  }
}
