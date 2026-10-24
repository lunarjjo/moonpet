package com.lunarjjo.moonpet

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "moonpet/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // direktori library asli (tempat libmoonpetmodel.so
                    // di-extract saat instalasi — jalan pintas tanpa salin aset)
                    "nativeLibraryDir" -> result.success(
                        applicationInfo.nativeLibraryDir
                    )
                    else -> result.notImplemented()
                }
            }
    }
}
