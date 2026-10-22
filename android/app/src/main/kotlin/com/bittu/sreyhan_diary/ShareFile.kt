package com.bittu.sreyhan_diary

import android.app.Activity
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File

/**
 * Opens Android's share sheet (WhatsApp, Drive, print...) for a storybook,
 * postcard or comic the app made in its cache/share folder. Our own few lines
 * rather than a share plugin: add-ons have not all worked in release builds.
 */
object ShareFile {
    fun share(activity: Activity, path: String, mime: String, title: String) {
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.share", File(path))
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, title)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(send, title))
    }
}
