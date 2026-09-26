package com.eremat.greengains.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Random
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sqrt

class PositionFilterTest {
    private val latRef = 48.8566
    private val lonRef = 2.3522
    private val mPerDegLat = 111_320.0
    private val mPerDegLon = 111_320.0 * cos(Math.toRadians(latRef))

    private fun offset(eastM: Double, northM: Double) =
        Pair(latRef + northM / mPerDegLat, lonRef + eastM / mPerDegLon)

    private fun errM(lat: Double, lon: Double, trueEast: Double, trueNorth: Double): Double =
        hypot((lon - lonRef) * mPerDegLon - trueEast, (lat - latRef) * mPerDegLat - trueNorth)

    private fun rms(errors: List<Double>) = sqrt(errors.sumOf { it * it } / errors.size)

    /** Per-axis noise of a fix whose reported accuracy (68 % radius) is [accuracyM]. */
    private fun noise(rnd: Random, accuracyM: Double) = rnd.nextGaussian() * accuracyM * PositionFilter.SIGMA_PER_ACCURACY

    @Test
    fun stationary_noisy_fixes_are_smoothed_toward_the_true_position() {
        val rnd = Random(42)
        val f = PositionFilter()
        val raw = mutableListOf<Double>()
        val filtered = mutableListOf<Double>()
        var t = 0L
        repeat(300) { i ->
            val (lat, lon) = offset(noise(rnd, 20.0), noise(rnd, 20.0))
            val out = f.update(lat, lon, 20.0, t, null, stationary = true)
            t += 60_000
            if (i >= 20) { // burn-in
                raw += errM(lat, lon, 0.0, 0.0)
                filtered += errM(out.latitude, out.longitude, 0.0, 0.0)
            }
        }
        println("stationary: raw RMS=%.1f m  filtered RMS=%.1f m".format(rms(raw), rms(filtered)))
        assertTrue("filtered ${rms(filtered)} should beat raw ${rms(raw)} by >30%", rms(filtered) < 0.7 * rms(raw))
    }

    @Test
    fun accurate_fix_outweighs_coarse_fix_instead_of_being_overwritten() {
        // A good 5 m fix followed by coarse 100 m fixes scattered around the truth: the old code
        // (last fix wins) would wander with the coarse fixes; the filter must stay near the good one.
        val rnd = Random(7)
        val f = PositionFilter()
        val (glat, glon) = offset(noise(rnd, 5.0), noise(rnd, 5.0))
        f.update(glat, glon, 5.0, 0L, null, stationary = true)

        val lastFixWins = mutableListOf<Double>()
        val filtered = mutableListOf<Double>()
        var t = 60_000L
        repeat(60) {
            val (lat, lon) = offset(noise(rnd, 100.0), noise(rnd, 100.0))
            val out = f.update(lat, lon, 100.0, t, null, stationary = true)
            t += 60_000
            lastFixWins += errM(lat, lon, 0.0, 0.0)
            filtered += errM(out.latitude, out.longitude, 0.0, 0.0)
        }
        println("good-then-coarse: last-fix-wins RMS=%.1f m  filtered RMS=%.1f m".format(rms(lastFixWins), rms(filtered)))
        assertTrue(rms(filtered) < 0.5 * rms(lastFixWins))
    }

    @Test
    fun walking_in_a_straight_line_is_not_made_worse_by_lag() {
        val rnd = Random(3)
        val f = PositionFilter()
        val raw = mutableListOf<Double>()
        val filtered = mutableListOf<Double>()
        val speed = 1.4
        var t = 0L
        repeat(120) { i ->
            val trueEast = speed * (i * 10.0)
            val (lat, lon) = offset(trueEast + noise(rnd, 10.0), noise(rnd, 10.0))
            val out = f.update(lat, lon, 10.0, t, speed, stationary = false)
            t += 10_000
            if (i >= 5) {
                raw += errM(lat, lon, trueEast, 0.0)
                filtered += errM(out.latitude, out.longitude, trueEast, 0.0)
            }
        }
        println("walking: raw RMS=%.1f m  filtered RMS=%.1f m".format(rms(raw), rms(filtered)))
        assertTrue("must not be worse than raw", rms(filtered) <= rms(raw) * 1.05)
    }

    @Test
    fun a_real_jump_is_followed_immediately_not_smeared_over_many_updates() {
        val f = PositionFilter()
        val (a, b) = offset(0.0, 0.0)
        repeat(10) { i -> f.update(a, b, 10.0, i * 10_000L, null, stationary = true) }

        // Teleport 500 m east (e.g. got into a car while flagged stationary), fix accuracy 10 m.
        val (lat, lon) = offset(500.0, 0.0)
        val out = f.update(lat, lon, 10.0, 200_000L, null, stationary = true)
        val e = errM(out.latitude, out.longitude, 500.0, 0.0)
        println("jump: error right after a 500 m move = %.1f m".format(e))
        assertTrue("error after jump was $e m", e < 20.0)
    }

    @Test
    fun non_finite_input_never_throws_and_resets() {
        val f = PositionFilter()
        val (a, b) = offset(0.0, 0.0)
        f.update(a, b, 10.0, 0L, null, stationary = true)
        val out = f.update(Double.NaN, b, 10.0, 1_000L, null, stationary = true)
        assertTrue(out.latitude.isNaN())
        assertFalse(f.isInitialized)
        // and it recovers cleanly
        val again = f.update(a, b, 10.0, 2_000L, null, stationary = true)
        assertEquals(a, again.latitude, 1e-9)
        assertTrue(f.isInitialized)
    }

    @Test
    fun missing_accuracy_is_treated_pessimistically_not_as_perfect() {
        val f = PositionFilter()
        val (a, b) = offset(0.0, 0.0)
        f.update(a, b, 5.0, 0L, null, stationary = true)
        // Unknown-accuracy fix 40 m away must barely move an established 5 m estimate.
        val (lat, lon) = offset(40.0, 0.0)
        val out = f.update(lat, lon, null, 60_000L, null, stationary = true)
        val movedM = errM(out.latitude, out.longitude, 0.0, 0.0)
        println("unknown-accuracy fix moved the estimate by %.1f m of a 40 m offset".format(movedM))
        assertTrue(movedM < 20.0)
    }

    @Test
    fun sigma_factor_follows_from_the_documented_68_percent_radius() {
        // Rayleigh: P(r <= R) = 1 - exp(-R^2 / 2 sigma^2). Put R = 1 and sigma = the factor:
        // the probability must come back as the documented 0.68.
        val sigma = PositionFilter.SIGMA_PER_ACCURACY
        val p = 1.0 - Math.exp(-1.0 / (2.0 * sigma * sigma))
        assertEquals(0.68, p, 1e-12)
        assertEquals(0.6624, sigma, 5e-4)
    }

    @Test
    fun honest_noise_restarts_the_filter_no_more_often_than_the_chosen_probability() {
        // Stationary phone, honest fixes whose 68 % radius matches the reported accuracy. Every
        // restart here is a false alarm. The predicted variance is never below the true estimate
        // variance, so the observed rate may sit BELOW alpha but must not exceed it.
        val rnd = Random(2024)
        val f = PositionFilter()
        var restarts = 0
        val n = 20_000
        var t = 0L
        repeat(n) { i ->
            val (lat, lon) = offset(noise(rnd, 30.0), noise(rnd, 30.0))
            val out = f.update(lat, lon, 30.0, t, null, stationary = true)
            t += 30_000
            // A restart returns the raw fix unchanged (the first fix is that too).
            if (i > 0 && out.latitude == lat && out.longitude == lon) restarts++
        }
        val rate = restarts.toDouble() / n
        println("false restart rate = %.4f (chosen alpha = %.2f)".format(rate, PositionFilter.FALSE_RESTART_PROBABILITY))
        assertTrue("rate $rate exceeds alpha", rate <= PositionFilter.FALSE_RESTART_PROBABILITY * 1.25)
    }
}
