package com.eremat.greengains.util

/**
 * Single source of truth for SharedPreferences keys used across native Kotlin and Flutter.
 *
 * Flutter writes to "FlutterSharedPreferences" via the shared_preferences package.
 * The Flutter shared_preferences plugin adds a "flutter." prefix to all keys,
 * so Flutter key "flutter.tracking_paused" is stored as "flutter.flutter.tracking_paused".
 * All native Kotlin code reads from the same store using the full double-prefixed keys.
 */
object AppPrefs {

    /** SharedPreferences file name — Flutter's shared_preferences package uses this name. */
    const val NAME = "FlutterSharedPreferences"

    // ── Service state ────────────────────────────────────────────────────────

    /** Whether the foreground service should auto-restart after reboot. */
    const val FOREGROUND_ENABLED = "flutter.flutter.foreground_service_enabled"

    /** Whether the user has paused tracking (service stays alive but stops collecting). */
    const val TRACKING_PAUSED = "flutter.flutter.tracking_paused"

    // ── Privacy ──────────────────────────────────────────────────────────────

    /** Whether the user has consented to location sharing in uploads. */
    const val SHARE_LOCATION = "flutter.flutter.share_location"

    /** Whether uploads are allowed on mobile data (false = WiFi only). */
    const val USE_MOBILE_DATA = "flutter.flutter.use_mobile_data_uploads"

    // ── Identity ─────────────────────────────────────────────────────────────

    /** Persistent device identifier (UUID v4, generated once per install). */
    const val DEVICE_ID = "flutter.flutter.device_id"

    /** Per-device HMAC secret for payload signing. */
    const val DEVICE_SECRET = "flutter.flutter.device_secret"

    /** Firebase ID token, refreshed by Flutter and read by native uploader. */
    const val FIREBASE_AUTH_TOKEN = "flutter.flutter.firebase_auth_token"

    // ── Backend config ───────────────────────────────────────────────────────
    // NOTE: These are written by Flutter's main.dart via direct SharedPreferences calls,
    // NOT via AppPreferences.instance, so they only get one "flutter." prefix (from the plugin).

    /** Backend base URL (falls back to hardcoded prod URL if absent). */
    const val BACKEND_URL = "flutter.backend_url"

    /** Legacy API key for device→backend authentication. */
    const val BACKEND_API_KEY = "flutter.backend_api_key"

    // ── Upload tracking ──────────────────────────────────────────────────────

    /** ISO 8601 timestamp of the last successful upload, shown in the notification. */
    const val LAST_UPLOAD_AT = "flutter.flutter.last_upload_at"
}
