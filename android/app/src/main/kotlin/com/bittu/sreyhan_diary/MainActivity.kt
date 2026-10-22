package com.bittu.sreyhan_diary

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // We're open, so the "updated, tap to open" fallback is no longer needed.
        AppUpdater.clearUpdatedNotification(this)
        Thread { CrashLog.reportLastExit(applicationContext) }.start()
    }

    // Settings live in Android's own SharedPreferences, read and written over a
    // channel: the shared_preferences plugin never answers in R8 release builds,
    // which left 0.4.0 on a black screen (ShotDrop hit the same thing).
    private val prefs by lazy { getSharedPreferences("diary.settings", Context.MODE_PRIVATE) }

    // Answers waiting on the location question and the backup file picker.
    private var onLocationAnswer: ((Boolean) -> Unit)? = null
    private var onBackupPicked: ((android.net.Uri?) -> Unit)? = null

    private fun withLocation(then: (Boolean) -> Unit) {
        val perm = Manifest.permission.ACCESS_COARSE_LOCATION
        if (checkSelfPermission(perm) == PackageManager.PERMISSION_GRANTED) return then(true)
        onLocationAnswer = then
        requestPermissions(arrayOf(perm), LOCATION_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LOCATION_REQUEST) return
        onLocationAnswer?.invoke(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        onLocationAnswer = null
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != BACKUP_REQUEST) return
        onBackupPicked?.invoke(if (resultCode == Activity.RESULT_OK) data?.data else null)
        onBackupPicked = null
    }

    /** Slow file work off the main thread; the answer back on it. */
    private fun inBackground(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            try {
                val value = work()
                runOnUiThread { result.success(value) }
            } catch (e: Exception) {
                runOnUiThread { result.error("failed", e.message ?: e.toString(), null) }
            }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "sreyhan/app").setMethodCallHandler { call, result ->
            when (call.method) {
                "prefs" -> result.success(HashMap<String, Any?>(prefs.all))
                "setPref" -> {
                    val key = call.argument<String>("key")!!
                    val edit = prefs.edit()
                    when (val v = call.argument<Any?>("value")) {
                        null -> edit.remove(key)
                        is Boolean -> edit.putBoolean(key, v)
                        is Int -> edit.putInt(key, v)
                        is Long -> edit.putInt(key, v.toInt())
                        else -> edit.putString(key, v.toString())
                    }
                    edit.apply()
                    result.success(null)
                }
                // A Dart error (the app keeps going): noted in Download.
                "logError" -> {
                    val text = call.argument<String>("text") ?: ""
                    Thread { CrashLog.write(applicationContext, text, suffix = "-dart.txt") }.start()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "sreyhan/share").setMethodCallHandler { call, result ->
            val path = call.argument<String>("path")
            if (call.method != "share" || path == null) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                ShareFile.share(this, path, call.argument<String>("mime") ?: "*/*", call.argument<String>("title") ?: "Share")
                result.success(null)
            } catch (e: Exception) {
                result.error("share_failed", e.message ?: e.toString(), null)
            }
        }

        MethodChannel(messenger, "sreyhan/place").setMethodCallHandler { call, result ->
            when (call.method) {
                "photo" -> inBackground(result) { PhotoPlace.fromPhoto(call.argument<String>("path")!!) }
                "here" -> withLocation { allowed ->
                    if (allowed) PhotoPlace.here(this) { result.success(it) } else result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "sreyhan/files").setMethodCallHandler { call, result ->
            when (call.method) {
                "zip" -> inBackground(result) {
                    DiaryFiles.zip(File(call.argument<String>("dir")!!), File(call.argument<String>("out")!!))
                    null
                }
                // Lets the grown-up pick a backup .zip, then unpacks it; null if they backed out.
                "openBackup" -> {
                    val into = File(call.argument<String>("into")!!)
                    onBackupPicked = { uri ->
                        if (uri == null) result.success(null)
                        else inBackground(result) { DiaryFiles.unzip(this, uri, into); into.path }
                    }
                    val pick = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/zip", "application/x-zip-compressed", "application/octet-stream"))
                    }
                    @Suppress("DEPRECATION")
                    startActivityForResult(pick, BACKUP_REQUEST)
                }
                "saveToGallery" -> inBackground(result) {
                    DiaryFiles.saveToGallery(this, call.argument<String>("path")!!, call.argument<String>("name")!!)
                    null
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "sreyhan/translate").setMethodCallHandler { call, result ->
            WordTranslation.handle(this, call, result)
        }

        MethodChannel(messenger, "sreyhan/labels").setMethodCallHandler { call, result ->
            val path = call.argument<String>("path")
            if (call.method != "labels" || path == null) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            PhotoLabels.labels(this, path) { result.success(it) }
        }

        val updater = MethodChannel(messenger, "sreyhan/updater")
        updater.setMethodCallHandler { call, result ->
            val path = call.argument<String>("path")
            if (call.method != "install" || path == null) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            // On success this process is replaced, so `result` only ever reports failure.
            AppUpdater.install(
                this,
                File(path),
                progress = { updater.invokeMethod("installProgress", it) },
                failure = { result.error("install_failed", it, null) },
            )
        }
    }

    companion object {
        private const val LOCATION_REQUEST = 41
        private const val BACKUP_REQUEST = 42
    }
}
