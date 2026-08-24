import 'package:intl/intl.dart';

/// Parses a MongoDB timestamp (ISO string, [DateTime], or epoch ms) to a UTC
/// [DateTime]. Returns null for empty/unparseable input instead of throwing.
DateTime? _parseMongoUtc(dynamic mongoTimestamp) {
  if (mongoTimestamp is String) {
    if (mongoTimestamp.trim().isEmpty) return null;
    return DateTime.tryParse(mongoTimestamp)?.toUtc();
  } else if (mongoTimestamp is DateTime) {
    return mongoTimestamp.toUtc();
  } else if (mongoTimestamp is int) {
    // If timestamp is in milliseconds
    return DateTime.fromMillisecondsSinceEpoch(mongoTimestamp, isUtc: true);
  }
  return null;
}

String convertMongoUtcToIst(dynamic mongoTimestamp) {
  final utcDateTime = _parseMongoUtc(mongoTimestamp);
  if (utcDateTime == null) return '';

  // IST = UTC + 5 hours 30 minutes
  final DateTime istDateTime = utcDateTime.add(
    const Duration(hours: 5, minutes: 30),
  );

  return DateFormat('dd MMM yyyy, hh:mm a').format(istDateTime);
}

String convertMongoUtcToIstExceptTime(dynamic mongoTimestamp) {
  final utcDateTime = _parseMongoUtc(mongoTimestamp);
  if (utcDateTime == null) return '';

  // IST = UTC + 5 hours 30 minutes
  final DateTime istDateTime = utcDateTime.add(
    const Duration(hours: 5, minutes: 30),
  );

  return DateFormat('dd MMM yyyy').format(istDateTime);
}
