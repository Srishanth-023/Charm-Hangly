package com.hangly.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat

class HanglyOverlayService : Service() {

    companion object {
        const val CHANNEL_ID = "hangly_overlay_channel"
        const val NOTIFICATION_ID = 2026
        const val ACTION_STOP_OVERLAY = "com.hangly.mobile.ACTION_STOP_OVERLAY"

        var isRunning: Boolean = false
            private set
    }

    private var windowManager: WindowManager? = null
    private var overlayView: OverlayView? = null
    private var screenReceiver: BroadcastReceiver? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        registerScreenReceiver()
        showOverlayWindow()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_OVERLAY) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Hangly Desktop Charm",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows active desktop charm floating over applications"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, HanglyOverlayService::class.java).apply {
            action = ACTION_STOP_OVERLAY
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Hangly Charm Active")
            .setContentText("Your charm is hanging above other apps. Tap to open or stop.")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun registerScreenReceiver() {
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> overlayView?.pause()
                    Intent.ACTION_SCREEN_ON -> overlayView?.resume()
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        registerReceiver(screenReceiver, filter)
    }

    private fun showOverlayWindow() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val density = resources.displayMetrics.density
        val width = (160 * density).toInt()
        val height = (240 * density).toInt()

        val layoutParams = WindowManager.LayoutParams(
            width,
            height,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = 0
            y = (20 * density).toInt()
        }

        overlayView = OverlayView(this, layoutParams, windowManager)
        try {
            windowManager?.addView(overlayView, layoutParams)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        isRunning = false
        screenReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
        }
        overlayView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        overlayView = null
        super.onDestroy()
    }

    class OverlayView(
        context: Context,
        private val params: WindowManager.LayoutParams,
        private val wm: WindowManager?
    ) : View(context) {

        private var initialX: Int = 0
        private var initialY: Int = 0
        private var initialTouchX: Float = 0f
        private var initialTouchY: Float = 0f

        private val ropePaint = Paint().apply {
            color = Color.parseColor("#FFD700")
            strokeWidth = 6f
            strokeCap = Paint.Cap.ROUND
            isAntiAlias = true
        }

        private val charmPaint = Paint().apply {
            color = Color.parseColor("#1E88E5")
            style = Paint.Style.FILL
            isAntiAlias = true
        }

        private val charmGlowPaint = Paint().apply {
            color = Color.parseColor("#441E88E5")
            style = Paint.Style.FILL
            isAntiAlias = true
        }

        private val innerEyePaint = Paint().apply {
            color = Color.WHITE
            style = Paint.Style.FILL
            isAntiAlias = true
        }

        private val centerDotPaint = Paint().apply {
            color = Color.parseColor("#0D47A1")
            style = Paint.Style.FILL
            isAntiAlias = true
        }

        private var isSuspended = false

        fun pause() {
            isSuspended = true
            invalidate()
        }

        fun resume() {
            isSuspended = false
            invalidate()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            if (isSuspended) return

            val cx = width / 2f
            val ropeTop = 10f
            val charmCenterY = height - 50f
            val charmRadius = 36f

            // Rope
            canvas.drawLine(cx, ropeTop, cx, charmCenterY, ropePaint)

            // Knot
            canvas.drawCircle(cx, ropeTop, 8f, ropePaint)

            // Charm halo glow
            canvas.drawCircle(cx, charmCenterY, charmRadius + 12f, charmGlowPaint)

            // Charm amulet (Nazar style disc)
            canvas.drawCircle(cx, charmCenterY, charmRadius, charmPaint)
            canvas.drawCircle(cx, charmCenterY, charmRadius * 0.65f, innerEyePaint)
            canvas.drawCircle(cx, charmCenterY, charmRadius * 0.35f, centerDotPaint)
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    wm?.updateViewLayout(this, params)
                    return true
                }
            }
            return super.onTouchEvent(event)
        }
    }
}
