import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/exercise_model.dart';
import '../../models/profession_model.dart';
import '../../models/profile_history_model.dart';
import '../../provider/exercise_provider.dart';
import '../../provider/profession_provider.dart';
import '../../provider/profile_history_provider.dart';
import '../../../auth/providers/auth_provider.dart';

class ProfileHistoryScreen extends ConsumerStatefulWidget {
  const ProfileHistoryScreen({super.key});

  @override
  ConsumerState<ProfileHistoryScreen> createState() =>
      _ProfileHistoryScreenState();
}

class _ProfileHistoryScreenState extends ConsumerState<ProfileHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load exercises/professions if not already cached
      ref.read(exerciseProvider.notifier).loadExercises();
      ref.read(professionProvider.notifier).loadProfessions();

      final userId = ref.read(authProvider).userId ?? '';
      if (userId.isNotEmpty) {
        ref.read(profileHistoryProvider.notifier).loadHistory(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(profileHistoryProvider);
    final exerciseGroups = ref.watch(exerciseProvider).exercises;
    final professionGroups = ref.watch(professionProvider).professions;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile Update History',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.semiBold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(historyState, exerciseGroups, professionGroups),
    );
  }

  Widget _buildBody(
    ProfileHistoryState state,
    List<ExerciseGroup> exerciseGroups,
    List<ProfessionGroup> professionGroups,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 56, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: AppTypography.fontSize14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  final userId = ref.read(authProvider).userId ?? '';
                  ref.read(profileHistoryProvider.notifier).loadHistory(userId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.histories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 72, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text(
              'No history found',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: AppTypography.fontSize16,
                fontWeight: AppTypography.medium,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your profile update history will appear here.',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: AppTypography.fontSize13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: state.histories.length,
        itemBuilder: (context, index) {
          final entry = state.histories[index];
          final isLast = index == state.histories.length - 1;
          return _TimelineItem(
            entry: entry,
            isLast: isLast,
            exerciseGroups: exerciseGroups,
            professionGroups: professionGroups,
          );
        },
      ),
    );
  }
}

// ─── Timeline item ──────────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  final ProfileHistory entry;
  final bool isLast;
  final List<ExerciseGroup> exerciseGroups;
  final List<ProfessionGroup> professionGroups;

  const _TimelineItem({
    required this.entry,
    required this.isLast,
    required this.exerciseGroups,
    required this.professionGroups,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.lightGreen.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Card content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: _HistoryCard(
                entry: entry,
                exerciseGroups: exerciseGroups,
                professionGroups: professionGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── History card ────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final ProfileHistory entry;
  final List<ExerciseGroup> exerciseGroups;
  final List<ProfessionGroup> professionGroups;

  const _HistoryCard({
    required this.entry,
    required this.exerciseGroups,
    required this.professionGroups,
  });

  /// Resolve MongoDB _id → profession display name
  String? _resolveProfessionName(String? groupId) {
    if (groupId == null || groupId.isEmpty) return null;
    final match = professionGroups.where((p) => p.id == groupId).toList();
    return match.isNotEmpty ? match.first.professionGroup : null;
  }

  @override
  Widget build(BuildContext context) {
    final changes = entry.changes;
    final professionName = _resolveProfessionName(changes.professionGroupId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header — date + source badge
          _buildHeader(),
          const Divider(height: 1, color: AppColors.dividerColor),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Physical Activity
                if (professionName != null) ...[
                  _sectionLabel('Physical Activity'),
                  const SizedBox(height: 6),
                  _ActivityChip(name: professionName),
                  const SizedBox(height: 14),
                ],

                // Nutritional targets
                if (changes.hasNutritionalData) ...[
                  _sectionLabel('Nutritional Targets'),
                  const SizedBox(height: 8),
                  _NutritionGrid(changes: changes),
                  const SizedBox(height: 14),
                ],

                // Exercises
                if (changes.exercises.isNotEmpty) ...[
                  _sectionLabel('Exercise'),
                  const SizedBox(height: 8),
                  ...changes.exercises.map(
                    (ex) => _ExerciseRow(
                      entry: ex,
                      exerciseGroups: exerciseGroups,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Digestive health
                _sectionLabel('Digestive Health'),
                const SizedBox(height: 6),
                _DigestiveChip(status: changes.digestiveStatus),
                const SizedBox(height: 14),

                // Special conditions
                if (changes.specialConditions.isNotEmpty) ...[
                  _sectionLabel('Health Conditions'),
                  const SizedBox(height: 8),
                  _ConditionTags(changes: changes),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final dt = entry.createdAt;
    final dateStr =
        '${_dayStr(dt.weekday)}, ${dt.day} ${_monthStr(dt.month)} ${dt.year}';
    final timeStr = _formatTime(dt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded,
              size: 14, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: AppTypography.fontSize13,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: AppTypography.fontSize10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          _SourceBadge(source: entry.source, role: entry.updatedByRole),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: AppTypography.fontSize10,
        fontWeight: AppTypography.semiBold,
        color: AppColors.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }

  String _dayStr(int wd) =>
      const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][wd];

  String _monthStr(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h % 12 == 0 ? 12 : h % 12;
    return '$displayH:$m $period';
  }
}

// ─── Source badge ─────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  final String source;
  final String role;

  const _SourceBadge({required this.source, required this.role});

  @override
  Widget build(BuildContext context) {
    final isNutritionist = role == 'nutritionist' || role == 'admin';
    final label = isNutritionist ? 'Nutritionist' : 'Self';
    final color =
        isNutritionist ? const Color(0xFF7B5EA7) : AppColors.primaryGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: AppTypography.fontSize10,
          fontWeight: AppTypography.semiBold,
          color: color,
        ),
      ),
    );
  }
}

// ─── Activity chip ────────────────────────────────────────────────────────────

class _ActivityChip extends StatelessWidget {
  final String name;
  const _ActivityChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.work_outline_rounded,
              size: 13, color: AppColors.primaryGreen),
          const SizedBox(width: 5),
          Text(
            name,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: AppTypography.fontSize12,
              fontWeight: AppTypography.medium,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Nutrition grid ───────────────────────────────────────────────────────────

class _NutritionGrid extends StatelessWidget {
  final ProfileHistoryChanges changes;

  const _NutritionGrid({required this.changes});

  @override
  Widget build(BuildContext context) {
    final items = <_NutrientInfo>[];

    if (changes.targetKCalories != null) {
      items.add(_NutrientInfo(
        label: 'Calories',
        value: '${changes.targetKCalories!.toStringAsFixed(0)} kcal',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFE57373),
      ));
    }
    if (changes.targetProtein != null) {
      items.add(_NutrientInfo(
        label: 'Protein',
        value: '${changes.targetProtein!.toStringAsFixed(1)} g',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFF64B5F6),
      ));
    }
    if (changes.targetFat != null) {
      items.add(_NutrientInfo(
        label: 'Fat',
        value: '${changes.targetFat!.toStringAsFixed(1)} g',
        icon: Icons.opacity_rounded,
        color: const Color(0xFFFFB74D),
      ));
    }
    if (changes.targetCarbs != null) {
      items.add(_NutrientInfo(
        label: 'Carbs',
        value: '${changes.targetCarbs!.toStringAsFixed(1)} g',
        icon: Icons.grain_rounded,
        color: const Color(0xFF81C784),
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((info) => _NutrientChip(info: info)).toList(),
    );
  }
}

class _NutrientInfo {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _NutrientInfo({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _NutrientChip extends StatelessWidget {
  final _NutrientInfo info;
  const _NutrientChip({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: info.color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 13, color: info.color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.label,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: AppTypography.fontSize10,
                  color: info.color.withValues(alpha: 0.8),
                  fontWeight: AppTypography.medium,
                ),
              ),
              Text(
                info.value,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.semiBold,
                  color: info.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Exercise row ─────────────────────────────────────────────────────────────

class _ExerciseRow extends StatelessWidget {
  final HistoryExerciseEntry entry;
  final List<ExerciseGroup> exerciseGroups;

  const _ExerciseRow({required this.entry, required this.exerciseGroups});

  /// Resolve MongoDB _id → exercise display name
  String get _displayName {
    final match =
        exerciseGroups.where((g) => g.id == entry.exerciseGroupId).toList();
    return match.isNotEmpty ? match.first.exerciseGroup : entry.exerciseGroupId;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              _displayName,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: AppTypography.fontSize13,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _miniTag(
            '${entry.daysPerWeek}d/wk',
            AppColors.primaryGreen.withValues(alpha: 0.1),
            AppColors.primaryGreen,
          ),
          const SizedBox(width: 4),
          _miniTag(
            '${entry.hoursPerDay}h/day',
            AppColors.darkGreen.withValues(alpha: 0.1),
            AppColors.darkGreen,
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: AppTypography.fontSize10,
          fontWeight: AppTypography.semiBold,
          color: fg,
        ),
      ),
    );
  }
}

// ─── Digestive chip ───────────────────────────────────────────────────────────

class _DigestiveChip extends StatelessWidget {
  final String status;
  const _DigestiveChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isNone = status == 'None';
    final color = isNone ? AppColors.textTertiary : const Color(0xFFE57373);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: AppTypography.fontSize12,
          fontWeight: AppTypography.medium,
          color: color,
        ),
      ),
    );
  }
}

// ─── Condition tags ───────────────────────────────────────────────────────────

class _ConditionTags extends StatelessWidget {
  final ProfileHistoryChanges changes;
  const _ConditionTags({required this.changes});

  @override
  Widget build(BuildContext context) {
    final active = changes.activeConditionCodes;
    final all = changes.specialConditions;

    if (all.isEmpty) {
      return const Text(
        'None',
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: AppTypography.fontSize13,
          color: AppColors.textTertiary,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: all.map((c) {
        final isActive = active.contains(c.code);
        final color =
            isActive ? const Color(0xFF7B5EA7) : AppColors.textTertiary;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 11,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                c.code.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: AppTypography.fontSize10,
                  fontWeight: AppTypography.semiBold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
