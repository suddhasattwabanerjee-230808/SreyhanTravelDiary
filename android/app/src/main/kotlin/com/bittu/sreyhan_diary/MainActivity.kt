package com.bittu.sreyhan_diary

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
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

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
