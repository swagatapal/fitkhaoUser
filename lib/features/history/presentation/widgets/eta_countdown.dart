import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';

/// A live countdown to a meal's estimated delivery time.
///
/// [estimatedDeliveryAt] is an absolute instant (UTC) computed from the
/// kitchen's acceptance timestamp plus the total estimated delivery minutes.
/// The widget ticks once per second, rebuilding only itself, and stops the
/// timer the moment the ETA elapses. The target time is displayed in IST
/// (UTC + 5:30) regardless of the device timezone.
///
/// Two layouts:
/// • full    → a prominent banner for the order tracking screen
/// • compact → a single-line pill for the history list cards
class EtaCountdown extends StatefulWidget {
  final DateTime estimatedDeliveryAt;
  final bool compact;

  const EtaCountdown({
    super.key,
    required this.estimatedDeliveryAt,
    this.compact = false,
  });

  @override
  State<EtaCountdown> createState() => _EtaCountdownState();
}

class _EtaCountdownState extends State<EtaCountdown> {
  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _recompute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
  }

  @override
  void didUpdateWidget(covariant EtaCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.estimatedDeliveryAt != widget.estimatedDeliveryAt) {
      _timer?.cancel();
      _recompute();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _recompute() {
    // Absolute-instant difference — timezone-independent.
    final diff = widget.estimatedDeliveryAt.difference(DateTime.now());
    final next = diff.isNegative ? Duration.zero : diff;
    if (diff.isNegative) _timer?.cancel();
    if (!mounted) return;
    if (next != _remaining) {
      setState(() => _remaining = next);
    }
  }

  bool get _elapsed => _remaining <= Duration.zero;

  /// "08:42 min" while counting; collapses to a friendly message at zero.
  String get _countdownText {
    if (_elapsed) return 'Arriving at any moment';
    final m = _remaining.inMinutes;
    final s = _remaining.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} min';
  }

  /// Target delivery time in IST, e.g. "12:52 AM".
  String get _istEtaLabel {
    final ist = widget.estimatedDeliveryAt.toUtc().add(_istOffset);
    final h = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    final m = ist.minute.toString().padLeft(2, '0');
    final ampm = ist.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return widget.compact ? _buildCompact() : _buildFull();
  }

  // ─── Full banner (tracking screen) ─────────────────────────────────────────

  Widget _buildFull() {
    final accent =
        _elapsed ? AppColors.successColor : AppColors.primaryGreen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _elapsed
                  ? Icons.delivery_dining_rounded
                  : Icons.timer_outlined,
              color: accent,
              size: AppSizes.icon24,
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _elapsed ? 'Almost there' : 'Estimated delivery in',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: AppColors.textSecondary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _countdownText,
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: accent,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Arriving by $_istEtaLabel',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.medium,
                    color: AppColors.textSecondary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Compact pill (history list card) ──────────────────────────────────────

  Widget _buildCompact() {
    final accent =
        _elapsed ? AppColors.successColor : AppColors.primaryGreen;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: AppSizes.icon14, color: accent),
          const SizedBox(width: AppSizes.spacing4),
          Flexible(
            child: Text(
              _elapsed
                  ? 'Arriving at any moment'
                  : '$_countdownText • by $_istEtaLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                fontWeight: AppTypography.semiBold,
                color: accent,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
