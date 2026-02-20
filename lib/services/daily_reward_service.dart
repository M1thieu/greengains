import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/models/daily_reward.dart';
import 'network/backend_client.dart';

/// Daily reward service - server-authoritative to prevent cheating
///
/// Anti-cheat measures:
/// - Server time used for all date comparisons
/// - Rewards tied to Firebase user ID (not device)
/// - Once-per-UTC-day rule enforced on backend
/// - Soft streak: miss 1 day = pause, miss 2+ days = reset
class DailyRewardService {
  static final DailyRewardService _instance = DailyRewardService._();
  static DailyRewardService get instance => _instance;
  DailyRewardService._();

  final _rewardNotifier = ValueNotifier<DailyReward?>(null);
  ValueListenable<DailyReward?> get reward => _rewardNotifier;

  bool _isInitialized = false;

  /// Initialize and fetch current reward state
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('DailyReward: No user logged in, skipping');
        return;
      }

      await fetchRewardState();
      _isInitialized = true;
    } catch (e) {
      debugPrint('DailyReward: Failed to initialize: $e');
    }
  }

  /// Fetch current reward state from backend
  Future<void> fetchRewardState() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await BackendClient.get('/daily-reward');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _rewardNotifier.value = DailyReward.fromJson(data);
      } else {
        debugPrint('DailyReward: Failed to fetch state: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('DailyReward: Error fetching reward state: $e');
    }
  }

  /// Claim today's reward (if eligible)
  /// Returns true if successful, false if already claimed or error
  Future<bool> claimReward() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('DailyReward: Cannot claim - no user logged in');
        return false;
      }

      final current = _rewardNotifier.value;
      if (current != null && !current.canClaimToday) {
        debugPrint('DailyReward: Already claimed today');
        return false;
      }

      final response = await BackendClient.post('/daily-reward/claim', {});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _rewardNotifier.value = DailyReward.fromJson(data);
        debugPrint('DailyReward: Claimed successfully! +${data['reward_amount']} credits');
        return true;
      } else if (response.statusCode == 409) {
        // Already claimed today (race condition)
        debugPrint('DailyReward: Already claimed (race condition)');
        await fetchRewardState(); // Refresh state
        return false;
      } else {
        debugPrint('DailyReward: Failed to claim: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('DailyReward: Error claiming reward: $e');
      return false;
    }
  }

  /// Check if should show daily reward notification
  /// Call this on app startup
  Future<bool> shouldShowDailyRewardNotification() async {
    await fetchRewardState();
    final current = _rewardNotifier.value;
    return current != null && current.canClaimToday;
  }

  void dispose() {
    _rewardNotifier.dispose();
  }
}
