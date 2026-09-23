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
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.os.Build
import android.os.IBinder
import android.view.Choreographer
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

class HanglyOverlayService : Service() {

    companion object {
        const val CHANNEL_ID = "hangly_overlay_channel"
        const val NOTIFICATION_ID = 2026
        const val ACTION_STOP_OVERLAY = "com.hangly.mobile.ACTION_STOP_OVERLAY"
        const val ACTION_SHOW_OVERLAY = "com.hangly.mobile.ACTION_SHOW_OVERLAY"
        const val ACTION_HIDE_OVERLAY = "com.hangly.mobile.ACTION_HIDE_OVERLAY"

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
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(),
                    0
                )
            } else {
                startForeground(NOTIFICATION_ID, buildNotification())
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        registerScreenReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_OVERLAY -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_HIDE_OVERLAY -> {
                overlayView?.visibility = View.GONE
                overlayView?.pause()
                return START_STICKY
            }
            ACTION_SHOW_OVERLAY, null -> {
                val charmBytes = intent?.getByteArrayExtra("charmBytes")
                val ropeColor = intent?.getStringExtra("ropeColor") ?: "#FFD700"
                val ropeLength = intent?.getFloatExtra("ropeLength", 135f) ?: 135f
                val charmRadius = intent?.getFloatExtra("charmRadius", 25f) ?: 25f

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !android.provider.Settings.canDrawOverlays(this)) {
                    android.util.Log.w("HanglyOverlay", "Missing Settings.canDrawOverlays permission!")
                    return START_STICKY
                }

                if (overlayView == null) {
                    showOverlayWindow(charmBytes, ropeColor, ropeLength, charmRadius)
                } else {
                    overlayView?.updateConfig(charmBytes, ropeColor, ropeLength, charmRadius)
                    overlayView?.visibility = View.VISIBLE
                    overlayView?.requestLayout()
                    overlayView?.resume()
                    overlayView?.wake()
                }
                return START_STICKY
            }
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

    private fun showOverlayWindow(
        charmBytes: ByteArray?,
        ropeColor: String,
        ropeLength: Float,
        charmRadius: Float
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !android.provider.Settings.canDrawOverlays(this)) {
            return
        }
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val density = resources.displayMetrics.density

        val width = (140 * density).toInt()
        val height = (max(180f, ropeLength + charmRadius * 2f + 40f) * density).toInt().coerceAtMost((260 * density).toInt())

        val layoutParams = WindowManager.LayoutParams(
            width,
            height,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = 0
            y = 0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }

        val view = OverlayView(this, layoutParams, windowManager)
        view.updateConfig(charmBytes, ropeColor, ropeLength, charmRadius)
        overlayView = view

        try {
            windowManager?.addView(view, layoutParams)
            view.visibility = View.VISIBLE
            view.wake()
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
            it.destroy()
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

        private val density = resources.displayMetrics.density

        private var charmBitmap: Bitmap? = null
        private var ropeColorInt = Color.parseColor("#FFD700")
        private var ropeLengthPx = 135f * density
        private var charmRadiusPx = 25f * density

        class Point(
            var x: Float,
            var y: Float,
            var oldX: Float,
            var oldY: Float,
            val isPinned: Boolean = false
        )

        private val segmentCount = 20
        private val points = mutableListOf<Point>()
        private var isSleeping = false
        private var isSuspended = false
        private var sleepFrames = 0
        private val framesBeforeSleep = 60

        private var isDraggingCharm = false
        private var isDraggingAnchor = false

        private var initialWindowX = 0
        private var initialWindowY = 0
        private var initialTouchRawX = 0f
        private var initialTouchRawY = 0f

        private var lastTouchX = 0f
        private var lastTouchY = 0f
        private var touchVx = 0f
        private var touchVy = 0f
        private var lastTouchTime = 0L

        private val ropePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 4.5f * density
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }

        private val knotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

        // Fallback procedural charm paints
        private val fallbackCharmPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1E88E5")
            style = Paint.Style.FILL
        }
        private val fallbackEyePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        private val fallbackDotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0D47A1")
            style = Paint.Style.FILL
        }

        private val ropePath = Path()

        private val anchorX: Float get() = width.takeIf { it > 0 }?.div(2f) ?: (70f * density)
        private val anchorY: Float get() = 12f * density

        private val frameCallback = object : Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                if (isSuspended) return
                stepSimulation()
                invalidate()
                if (!isSleeping) {
                    Choreographer.getInstance().postFrameCallback(this)
                }
            }
        }

        init {
            initPoints()
            wake()
        }

        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            isSuspended = false
            initPoints()
            wake()
        }

        override fun onDetachedFromWindow() {
            super.onDetachedFromWindow()
            isSuspended = true
            Choreographer.getInstance().removeFrameCallback(frameCallback)
        }

        override fun onVisibilityChanged(changedView: View, visibility: Int) {
            super.onVisibilityChanged(changedView, visibility)
            if (visibility == View.VISIBLE) {
                isSuspended = false
                wake()
            } else {
                pause()
            }
        }

        fun updateConfig(
            charmBytes: ByteArray?,
            ropeColor: String,
            ropeLength: Float,
            charmRadius: Float
        ) {
            try {
                ropeColorInt = Color.parseColor(ropeColor)
            } catch (_: Exception) {
                ropeColorInt = Color.parseColor("#FFD700")
            }
            ropePaint.color = ropeColorInt
            knotPaint.color = ropeColorInt
            glowPaint.color = Color.argb(45, Color.red(ropeColorInt), Color.green(ropeColorInt), Color.blue(ropeColorInt))

            ropeLengthPx = ropeLength * density
            charmRadiusPx = charmRadius * density

            if (charmBytes != null && charmBytes.isNotEmpty()) {
                try {
                    charmBitmap = BitmapFactory.decodeByteArray(charmBytes, 0, charmBytes.size)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            initPoints()
            wake()
        }

        private fun initPoints() {
            points.clear()
            val curAnchorX = anchorX
            val curAnchorY = anchorY
            val segLen = ropeLengthPx / segmentCount

            // Pinned anchor at top center
            points.add(Point(curAnchorX, curAnchorY, curAnchorX, curAnchorY, isPinned = true))

            for (i in 1..segmentCount) {
                val py = curAnchorY + (i * segLen)
                // Add natural gentle pendulum sway displacement
                val swayOffset = (i.toFloat() / segmentCount) * (14f * density)
                points.add(Point(curAnchorX + swayOffset, py, curAnchorX, py, isPinned = false))
            }
            sleepFrames = 0
            isSleeping = false
        }

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            if (w > 0 && h > 0) {
                initPoints()
                wake()
            }
        }

        fun wake() {
            if (isSuspended) return
            isSleeping = false
            sleepFrames = 0
            Choreographer.getInstance().removeFrameCallback(frameCallback)
            Choreographer.getInstance().postFrameCallback(frameCallback)
            invalidate()
        }

        fun pause() {
            isSuspended = true
            Choreographer.getInstance().removeFrameCallback(frameCallback)
        }

        fun resume() {
            isSuspended = false
            wake()
        }

        fun destroy() {
            isSuspended = true
            Choreographer.getInstance().removeFrameCallback(frameCallback)
            charmBitmap?.recycle()
            charmBitmap = null
        }

        private fun stepSimulation() {
            if (points.size < 2) return

            val dt = 1f / 60f
            val gravity = 1800f * density
            val damping = 0.992f
            val segLen = ropeLengthPx / segmentCount

            // 1. Verlet Integration
            for (i in 1 until points.size) {
                val p = points[i]
                if (i == points.size - 1 && isDraggingCharm) continue

                val vx = (p.x - p.oldX) * damping
                val vy = (p.y - p.oldY) * damping

                p.oldX = p.x
                p.oldY = p.y
                p.x += vx
                p.y += vy + (gravity * dt * dt)
            }

            // 2. Relaxation constraints
            val curAnchorX = anchorX
            val curAnchorY = anchorY

            for (iter in 0 until 16) {
                points[0].x = curAnchorX
                points[0].y = curAnchorY

                for (i in 0 until points.size - 1) {
                    val p1 = points[i]
                    val p2 = points[i + 1]

                    val dx = p2.x - p1.x
                    val dy = p2.y - p1.y
                    val dist = hypot(dx, dy)
                    if (dist > 1e-4f) {
                        val diff = (dist - segLen) / dist
                        val offsetX = dx * diff
                        val offsetY = dy * diff

                        if (p1.isPinned) {
                            if (!(i + 1 == points.size - 1 && isDraggingCharm)) {
                                p2.x -= offsetX
                                p2.y -= offsetY
                            }
                        } else if (i + 1 == points.size - 1 && isDraggingCharm) {
                            p1.x += offsetX
                            p1.y += offsetY
                        } else {
                            p1.x += offsetX * 0.5f
                            p1.y += offsetY * 0.5f
                            p2.x -= offsetX * 0.5f
                            p2.y -= offsetY * 0.5f
                        }
                    }
                }
            }

            // 3. Energy / Sleep Check
            if (!isDraggingCharm && !isDraggingAnchor) {
                var totalMotion = 0f
                for (i in 1 until points.size) {
                    val p = points[i]
                    totalMotion += hypot(p.x - p.oldX, p.y - p.oldY)
                }

                if (totalMotion < (0.4f * density)) {
                    sleepFrames++
                    if (sleepFrames > framesBeforeSleep) {
                        isSleeping = true
                    }
                } else {
                    sleepFrames = 0
                }
            }
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            if (points.size < 2) return

            val curAnchorX = anchorX
            val curAnchorY = anchorY

            // Draw Rope Path
            ropePath.reset()
            ropePath.moveTo(points[0].x, points[0].y)
            for (i in 1 until points.size) {
                val prev = points[i - 1]
                val curr = points[i]
                val midX = (prev.x + curr.x) / 2f
                val midY = (prev.y + curr.y) / 2f
                ropePath.quadTo(prev.x, prev.y, midX, midY)
            }
            val last = points.last()
            ropePath.lineTo(last.x, last.y)
            canvas.drawPath(ropePath, ropePaint)

            // Draw Top Anchor Knot / Ring
            canvas.drawCircle(curAnchorX, curAnchorY, 5.5f * density, knotPaint)

            // Calculate Charm Angle from last rope segment
            val secondLast = points[points.size - 2]
            val angleRad = atan2(last.y - secondLast.y, last.x - secondLast.x) - (Math.PI / 2.0).toFloat()
            val angleDeg = Math.toDegrees(angleRad.toDouble()).toFloat()

            // Draw Halo Glow
            canvas.drawCircle(last.x, last.y, charmRadiusPx * 1.35f, glowPaint)

            // Draw Charm Artwork (Bitmap or Fallback)
            val bmp = charmBitmap
            if (bmp != null && !bmp.isRecycled) {
                canvas.save()
                canvas.translate(last.x, last.y)
                canvas.rotate(angleDeg)
                val dstRect = RectF(-charmRadiusPx, -charmRadiusPx, charmRadiusPx, charmRadiusPx)
                canvas.drawBitmap(bmp, null, dstRect, bitmapPaint)
                canvas.restore()
            } else {
                // Procedural Nazar Eye Charm
                canvas.drawCircle(last.x, last.y, charmRadiusPx, fallbackCharmPaint)
                canvas.drawCircle(last.x, last.y, charmRadiusPx * 0.65f, fallbackEyePaint)
                canvas.drawCircle(last.x, last.y, charmRadiusPx * 0.35f, fallbackDotPaint)
            }
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            val curAnchorX = anchorX
            val curAnchorY = anchorY
            val last = if (points.isNotEmpty()) points.last() else null

            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    // Check if touching top knot to move window
                    val distToAnchor = hypot(event.x - curAnchorX, event.y - curAnchorY)
                    if (distToAnchor < (32f * density) || event.y < (24f * density)) {
                        isDraggingAnchor = true
                        initialWindowX = params.x
                        initialWindowY = params.y
                        initialTouchRawX = event.rawX
                        initialTouchRawY = event.rawY
                        return true
                    }

                    // Check if touching charm to interact with rope physics
                    if (last != null) {
                        val distToCharm = hypot(event.x - last.x, event.y - last.y)
                        if (distToCharm < (charmRadiusPx * 2.2f)) {
                            isDraggingCharm = true
                            lastTouchX = event.x
                            lastTouchY = event.y
                            lastTouchTime = System.currentTimeMillis()
                            touchVx = 0f
                            touchVy = 0f
                            wake()
                            return true
                        }
                    }
                    return false
                }

                MotionEvent.ACTION_MOVE -> {
                    if (isDraggingAnchor) {
                        params.x = initialWindowX + (event.rawX - initialTouchRawX).toInt()
                        params.y = initialWindowY + (event.rawY - initialTouchRawY).toInt()
                        wm?.updateViewLayout(this, params)
                        return true
                    }

                    if (isDraggingCharm && last != null) {
                        val now = System.currentTimeMillis()
                        val dtSec = max((now - lastTouchTime) / 1000f, 0.001f)
                        touchVx = (event.x - lastTouchX) / dtSec
                        touchVy = (event.y - lastTouchY) / dtSec
                        lastTouchX = event.x
                        lastTouchY = event.y
                        lastTouchTime = now

                        last.x = event.x
                        last.y = event.y
                        wake()
                        return true
                    }
                }

                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (isDraggingAnchor) {
                        isDraggingAnchor = false
                        return true
                    }

                    if (isDraggingCharm && last != null) {
                        isDraggingCharm = false
                        // Fling impulse with velocity clamping
                        val speed = hypot(touchVx, touchVy)
                        if (speed > 50f) {
                            val maxV = 1800f * density
                            val clampedVx = touchVx.coerceIn(-maxV, maxV)
                            val clampedVy = touchVy.coerceIn(-maxV, maxV)
                            last.oldX = last.x - (clampedVx * 0.016f)
                            last.oldY = last.y - (clampedVy * 0.016f)
                        } else {
                            // Gentle tap push
                            last.oldX -= 30f * density
                        }
                        wake()
                        return true
                    }
                }
            }
            return super.onTouchEvent(event)
        }
    }
}
