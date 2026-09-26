/// Result of POST /api/user/validate-referral-code.
///
/// Response shape:
/// ```json
/// { "data": { "referral": { "isOrganisation": true, "type": "ORGANISATION",
///   "id": "6ab...", "name": "O2", "referralCode": "O2026",
///   "subType": "Excercise" } } }
/// ```
/// An invalid code is a 404 (`Referral code not found or inactive.`) and an
/// empty one a 400, both of which surface as a thrown exception carrying the
/// server's message — so this model only ever represents a *valid* referral.
class ReferralValidation {
  /// Organisation id when [isOrganisation]; used to fetch its members.
  final String id;
  final String name;
  final String referralCode;

  /// 'ORGANISATION' and friends — kept raw for display/debugging.
  final String type;

  /// e.g. 'Excercise' — the organisation type name.
  final String subType;

  /// When true the user must additionally pick one of the organisation's
  /// members, whose id is sent as `consulterId`. When false the referral code
  /// stands alone and no member selection applies.
  final bool isOrganisation;

  const ReferralValidation({
    required this.id,
    required this.name,
    required this.referralCode,
    this.type = '',
    this.subType = '',
    this.isOrganisation = false,
  });

  factory ReferralValidation.fromJson(Map<String, dynamic> json) {
    // Accept either the wrapped `{data: {referral: {...}}}` payload or the
    // bare referral object, so a flattened response still parses.
    final data = json['data'];
    final referral = (data is Map<String, dynamic> ? data['referral'] : null) ??
        (data is Map<String, dynamic> ? data : null) ??
        json;
    final r = referral as Map<String, dynamic>;
    return ReferralValidation(
      id: r['id'] as String? ?? r['_id'] as String? ?? '',
      name: r['name'] as String? ?? '',
      referralCode: r['referralCode'] as String? ?? '',
      type: r['type'] as String? ?? '',
      subType: r['subType'] as String? ?? '',
      isOrganisation: r['isOrganisation'] as bool? ?? false,
    );
  }
}

/// A member of a referring organisation, from
/// GET /api/adm/organisation-members.
///
/// The chosen member's [id] is sent as `consulterId` on subscription create.
class OrganisationMember {
  final String id;
  final String name;
  final String organisationId;
  final String organisationName;
  final String organisationReferralCode;

  /// Free-text speciality, e.g. 'gym'. Shown as a subtitle when present.
  final String specialisation;
  final String mobile;
  final String email;

  const OrganisationMember({
    required this.id,
    required this.name,
    this.organisationId = '',
    this.organisationName = '',
    this.organisationReferralCode = '',
    this.specialisation = '',
    this.mobile = '',
    this.email = '',
  });

  factory OrganisationMember.fromJson(Map<String, dynamic> json) {
    return OrganisationMember(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      organisationId: json['organisationId'] as String? ?? '',
      organisationName: json['organisationName'] as String? ?? '',
      organisationReferralCode:
          json['organisationReferralCode'] as String? ?? '',
      specialisation: json['specialisation'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  /// Parses the `{ data: { items: [...] } }` list envelope these admin
  /// endpoints use, tolerating a bare list or a `data` array too.
  static List<OrganisationMember> listFromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final raw = data is Map<String, dynamic>
        ? (data['items'] ?? data['members'] ?? const [])
        : (data is List ? data : const []);
    return (raw as List)
        .whereType<Map<String, dynamic>>()
        .map(OrganisationMember.fromJson)
        .where((m) => m.id.isNotEmpty)
        .toList(growable: false);
  }
}
