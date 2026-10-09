package com.eremat.greengains.service.sensors

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.GnssStatus
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Satellite signal statistics, sent raw as extra `aux` channels for an experimental
 * sky-obstruction index. Under tree canopy C/N0 drops 4-5 dB-Hz against open sky
 * (Tomaštík & Everett 2023), but single readings mix in multipath, phone model and body
 * attenuation, and no study has validated the index for pocketed phones, so nothing here
 * is shown to the user.
 *
 * - `gnss_cn0_top4`: mean C/N0 (dB-Hz) of the four strongest satellites.
 * - `gnss_used`, `gnss_visible`: satellites used in the fix and seen.
 *
 * Only listens: it never asks for GNSS, so it costs nothing while the fused provider is not
 * using it (full GNSS tracking disables duty cycling and drains the battery). Needs the fine
 * location permission the app already holds.
 */
class GnssChannels(private val context: Context) {

    private val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
    private val cn0Top4 = ArrayList<Float>()
    private val used = ArrayList<Float>()
    private val visible = ArrayList<Float>()
    private var registered = false

    private val callback = object : GnssStatus.Callback() {
        override fun onSatelliteStatusChanged(status: GnssStatus) {
            val strengths = ArrayList<Float>(status.satelliteCount)
            var inFix = 0
            for (i in 0 until status.satelliteCount) {
                val cn0 = status.getCn0DbHz(i)
                if (cn0 > 0f) strengths.add(cn0)
                if (status.usedInFix(i)) inFix++
            }
            synchronized(this@GnssChannels) {
                if (strengths.isNotEmpty()) {
                    cn0Top4.add(strengths.sortedDescending().take(4).average().toFloat())
                }
                used.add(inFix.toFloat())
                visible.add(status.satelliteCount.toFloat())
            }
        }
    }

    @Synchronized
    fun start() {
        if (registered) return
        val lm = locationManager ?: return
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) return
        registered = try {
            lm.registerGnssStatusCallback(callback, Handler(Looper.getMainLooper()))
        } catch (e: SecurityException) {
            Log.w(TAG, "GNSS status refused: ${e.message}")
            false
        }
    }

    @Synchronized
    fun stop() {
        if (!registered) return
        locationManager?.unregisterGnssStatusCallback(callback)
        registered = false
        cn0Top4.clear(); used.clear(); visible.clear()
    }

    /** Medians over the window since the last call; empty when GNSS was not active. */
    @Synchronized
    fun drain(): Map<String, Float> {
        val out = HashMap<String, Float>()
        medianOf(cn0Top4)?.let { out["gnss_cn0_top4"] = it }
        medianOf(used)?.let { out["gnss_used"] = it }
        medianOf(visible)?.let { out["gnss_visible"] = it }
        cn0Top4.clear(); used.clear(); visible.clear()
        return out
    }

    private companion object {
        const val TAG = "GreenGainsGnss"
    }
}
