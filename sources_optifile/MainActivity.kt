package com.example.optifile_manager

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "optifile/app_size"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAppSize") {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    try {
                        val appInfo = packageManager.getApplicationInfo(packageName, 0)
                        var totalBytes = File(appInfo.sourceDir).length()
                        appInfo.splitSourceDirs?.forEach { splitPath ->
                            totalBytes += File(splitPath).length()
                        }
                        val sizeInMB = totalBytes.toDouble() / (1024.0 * 1024.0)
                        result.success(sizeInMB)
                    } catch (e: Exception) {
                        result.success(0.0)
                    }
                } else {
                    result.success(0.0)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
