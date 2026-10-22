package com.bittu.sreyhan_diary

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/**
 * The whole diary as one .zip (for moving it to a new phone), and pictures
 * saved into the phone's gallery. Plain Android, no plugins.
 */
object DiaryFiles {
    /** Zips everything under [dir] (days and photos) into [out]. */
    fun zip(dir: File, out: File) {
        out.parentFile?.mkdirs()
        ZipOutputStream(FileOutputStream(out)).use { zip ->
            dir.walkTopDown().filter { it.isFile && !it.name.endsWith(".tmp") }.forEach { f ->
                zip.putNextEntry(ZipEntry(f.relativeTo(dir).invariantSeparatorsPath))
                f.inputStream().use { it.copyTo(zip) }
                zip.closeEntry()
            }
        }
    }

    /** Unpacks a backup the user picked into [into], emptied first. */
    fun unzip(context: Context, uri: Uri, into: File) {
        into.deleteRecursively()
        into.mkdirs()
        val root = into.canonicalPath + File.separator
        val input = context.contentResolver.openInputStream(uri) ?: throw IllegalStateException("can't open the file")
        ZipInputStream(input).use { zip ->
            var entry = zip.nextEntry
            while (entry != null) {
                val f = File(into, entry.name)
                // Nothing may land outside the folder.
                if (!f.canonicalPath.startsWith(root)) throw SecurityException("bad entry ${entry.name}")
                if (entry.isDirectory) {
                    f.mkdirs()
                } else {
                    f.parentFile?.mkdirs()
                    f.outputStream().use { zip.copyTo(it) }
                }
                entry = zip.nextEntry
            }
        }
    }

    /**
     * Copies a picked song into [dir] (replacing any earlier one) and returns
     * its path and the name it had, for the grown-ups' corner to show.
     */
    fun copySong(context: Context, uri: Uri, dir: File): Map<String, String> {
        val resolver = context.contentResolver
        val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        } ?: "My song"
        val ext = name.substringAfterLast('.', "").lowercase().takeIf { it.length in 2..4 } ?: "mp3"
        dir.deleteRecursively()
        dir.mkdirs()
        // A new file name each time, so the player never reuses the old song.
        val out = File(dir, "song-${System.currentTimeMillis()}.$ext")
        val input = resolver.openInputStream(uri) ?: throw IllegalStateException("can't open the song")
        input.use { src -> out.outputStream().use { src.copyTo(it) } }
        return mapOf("path" to out.path, "name" to name.substringBeforeLast('.'))
    }

    /** Puts a PNG into Pictures/Sreyhan Diary, where the gallery shows it. */
    fun saveToGallery(context: Context, path: String, name: String) {
        if (Build.VERSION.SDK_INT < 29) throw IllegalStateException("needs Android 10 or newer")
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Sreyhan Diary")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("the gallery said no")
        resolver.openOutputStream(uri)!!.use { out -> File(path).inputStream().use { it.copyTo(out) } }
        values.clear()
        values.put(MediaStore.Images.Media.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
    }
}
