import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/medical_record_model.dart';
import '../../provider/medical_record_provider.dart';
import '../../repository/medical_record_repository.dart';
import '../screens/document_viewer_screen.dart';

/// Prescription / medical-record upload + history.
///
/// Pick up to [MedicalRecordRepository.maxDocuments] images, add optional
/// notes, and POST them as multipart to `/api/user/medical-records`. Already
/// uploaded records are listed below and open in an external viewer on tap.
class PrescriptionUploadSection extends ConsumerStatefulWidget {
  const PrescriptionUploadSection({super.key, this.consultationId});

  /// Optional consultation this prescription belongs to.
  final String? consultationId;

  @override
  ConsumerState<PrescriptionUploadSection> createState() =>
      _PrescriptionUploadSectionState();
}

class _PrescriptionUploadSectionState
    extends ConsumerState<PrescriptionUploadSection> {
  static const int _maxFiles = MedicalRecordRepository.maxDocuments;

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _notesController = TextEditingController();
  final List<File> _pending = [];
  MedicalRecordType _recordType = MedicalRecordType.prescription;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _remainingSlots => _maxFiles - _pending.length;

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.errorColor : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickFrom(ImageSource source) async {
    if (_remainingSlots <= 0) {
      _snack('You can attach up to $_maxFiles documents.', error: true);
      return;
    }
    try {
      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final shot = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        picked = shot == null ? const [] : [shot];
      } else {
        picked = await _picker.pickMultiImage(imageQuality: 85);
      }
      if (picked.isEmpty || !mounted) return;

      // Respect the server cap; tell the user if we had to trim.
      final accepted = picked.take(_remainingSlots).toList();
      setState(() => _pending.addAll(accepted.map((x) => File(x.path))));

      if (picked.length > accepted.length) {
        _snack('Only $_maxFiles documents can be attached at once.',
            error: true);
      }
    } catch (_) {
      _snack('Could not open your photos. Please try again.', error: true);
    }
  }

  void _showPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSizes.spacing12),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppColors.primaryGreen),
              title: const Text('Take a photo',
                  style: TextStyle(fontFamily: 'Lato')),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickFrom(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primaryGreen),
              title: const Text('Choose from gallery',
                  style: TextStyle(fontFamily: 'Lato')),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickFrom(ImageSource.gallery);
              },
            ),
            const SizedBox(height: AppSizes.spacing8),
          ],
        ),
      ),
    );
  }

  Future<void> _upload() async {
    if (_pending.isEmpty) return;
    final ok = await ref.read(medicalRecordUploadProvider.notifier).upload(
          documents: _pending,
          recordType: _recordType,
          notes: _notesController.text,
          consultationId: widget.consultationId,
        );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _pending.clear();
        _notesController.clear();
      });
      _snack('Prescription uploaded successfully.');
    } else {
      _snack(
        ref.read(medicalRecordUploadProvider).error ??
            'Upload failed. Please try again.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUploading =
        ref.watch(medicalRecordUploadProvider.select((s) => s.isUploading));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prescriptions & medical records',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Color(0xFF2B292A),
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Upload up to $_maxFiles documents so your nutritionist can review them.',
          style: TextStyle(
            fontSize: AppTypography.fontSize12,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),

        // ── Record type ──
        Wrap(
          spacing: AppSizes.spacing8,
          runSpacing: AppSizes.spacing8,
          children: [
            for (final type in MedicalRecordType.values)
              _TypeChip(
                label: type.label,
                selected: _recordType == type,
                onTap: isUploading
                    ? null
                    : () => setState(() => _recordType = type),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.spacing12),

        // ── Attach tile ──
        _AttachTile(
          count: _pending.length,
          max: _maxFiles,
          onTap: isUploading || _remainingSlots <= 0 ? null : _showPickerSheet,
        ),

        // ── Selected files ──
        if (_pending.isNotEmpty) ...[
          const SizedBox(height: AppSizes.spacing12),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pending.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSizes.spacing8),
              itemBuilder: (_, i) => _PendingThumb(
                file: _pending[i],
                onRemove: isUploading
                    ? null
                    : () => setState(() => _pending.removeAt(i)),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),

          // ── Notes ──
          TextField(
            controller: _notesController,
            enabled: !isUploading,
            minLines: 1,
            maxLines: 3,
            maxLength: 300,
            style: const TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
            decoration: InputDecoration(
              hintText: 'Add a note (optional)',
              counterText: '',
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                fontFamily: 'Lato',
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing16, vertical: AppSizes.spacing12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius4),
                borderSide: const BorderSide(
                    color: AppColors.borderColor, width: AppSizes.borderNormal),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius4),
                borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: AppSizes.borderMedium),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),

          // ── Upload CTA ──
          SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: isUploading ? null : _upload,
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
              icon: isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded,
                      size: AppSizes.icon20),
              label: Text(
                isUploading
                    ? 'Uploading…'
                    : 'Upload ${_pending.length} '
                        '${_pending.length == 1 ? 'document' : 'documents'}',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.bold,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSizes.spacing20),
        const _UploadedRecordsList(),
      ],
    );
  }
}

/// Previously uploaded records (GET /api/user/medical-records).
class _UploadedRecordsList extends ConsumerWidget {
  const _UploadedRecordsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(medicalRecordsProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.spacing16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryGreen),
          ),
        ),
      ),
      error: (_, __) => Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: AppSizes.icon18, color: AppColors.errorColor),
          const SizedBox(width: AppSizes.spacing8),
          const Expanded(
            child: Text(
              'Could not load your records.',
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(medicalRecordsProvider),
            child: const Text('Retry',
                style: TextStyle(
                    fontFamily: 'Lato', color: AppColors.primaryGreen)),
          ),
        ],
      ),
      data: (records) {
        if (records.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uploaded (${records.length})',
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing8),
            for (final record in records)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
                child: _RecordCard(record: record),
              ),
          ],
        );
      },
    );
  }
}

class _RecordCard extends ConsumerWidget {
  const _RecordCard({required this.record});

  final MedicalRecord record;

  static const _months = [
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

  String get _dateLabel {
    final d = record.createdAt;
    if (d == null) return '';
    final local = d.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this record?',
            style:
                TextStyle(fontFamily: 'Lato', fontWeight: AppTypography.bold)),
        content: Text(
          'This will permanently remove "${record.recordType.label}" and its '
          '${record.documents.length} '
          '${record.documents.length == 1 ? 'document' : 'documents'}.',
          style: const TextStyle(fontFamily: 'Lato'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep', style: TextStyle(fontFamily: 'Lato')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style:
                    TextStyle(fontFamily: 'Lato', color: AppColors.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok =
        await ref.read(medicalRecordDeleteProvider.notifier).delete(record.id);
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? 'Record deleted.' : 'Could not delete this record.'),
      backgroundColor: ok ? AppColors.primaryGreen : AppColors.errorColor,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = record.documents;
    final deleting = ref.watch(medicalRecordDeleteProvider).contains(record.id);

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
                child: const Icon(Icons.description_rounded,
                    size: AppSizes.icon16, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: AppSizes.spacing8),
              Expanded(
                child: Text(
                  record.recordType.label,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
              if (_dateLabel.isNotEmpty)
                Text(
                  _dateLabel,
                  style: TextStyle(
                    fontSize: AppTypography.fontSize10,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontFamily: 'Lato',
                  ),
                ),
              const SizedBox(width: AppSizes.spacing4),
              // Delete this record.
              deleting
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.errorColor),
                      ),
                    )
                  : GestureDetector(
                      onTap: () => _confirmAndDelete(context, ref),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline_rounded,
                            size: AppSizes.icon18, color: AppColors.errorColor),
                      ),
                    ),
            ],
          ),
          if (record.notes.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spacing6),
            Text(
              record.notes,
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontFamily: 'Lato',
                height: 1.35,
              ),
            ),
          ],
          if (docs.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spacing8),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSizes.spacing8),
                itemBuilder: (_, i) => _DocThumb(doc: docs[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Remote document preview — image thumbnail, or a PDF/file placeholder.
class _DocThumb extends StatelessWidget {
  const _DocThumb({required this.doc});

  final MedicalRecordDocument doc;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (doc.url.trim().isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DocumentViewerScreen(
              url: doc.url,
              title: doc.fileName.isEmpty ? 'Document' : doc.fileName,
              isPdf: doc.isPdf,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        child: Container(
          width: 64,
          height: 64,
          color: AppColors.borderColor.withValues(alpha: 0.25),
          child: doc.isPdf
              ? const Center(
                  child: Icon(Icons.picture_as_pdf_rounded,
                      color: AppColors.errorColor, size: AppSizes.icon24),
                )
              : Image.network(
                  doc.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.insert_drive_file_rounded,
                        color: AppColors.textSecondary, size: AppSizes.icon24),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Locally picked file awaiting upload.
class _PendingThumb extends StatelessWidget {
  const _PendingThumb({required this.file, this.onRemove});

  final File file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          child: Image.file(
            file,
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 88,
              height: 88,
              color: AppColors.borderColor.withValues(alpha: 0.25),
              child: const Icon(Icons.insert_drive_file_rounded,
                  color: AppColors.textSecondary),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.errorColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({required this.count, required this.max, this.onTap});

  final int count;
  final int max;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final full = count >= max;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing16),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: full ? 0.2 : 0.5),
          ),
        ),
        child: Column(
          children: [
            Icon(
              full ? Icons.check_circle_rounded : Icons.add_a_photo_rounded,
              color: full
                  ? AppColors.primaryGreen.withValues(alpha: 0.5)
                  : AppColors.primaryGreen,
              size: AppSizes.icon24,
            ),
            const SizedBox(height: AppSizes.spacing6),
            Text(
              full ? 'Maximum $max documents attached' : 'Attach documents',
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.semiBold,
                color: AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count of $max selected',
              style: TextStyle(
                fontSize: AppTypography.fontSize10,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing12, vertical: AppSizes.spacing6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : AppColors.borderColor,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.fontSize12,
            fontWeight: AppTypography.semiBold,
            color: selected ? Colors.white : AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
      ),
    );
  }
}
