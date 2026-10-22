package com.bittu.sreyhan_diary

import android.content.Context
import com.google.mlkit.common.MlKit
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bengali or Hindi to English with ML Kit, on the phone. Replaces the
 * google_mlkit_translation plugin, whose start-up grabbed ML Kit eagerly and
 * left it unregistered on the phone (MissingPluginException on every call).
 * Nothing here runs until the child first asks for a word, and every failure
 * comes back to Dart with its reason, so it lands in the crash notes.
 */
object WordTranslation {
    private const val ENGLISH = "en"
    private val translators = HashMap<String, Translator>()

    private fun models(context: Context): RemoteModelManager {
        // Normally done at launch by ML Kit's own provider; harmless if so.
        runCatching { MlKit.initialize(context.applicationContext) }
        return RemoteModelManager.getInstance()
    }

    private fun model(lang: String) = TranslateRemoteModel.Builder(lang).build()

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        try {
            val lang = call.argument<String>("lang") ?: return result.error("bad_args", "Missing language", null)
            when (call.method) {
                "isReady" -> {
                    val m = models(context)
                    m.isModelDownloaded(model(lang)).continueWithTask { source ->
                        if (source.result == true) m.isModelDownloaded(model(ENGLISH)) else source
                    }
                        .addOnSuccessListener { result.success(it == true) }
                        .addOnFailureListener { result.error("check_failed", it.message ?: it.toString(), null) }
                }
                "download" -> {
                    val m = models(context)
                    val any = DownloadConditions.Builder().build()
                    m.download(model(lang), any).continueWithTask { if (it.isSuccessful) m.download(model(ENGLISH), any) else it }
                        .addOnSuccessListener { result.success(true) }
                        .addOnFailureListener { result.error("download_failed", it.message ?: it.toString(), null) }
                }
                "translate" -> {
                    val text = call.argument<String>("text") ?: return result.error("bad_args", "Missing text", null)
                    models(context)
                    val translator = translators.getOrPut(lang) {
                        Translation.getClient(
                            TranslatorOptions.Builder().setSourceLanguage(lang).setTargetLanguage(ENGLISH).build(),
                        )
                    }
                    translator.translate(text)
                        .addOnSuccessListener { result.success(it) }
                        .addOnFailureListener { result.error("translate_failed", it.message ?: it.toString(), null) }
                }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("translation", "${e.javaClass.simpleName}: ${e.message}", null)
        }
    }
}
