import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/utils/dev_log.dart';
import '../models/referral_model.dart';

/// Referral-code validation and the organisation members it unlocks.
class ReferralRepository {
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;

  ReferralRepository({
    required ApiClient apiClient,
    required LocalStorageService localStorage,
  })  : _apiClient = apiClient,
        _localStorage = localStorage;

  /// Attaches the token when one exists. These endpoints answer without auth,
  /// so a missing token is not an error — but a signed-in user's request stays
  /// attributable.
  Map<String, String> _headers() {
    final token = _localStorage.getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// POST /api/user/validate-referral-code.
  ///
  /// Throws a [NetworkException] carrying the server's own message for an
  /// unknown code ("Referral code not found or inactive.") or an empty one, so
  /// callers can surface it verbatim rather than inventing copy.
  Future<ReferralValidation> validateReferralCode(String referralCode) async {
    debugPrint('[ReferralRepository] Validating code: $referralCode');
    try {
      final json = await _apiClient.postJson(
        AppConfig.validateReferralCodePath,
        headers: _headers(),
        body: {'referralCode': referralCode},
      );
      devLog(() => '[ReferralRepository] Validate response: $json');
      return ReferralValidation.fromJson(json);
    } catch (e) {
      debugPrint('[ReferralRepository] Validate error: $e');
      throw NetworkException(
        message: ExceptionHandler.getErrorMessage(e),
        originalError: e,
      );
    }
  }

  /// GET /api/adm/organisation-members — members of [organisationId].
  ///
  /// The id comes straight from the validation response, so the organisations
  /// list endpoint is not needed to resolve it.
  Future<List<OrganisationMember>> getOrganisationMembers({
    required String organisationId,
  }) async {
    debugPrint('[ReferralRepository] Members for org: $organisationId');
    try {
      final json = await _apiClient.getJson(
        '${AppConfig.organisationMembersPath}'
        '?sort=name,asc&status=ACTIVE'
        '&organisationId=${Uri.encodeQueryComponent(organisationId)}',
        headers: _headers(),
      );
      devLog(() => '[ReferralRepository] Members response: $json');
      final members = OrganisationMember.listFromJson(json);

      // The endpoint filters server-side, but this re-checks it: a backend that
      // ignored the parameter would otherwise offer members of *every*
      // organisation, letting the user attribute their subscription to someone
      // unrelated to the code they entered. Showing none is the safe failure.
      final scoped = members
          .where((m) => m.organisationId == organisationId)
          .toList(growable: false);

      if (scoped.length != members.length) {
        debugPrint('[ReferralRepository] Dropped ${members.length - scoped.length}'
            ' member(s) belonging to another organisation');
      }
      debugPrint('[ReferralRepository] ${scoped.length} member(s)');
      return scoped;
    } catch (e) {
      debugPrint('[ReferralRepository] Members error: $e');
      throw NetworkException(
        message: ExceptionHandler.getErrorMessage(e),
        originalError: e,
      );
    }
  }
}
