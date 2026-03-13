package com.newsblur.askai

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File

class AskAiVoiceRecorder(
    private val context: Context,
) {
    private var mediaRecorder: MediaRecorder? = null
    private var outputFile: File? = null

    fun startRecording(): Boolean =
        runCatching {
            val file = File.createTempFile("ask-ai-", ".m4a", context.cacheDir)
            val recorder =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    MediaRecorder(context)
                } else {
                    @Suppress("DEPRECATION")
                    MediaRecorder()
                }

            recorder.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44_100)
                setAudioEncodingBitRate(96_000)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }

            outputFile = file
            mediaRecorder = recorder
        }.isSuccess

    fun stopRecording(): File? =
        runCatching {
            val file = outputFile
            outputFile = null
            mediaRecorder?.stop()
            releaseRecorder()

            if (file != null && file.exists() && file.length() > 0) {
                file
            } else {
                file?.delete()
                null
            }
        }.getOrElse {
            cancel()
            null
        }

    fun cancel() {
        releaseRecorder()
        outputFile?.delete()
        outputFile = null
    }

    private fun releaseRecorder() {
        mediaRecorder?.let {
            runCatching {
                it.reset()
            }
        }
        mediaRecorder?.release()
        mediaRecorder = null
    }
}
