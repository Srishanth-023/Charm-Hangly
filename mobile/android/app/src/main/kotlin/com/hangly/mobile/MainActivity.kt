package com.hangly.mobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "hangly/overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPermission)
                }

                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(null)
                }

                "startOverlayService" -> {
                    val charmId = call.argument<String>("charmId") ?: "nazar"
                    val ropeStyle = call.argument<String>("ropeStyle") ?: "thread"

                    val serviceIntent = Intent(this, HanglyOverlayService::class.java).apply {
                        putExtra("charmId", charmId)
                        putExtra("ropeStyle", ropeStyle)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
                }

                "stopOverlayService" -> {
                    val serviceIntent = Intent(this, HanglyOverlayService::class.java)
                    stopService(serviceIntent)
                    result.success(true)
                }

                "isOverlayRunning" -> {
                    result.success(HanglyOverlayService.isRunning)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
