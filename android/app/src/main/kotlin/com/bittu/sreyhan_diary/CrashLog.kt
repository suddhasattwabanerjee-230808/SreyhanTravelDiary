package com.bittu.sreyhan_diary

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Notes about things that went wrong, saved to Download (SreyhanDiary-crash-…),
 * where a grown-up (or Claude, reading the phone's storage) can find them.
 * Adapted from ShotDrop.
 */
object CrashLog {
    /** Writes [text] to Download/SreyhanDiary-crash-<time>[suffix], with the app and phone versions on top. */
    fun write(context: Context, text: String, suffix: String = ".txt") {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        runCatching {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            val header = "Sreyhan's Diary ${info.versionName} (${info.longVersionCode}) · Android ${Build.VERSION.RELEASE} " +
                "(SDK ${Build.VERSION.SDK_INT}) · ${Build.MANUFACTURER} ${Build.MODEL}\n\n"
            val name = "SreyhanDiary-crash-" + SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date()) + suffix
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return
            context.contentResolver.openOutputStream(uri)?.use { it.write((header + text).toByteArray()) }
        }
    }

    /** If the previous run crashed or froze, says why, once. */
    fun reportLastExit(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        runCatching {
            val am = context.getSystemService(ActivityManager::class.java)
            val last = am.getHistoricalProcessExitReasons(context.packageName, 0, 1).firstOrNull() ?: return
            val kind = when (last.reason) {
                ApplicationExitInfo.REASON_CRASH -> "Java crash"
                ApplicationExitInfo.REASON_CRASH_NATIVE -> "native crash"
                ApplicationExitInfo.REASON_ANR -> "froze (ANR)"
                ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "failed to start"
                else -> return
            }
            val prefs = context.getSharedPreferences("diary.crashlog", Context.MODE_PRIVATE)
            if (prefs.getLong("reported", 0L) == last.timestamp) return
            prefs.edit().putLong("reported", last.timestamp).commit()
            val trace = runCatching { last.traceInputStream?.use { String(it.readBytes()) } }.getOrNull()
            write(
                context,
                "The last run ended: $kind\nWhen: ${Date(last.timestamp)}\nStatus: ${last.status}\n" +
                    "Description: ${last.description}\n\n${trace ?: ""}",
            )
        }
    }
}
