// Models for medical records / prescriptions (/api/user/medical-records)

/// Record categories accepted by the API. `medical_record` is the server default.
enum MedicalRecordType {
  medicalRecord('medical_record', 'Medical record'),
  prescription('prescription', 'Prescription'),
  labReport('lab_report', 'Lab report'),
  other('other', 'Other');

  const MedicalRecordType(this.wire, this.label);

  /// Value sent to / received from the API.
  final String wire;

  /// Human-readable label for the UI.
  final String label;

  static MedicalRecordType parse(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    for (final t in MedicalRecordType.values) {
      if (t.wire == v) return t;
    }
    return MedicalRecordType.medicalRecord;
  }
}

/// A single uploaded document belonging to a record.
class MedicalRecordDocument {
  final String url;
  final String fileName;
  final String mimeType;

  const MedicalRecordDocument({
    required this.url,
    required this.fileName,
    required this.mimeType,
  });

  bool get isPdf =>
      mimeType.contains('pdf') || url.toLowerCase().endsWith('.pdf');

  factory MedicalRecordDocument.fromJson(Map<String, dynamic> json) {
    // The backend may name these differently across endpoints — accept the
    // common aliases rather than hard-failing on one shape.
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final url = pick(['url', 'fileUrl', 'documentUrl', 'path', 'location']);
    return MedicalRecordDocument(
      url: url,
      fileName:
          pick(['fileName', 'originalName', 'name', 'filename']).isNotEmpty
              ? pick(['fileName', 'originalName', 'name', 'filename'])
              : url.split('/').last,
      mimeType: pick(['mimeType', 'contentType', 'type', 'fileType']),
    );
  }

  /// Some responses return documents as bare URL strings.
  factory MedicalRecordDocument.fromUrl(String url) => MedicalRecordDocument(
        url: url,
        fileName: url.split('/').last,
        mimeType: '',
      );
}

class MedicalRecord {
  final String id;
  final MedicalRecordType recordType;
  final String notes;
  final List<MedicalRecordDocument> documents;
  final DateTime? createdAt;

  /// Who uploaded this record — "user", "nutritionist", etc. (from the API).
  final String uploaderRole;

  const MedicalRecord({
    required this.id,
    required this.recordType,
    required this.notes,
    required this.documents,
    this.createdAt,
    this.uploaderRole = '',
  });

  /// Only records the signed-in user uploaded can be deleted by them.
  bool get isOwnUpload => uploaderRole.toLowerCase() == 'user';

  /// Human-readable uploader, e.g. "You", "Nutritionist".
  String get uploaderLabel {
    switch (uploaderRole.toLowerCase()) {
      case 'user':
        return 'You';
      case '':
        return '';
      default:
        final w = uploaderRole.replaceAll('_', ' ');
        return '${w[0].toUpperCase()}${w.substring(1)}';
    }
  }

  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    final rawDocs = (json['documents'] ?? json['files'] ?? json['attachments'])
        as List<dynamic>?;

    return MedicalRecord(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      recordType: MedicalRecordType.parse(json['recordType'] as String?),
      notes: json['notes'] as String? ?? '',
      documents: rawDocs
              ?.map<MedicalRecordDocument?>((e) {
                if (e is String) return MedicalRecordDocument.fromUrl(e);
                if (e is Map<String, dynamic>) {
                  return MedicalRecordDocument.fromJson(e);
                }
                return null;
              })
              .whereType<MedicalRecordDocument>()
              .where((d) => d.url.isNotEmpty)
              .toList() ??
          const [],
      createdAt: DateTime.tryParse(
          (json['createdAt'] ?? json['uploadedAt'] ?? '') as String? ?? ''),
      uploaderRole:
          (json['uploaderRole'] ?? json['uploadedByRole'] ?? '') as String? ??
              '',
    );
  }
}

/// Envelope for both upload (POST) and list (GET).
class MedicalRecordsResponse {
  final bool success;
  final String message;
  final List<MedicalRecord> records;

  const MedicalRecordsResponse({
    required this.success,
    required this.message,
    required this.records,
  });

  factory MedicalRecordsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];

    // `data` may be a bare list, or a wrapper holding the list under one of a
    // few names, or (on upload) a single record object.
    List<dynamic> raw;
    if (data is List) {
      raw = data;
    } else if (data is Map<String, dynamic>) {
      final inner = data['records'] ??
          data['medicalRecords'] ??
          data['documents'] ??
          data['items'];
      raw = inner is List ? inner : [data];
    } else {
      raw = const [];
    }

    return MedicalRecordsResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      records: raw
          .whereType<Map<String, dynamic>>()
          .map(MedicalRecord.fromJson)
          .toList(),
    );
  }
}
