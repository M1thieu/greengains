import 'package:flutter/foundation.dart';
import '../network/backend_client.dart';

class ReferralService {
  ReferralService._();

  static final ReferralService instance = ReferralService._();

  /// Log that the user shared their referral link.
  Future<void> registerReferralInvite({
    required String referralCode,
    required String inviterUid,
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

  /// Log that a new user signed up via a referral link.
  Future<void> registerReferralOpen({
    required String referralCode,
    required String inviteeUid,
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
