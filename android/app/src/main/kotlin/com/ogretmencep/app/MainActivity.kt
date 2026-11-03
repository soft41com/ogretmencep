package com.ogretmencep.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ogretmencep.app/intent"
    private var channel: MethodChannel? = null
    private var initialFilePath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFile" -> {
                    val path = initialFilePath
                    initialFilePath = null
                    result.success(path)
                }
                else -> result.notImplemented()
            }
        }

        // Eğer başlangıçta dosya varsa ve engine hazırsa hemen ilet
        initialFilePath?.let { path ->
            initialFilePath = null
            channel?.invokeMethod("onFileReceived", path)
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val data: Uri? = intent.data

        if (Intent.ACTION_VIEW == action && data != null) {
            val localPath = copyUriToCache(data)
            if (localPath != null) {
                initialFilePath = localPath
                channel?.invokeMethod("onFileReceived", localPath)
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val contentResolver = contentResolver
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val fileName = "incoming_kurum_verisi_${System.currentTimeMillis()}.ogretmencep"
            val targetFile = File(cacheDir, fileName)

            FileOutputStream(targetFile).use { outputStream ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    outputStream.write(buffer, 0, bytesRead)
                }
                outputStream.flush()
            }
            inputStream.close()
            targetFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
