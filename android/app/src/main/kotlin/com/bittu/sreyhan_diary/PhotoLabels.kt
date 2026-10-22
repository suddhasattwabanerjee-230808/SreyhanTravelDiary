package com.bittu.sreyhan_diary

import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import java.io.File

/**
 * Names the things in a photo ("Camel", "Sky") for Sheru's questions and the
 * I-Spy game. Uses Google Play services' copy of ML Kit's labelling model
 * (downloaded by Play services, see the manifest) rather than bundling it, which
 * keeps it out of the APK. Works offline once present; until then, no labels.
 */
object PhotoLabels {
    private val labeler by lazy {
        ImageLabeling.getClient(ImageLabelerOptions.Builder().setConfidenceThreshold(0.6f).build())
    }

    fun labels(context: Context, path: String, done: (List<String>) -> Unit) {
        val image = try {
            InputImage.fromFilePath(context, Uri.fromFile(File(path)))
        } catch (e: Exception) {
            done(emptyList())
            return
        }
        labeler.process(image)
            .addOnSuccessListener { found -> done(found.sortedByDescending { it.confidence }.map { it.text }.take(6)) }
            .addOnFailureListener { done(emptyList()) }
    }
}
