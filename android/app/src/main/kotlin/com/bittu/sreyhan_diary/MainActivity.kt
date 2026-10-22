package com.bittu.sreyhan_diary

import android.content.Context
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
}
