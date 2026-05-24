/// Parsed response from /api/app-version.
class AppVersionModel {
  final String platform;
  final String latestVersion;
  final String minRequiredVersion;
  final String releaseNotes;
  final String updateUrl;

  /// 'force' → user must update before using the app.
  /// 'none'  → update is optional.
  final String updateType;

  const AppVersionModel({
    required this.platform,
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.releaseNotes,
    required this.updateUrl,
    required this.updateType,
  });

  bool get isForceUpdate => updateType == 'force';

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return AppVersionModel(
      platform: data['platform'] as String? ?? '',
      latestVersion: data['latestVersion'] as String? ?? '',
      minRequiredVersion: data['minRequiredVersion'] as String? ?? '',
      releaseNotes: data['releaseNotes'] as String? ?? '',
      updateUrl: data['updateUrl'] as String? ?? '',
      updateType: data['updateType'] as String? ?? 'none',
    );
  }
}
