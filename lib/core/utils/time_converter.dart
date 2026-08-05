import 'package:intl/intl.dart';

String convertMongoUtcToIst(dynamic mongoTimestamp) {
  DateTime utcDateTime;

  if (mongoTimestamp is String) {
    // Example: "2026-06-11T10:30:00.000Z"
    utcDateTime = DateTime.parse(mongoTimestamp).toUtc();
  } else if (mongoTimestamp is DateTime) {
    utcDateTime = mongoTimestamp.toUtc();
  } else if (mongoTimestamp is int) {
    // If timestamp is in milliseconds
    utcDateTime = DateTime.fromMillisecondsSinceEpoch(
      mongoTimestamp,
      isUtc: true,
    );
  } else {
    throw ArgumentError('Invalid MongoDB timestamp format');
  }

  // IST = UTC + 5 hours 30 minutes
  final DateTime istDateTime = utcDateTime.add(
    const Duration(hours: 5, minutes: 30),
  );

  return DateFormat('dd MMM yyyy, hh:mm a').format(istDateTime);
}

String convertMongoUtcToIstExceptTime(dynamic mongoTimestamp) {
  DateTime utcDateTime;

  if (mongoTimestamp is String) {
    // Example: "2026-06-11T10:30:00.000Z"
    utcDateTime = DateTime.parse(mongoTimestamp).toUtc();
  } else if (mongoTimestamp is DateTime) {
    utcDateTime = mongoTimestamp.toUtc();
  } else if (mongoTimestamp is int) {
    // If timestamp is in milliseconds
    utcDateTime = DateTime.fromMillisecondsSinceEpoch(
      mongoTimestamp,
      isUtc: true,
    );
  } else {
    throw ArgumentError('Invalid MongoDB timestamp format');
  }

  // IST = UTC + 5 hours 30 minutes
  final DateTime istDateTime = utcDateTime.add(
    const Duration(hours: 5, minutes: 30),
  );

  return DateFormat('dd MMM yyyy').format(istDateTime);
}