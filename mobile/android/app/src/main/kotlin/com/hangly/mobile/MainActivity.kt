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
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            ).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                            } catch (_: Exception) {}
                        }
                    }
                    result.success(null)
                }

                "startOverlayService" -> {
                    val charmBytes = call.argument<ByteArray>("charmBytes")
                    val ropeColor = call.argument<String>("ropeColor") ?: "#FFD700"
                    val ropeLength = (call.argument<Double>("ropeLength") ?: 135.0).toFloat()
                    val charmRadius = (call.argument<Double>("charmRadius") ?: 25.0).toFloat()

                    val serviceIntent = Intent(this, HanglyOverlayService::class.java).apply {
                        action = HanglyOverlayService.ACTION_SHOW_OVERLAY
                        putExtra("charmBytes", charmBytes)
                        putExtra("ropeColor", ropeColor)
                        putExtra("ropeLength", ropeLength)
                        putExtra("charmRadius", charmRadius)
                    }

                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                    } catch (e: Exception) {
                        try {
                            startService(serviceIntent)
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }

                "stopOverlayService" -> {
                    val serviceIntent = Intent(this, HanglyOverlayService::class.java).apply {
                        action = HanglyOverlayService.ACTION_HIDE_OVERLAY
                    }
                    try {
                        startService(serviceIntent)
                    } catch (_: Exception) {}
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
