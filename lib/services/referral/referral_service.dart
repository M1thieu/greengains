import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../network/backend_client.dart';

class ReferralService {
  ReferralService._();

  static final ReferralService instance = ReferralService._();

  /// Fetch the current user's stable referral code.
  Future<String?> fetchReferralCode() async {
    try {
      final response = await BackendClient.get('/api/v1/referrals/code');
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final code = body['referralCode']?.toString();
      if (code == null || code.isEmpty) return null;
      return code;
    } catch (e) {
      debugPrint('Referral code fetch failed: $e');
      return null;
    }
  }

  /// Log that the user shared their referral link.
  Future<void> registerReferralInvite({
    required String referralCode,
  }) async {
    try {
      await BackendClient.post(
        '/api/v1/referrals/invite',
        {'referralCode': referralCode},
      );
    } catch (e) {
      // Non-critical — never block the copy action
      debugPrint('Referral invite log failed (non-critical): $e');
    }
  }

  /// Fetch the current user's referral stats (invites shared, conversions).
  /// Returns null on error — callers should handle gracefully.
  Future<({int invitesShared, int conversions})?> fetchStats() async {
    try {
      final response = await BackendClient.get('/api/v1/referrals/stats');
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        invitesShared: (body['invitesShared'] as num?)?.toInt() ?? 0,
        conversions: (body['conversions'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('Referral stats fetch failed: $e');
      return null;
    }
  }

  /// Log that a new user signed up via a referral link.
  Future<void> registerReferralOpen({
    required String referralCode,
  }) async {
    try {
      await BackendClient.post(
        '/api/v1/referrals/convert',
        {'referralCode': referralCode},
      );
    } catch (e) {
      debugPrint('Referral convert log failed (non-critical): $e');
    }
  }
}
