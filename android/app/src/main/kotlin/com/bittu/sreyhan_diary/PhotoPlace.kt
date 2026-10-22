package com.bittu.sreyhan_diary

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.ExifInterface
import android.os.Build
import android.os.Looper
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Where a photo was taken, for place facts and the passport map: the photo's
 * own GPS tag, or where the phone is now. Only a rough position is used (the
 * district), and it never leaves the phone.
 */
object PhotoPlace {
    /** The photo's GPS tag and when it was taken, each if known. */
    fun fromPhoto(path: String): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        try {
            val exif = ExifInterface(path)
            val spot: DoubleArray? = if (Build.VERSION.SDK_INT >= 29) {
                exif.latLong
            } else {
                val f = FloatArray(2)
                @Suppress("DEPRECATION")
                if (exif.getLatLong(f)) doubleArrayOf(f[0].toDouble(), f[1].toDouble()) else null
            }
            if (spot != null) {
                out["lat"] = spot[0]
                out["lng"] = spot[1]
            }
            val taken = exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
                ?: exif.getAttribute(ExifInterface.TAG_DATETIME)
            if (taken != null) {
                SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US).parse(taken)?.let { out["taken"] = it.time }
            }
        } catch (_: Exception) {
        }
        return out
    }

    /**
     * Where the phone is now: a recent last-known position, or a fresh one.
     * Needs the location permission (asked by MainActivity first); answers
     * null without it. [done] is called exactly once.
     */
    @SuppressLint("MissingPermission")
    fun here(context: Context, done: (Map<String, Any?>?) -> Unit) {
        val once = AtomicBoolean(false)
        fun answer(loc: Location?) {
            if (once.compareAndSet(false, true)) {
                done(loc?.let { mapOf("lat" to it.latitude, "lng" to it.longitude) })
            }
        }
        try {
            val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val known = lm.getProviders(true).mapNotNull {
                try { lm.getLastKnownLocation(it) } catch (_: Exception) { null }
            }.maxByOrNull { it.time }
            if (known != null && System.currentTimeMillis() - known.time < 30 * 60 * 1000) {
                answer(known)
                return
            }
            val provider = listOf(
                if (Build.VERSION.SDK_INT >= 31) LocationManager.FUSED_PROVIDER else null,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.GPS_PROVIDER,
            ).firstOrNull { it != null && lm.isProviderEnabled(it) }
            if (provider == null) {
                answer(known)
                return
            }
            if (Build.VERSION.SDK_INT >= 30) {
                lm.getCurrentLocation(provider, null, context.mainExecutor) { answer(it ?: known) }
            } else {
                @Suppress("DEPRECATION")
                lm.requestSingleUpdate(provider, object : LocationListener {
                    override fun onLocationChanged(location: Location) = answer(location)
                    @Deprecated("Deprecated in Java")
                    override fun onStatusChanged(p: String?, s: Int, e: android.os.Bundle?) {}
                    override fun onProviderEnabled(p: String) {}
                    override fun onProviderDisabled(p: String) = answer(known)
                }, Looper.getMainLooper())
            }
        } catch (_: Exception) {
            answer(null)
        }
    }
}
