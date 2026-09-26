package com.eremat.greengains.service

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.eremat.greengains.util.AppPrefs
import java.util.concurrent.atomic.AtomicLong

/** Coarse link type. Deliberately no SSID, BSSID or cell identity is ever read. */
enum class NetTransport(val wire: String) {
    NONE("none"), WIFI("wifi"), CELLULAR("cellular"), ETHERNET("ethernet"), VPN("vpn"), OTHER("other"),
}

/**
 * Immutable picture of the system's default network, built only from [NetworkCapabilities].
 *
 * [epoch] increments whenever the default network, its transport or its validated state
 * changes, so a caller can tell whether the network moved underneath an in-flight request.
 */
data class NetworkSnapshot(
    val transport: NetTransport,
    val validated: Boolean,
    val metered: Boolean,
    val roaming: Boolean,
    val downKbps: Int,
    val upKbps: Int,
    val epoch: Long,
) {
    /** True only when the system has verified this network actually reaches the internet. */
    val usable: Boolean get() = transport != NetTransport.NONE && validated
}

/**
 * Tracks the system's DEFAULT network and decides whether an upload may go out.
 *
 * Design follows the Android "Read network state" guidance:
 *  - Track the default network (registerDefaultNetworkCallback), so a Wi-Fi <-> cellular
 *    handoff is one event rather than two unrelated networks coming and going.
 *  - Build state from onCapabilitiesChanged, never by polling activeNetwork inside a
 *    callback (racy mid-handoff).
 *  - Gate on NET_CAPABILITY_VALIDATED, not NET_CAPABILITY_INTERNET: INTERNET only says the
 *    network is *set up* for internet, a captive portal or dead Wi-Fi still has it.
 *  - Judge data cost by NET_CAPABILITY_NOT_METERED, not by "is it Wi-Fi": a phone hotspot
 *    is Wi-Fi but metered.
 *
 * Cellular generation (2G/3G/4G/5G) is intentionally NOT collected: it needs
 * READ_PHONE_STATE, a dangerous permission that also exposes the phone number.
 */
class NetworkStateMonitor(private val context: Context) {
    companion object {
        private const val TAG = "NetworkStateMonitor"
        private const val NOT_UNUSABLE = -1L
    }

    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    @Volatile private var snapshot = NetworkSnapshot(NetTransport.NONE, false, true, false, 0, 0, 0)
    private var currentNetwork: Network? = null
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var seededOnce = false

    // Cumulative and monotonic: consumers diff against their own baseline, so a failed
    // upload never loses telemetry.
    private val transitionsTotal = AtomicLong(0)
    private val unusableMsTotal = AtomicLong(0)
    @Volatile private var unusableSinceMs = SystemClock.elapsedRealtime()

    /** Called on every default-network / transport / validation change. */
    @Volatile var transitionListener: ((from: NetworkSnapshot, to: NetworkSnapshot) -> Unit)? = null

    fun startMonitoring() {
        seedFromActiveNetwork()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        if (callback != null) return

        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // API 26+ delivers onCapabilitiesChanged immediately after this. Before that
                // it may not, so read the capabilities of THIS network (never activeNetwork,
                // which can still be the old one mid-handoff).
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    apply(network, connectivityManager.getNetworkCapabilities(network))
                }
            }

            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                apply(network, caps)
            }

            override fun onLost(network: Network) {
                // A handoff can deliver a late onLost for a network we already moved off;
                // that must not clobber the new default.
                if (network == currentNetwork) apply(null, null)
            }
        }

        try {
            connectivityManager.registerDefaultNetworkCallback(cb)
            callback = cb
            Log.i(TAG, "Default-network monitoring started: ${describe(snapshot)}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register default network callback", e)
        }
    }

    fun stopMonitoring() {
        callback?.let {
            try {
                connectivityManager.unregisterNetworkCallback(it)
                Log.i(TAG, "Network monitoring stopped")
            } catch (e: IllegalArgumentException) {
                Log.w(TAG, "Network callback was not registered", e)
            }
        }
        callback = null
        // Stop counting "unusable" time while nobody is listening; start() re-seeds.
        trackUnusable(nextUsable = true)
    }

    fun snapshot(): NetworkSnapshot = snapshot

    fun transitionCount(): Long = transitionsTotal.get()

    fun unusableMs(): Long {
        val since = unusableSinceMs
        val open = if (since == NOT_UNUSABLE) 0L else SystemClock.elapsedRealtime() - since
        return unusableMsTotal.get() + open
    }

    /**
     * Whether an upload may go out right now:
     *  - the network must be VALIDATED (verified internet, not a captive portal / dead Wi-Fi);
     *  - if the user turned mobile uploads off, neither cellular nor any metered network
     *    (e.g. a phone hotspot) is allowed.
     */
    fun isUploadAllowed(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) seedFromActiveNetwork()

        val s = snapshot
        if (!s.usable) {
            Log.d(TAG, "Upload not allowed: no validated network (${describe(s)})")
            return false
        }

        val allowMobile = context.getSharedPreferences(AppPrefs.NAME, Context.MODE_PRIVATE)
            .getBoolean(AppPrefs.USE_MOBILE_DATA, true)
        if (!allowMobile && (s.transport == NetTransport.CELLULAR || s.metered)) {
            Log.d(TAG, "Upload not allowed: mobile uploads off and network is ${describe(s)}")
            return false
        }
        return true
    }

    private fun seedFromActiveNetwork() {
        val network = try { connectivityManager.activeNetwork } catch (e: Exception) { null }
        val caps = network?.let {
            try { connectivityManager.getNetworkCapabilities(it) } catch (e: Exception) { null }
        }
        apply(network, caps)
        if (!seededOnce) {
            // The first reading is a starting point, not a transition.
            transitionsTotal.set(0)
            seededOnce = true
        }
    }

    @Synchronized
    private fun apply(network: Network?, caps: NetworkCapabilities?) {
        val prev = snapshot
        val built = build(caps)
        val changed = network != currentNetwork ||
            built.transport != prev.transport ||
            built.validated != prev.validated

        currentNetwork = network
        val next = built.copy(epoch = if (changed) prev.epoch + 1 else prev.epoch)
        snapshot = next
        trackUnusable(next.usable)

        if (changed) {
            transitionsTotal.incrementAndGet()
            Log.i(TAG, "Network ${describe(prev)} -> ${describe(next)} (epoch ${next.epoch})")
            transitionListener?.invoke(prev, next)
        }
    }

    private fun build(caps: NetworkCapabilities?): NetworkSnapshot {
        if (caps == null) {
            return NetworkSnapshot(NetTransport.NONE, false, true, false, 0, 0, 0)
        }
        val transport = when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> NetTransport.WIFI
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> NetTransport.CELLULAR
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> NetTransport.ETHERNET
            caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> NetTransport.VPN
            else -> NetTransport.OTHER
        }
        return NetworkSnapshot(
            transport = transport,
            validated = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED),
            metered = !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED),
            roaming = !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_ROAMING),
            downKbps = caps.linkDownstreamBandwidthKbps.coerceAtLeast(0),
            upKbps = caps.linkUpstreamBandwidthKbps.coerceAtLeast(0),
            epoch = 0,
        )
    }

    private fun trackUnusable(nextUsable: Boolean) {
        val now = SystemClock.elapsedRealtime()
        if (nextUsable) {
            val since = unusableSinceMs
            if (since != NOT_UNUSABLE) {
                unusableMsTotal.addAndGet(now - since)
                unusableSinceMs = NOT_UNUSABLE
            }
        } else if (unusableSinceMs == NOT_UNUSABLE) {
            unusableSinceMs = now
        }
    }

    private fun describe(s: NetworkSnapshot): String {
        if (s.transport == NetTransport.NONE) return "none"
        val flags = buildList {
            add(if (s.validated) "validated" else "NOT-validated")
            add(if (s.metered) "metered" else "unmetered")
            if (s.roaming) add("roaming")
        }
        return "${s.transport.wire}(${flags.joinToString(",")})"
    }
}
