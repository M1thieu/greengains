package com.eremat.greengains.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.util.Log
import com.eremat.greengains.util.AppPrefs

/**
 * Monitors network connectivity state and respects user preferences
 * for WiFi-only uploads.
 *
 * Prevents battery drain from repeated failed upload attempts when offline
 * or when user wants WiFi-only uploads.
 */
class NetworkStateMonitor(private val context: Context) {
    companion object {
        private const val TAG = "NetworkStateMonitor"
    }

    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var isConnected = false
    private var isWiFi = false

    /**
     * Start monitoring network state.
     */
    fun startMonitoring() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Use NetworkCallback API for Android 7.0+
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    updateNetworkState()
                    Log.i(TAG, "Network available: WiFi=$isWiFi")
                }

                override fun onLost(network: Network) {
                    isConnected = false
                    isWiFi = false
                    Log.i(TAG, "Network lost")
                }

                override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                    updateNetworkState()
                }
            }

            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()

            try {
                connectivityManager.registerNetworkCallback(request, networkCallback!!)
                updateNetworkState() // Get initial state
                Log.i(TAG, "Network monitoring started (API 24+)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to register network callback", e)
            }
        } else {
            // Fallback for older devices - just check current state
            updateNetworkState()
            Log.i(TAG, "Network monitoring started (legacy)")
        }
    }

    /**
     * Stop monitoring network state.
     */
    fun stopMonitoring() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            networkCallback?.let { callback ->
                try {
                    connectivityManager.unregisterNetworkCallback(callback)
                    Log.i(TAG, "Network monitoring stopped")
                } catch (e: IllegalArgumentException) {
                    Log.w(TAG, "Network callback was not registered", e)
                }
            }
        }
    }

    /**
     * Update current network state by querying ConnectivityManager.
     */
    private fun updateNetworkState() {
        val network = connectivityManager.activeNetwork
        val capabilities = network?.let { connectivityManager.getNetworkCapabilities(it) }

        isConnected = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        isWiFi = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true

        Log.d(TAG, "Network state: connected=$isConnected, WiFi=$isWiFi")
    }

    /**
     * Check if uploads should be allowed based on current network state
     * and user preferences.
     *
     * Returns true if:
     * - Connected to internet AND
     * - Either on WiFi OR user allows mobile uploads
     */
    fun isUploadAllowed(): Boolean {
        updateNetworkState() // Refresh state before check

        if (!isConnected) {
            Log.d(TAG, "Upload not allowed: no internet connection")
            return false
        }

        val prefs = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
        val allowMobile = prefs.getBoolean(AppPrefs.USE_MOBILE_DATA, true)

        return if (isWiFi) {
            // Always allow on WiFi
            true
        } else if (allowMobile) {
            // Allow on mobile data if user enabled it
            Log.d(TAG, "Upload allowed on mobile data (user preference)")
            true
        } else {
            // Block on mobile data if user wants WiFi-only
            Log.d(TAG, "Upload not allowed: WiFi-only mode enabled, currently on mobile data")
            false
        }
    }

    /**
     * Check if currently connected to any network.
     */
    fun isConnected(): Boolean {
        updateNetworkState()
        return isConnected
    }

    /**
     * Check if currently connected to WiFi.
     */
    fun isOnWiFi(): Boolean {
        updateNetworkState()
        return isWiFi
    }
}
