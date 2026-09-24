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
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max

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
    var displayView: DisplayOverlayView? = null
        private set
    var anchorTouchView: AnchorTouchView? = null
        private set
    var charmTouchView: CharmTouchView? = null
        private set
    private var screenReceiver: BroadcastReceiver? = null

    private var displayParams: WindowManager.LayoutParams? = null
    private var anchorTouchParams: WindowManager.LayoutParams? = null
    private var charmTouchParams: WindowManager.LayoutParams? = null

    var anchorX: Float = 0f
        private set
    var anchorY: Float = 0f
        private set
    var isAnchorDragging: Boolean = false

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
                displayView?.visibility = View.GONE
                anchorTouchView?.visibility = View.GONE
                charmTouchView?.visibility = View.GONE
                displayView?.pause()
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

                if (displayView == null) {
                    showOverlayWindow(charmBytes, ropeColor, ropeLength, charmRadius)
                } else {
                    displayView?.updateConfig(charmBytes, ropeColor, ropeLength, charmRadius)
                    displayView?.visibility = View.VISIBLE
                    anchorTouchView?.visibility = View.VISIBLE
                    charmTouchView?.visibility = View.VISIBLE
                    displayView?.requestLayout()
                    displayView?.resume()
                    displayView?.wake()
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
                    Intent.ACTION_SCREEN_OFF -> displayView?.pause()
                    Intent.ACTION_SCREEN_ON -> displayView?.resume()
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
        val metrics = resources.displayMetrics
        val density = metrics.density
        val screenWidth = metrics.widthPixels.toFloat()

        // Read saved anchor position if previously customized by user
        val prefs = getSharedPreferences("hangly_overlay_prefs", Context.MODE_PRIVATE)
        val savedRatio = prefs.getFloat("anchor_x_ratio", 0.5f)
        val savedYDp = prefs.getFloat("anchor_y_dp", 16f)

        anchorX = (screenWidth * savedRatio).coerceIn(36f * density, screenWidth - 36f * density)
        anchorY = (savedYDp * density).coerceIn(8f * density, 80f * density)

        // 1. FULL-SCREEN DISPLAY OVERLAY VIEW
        // Covers the entire screen without any boundary clipping.
        // FLAG_NOT_TOUCHABLE ensures ALL touches pass cleanly to underlying apps.
        val dParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        displayParams = dParams

        val dView = DisplayOverlayView(this, this)
        dView.updateConfig(charmBytes, ropeColor, ropeLength, charmRadius)
        displayView = dView

        // 2. TOP ANCHOR TOUCH HANDLE
        // A generous 88dp x 52dp touch target placed over the top anchor knot.
        // User can drag it horizontally across the top to move the anchor anywhere!
        val anchorW = (88 * density).toInt()
        val anchorH = (52 * density).toInt()
        val aParams = WindowManager.LayoutParams(
            anchorW,
            anchorH,
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
            gravity = Gravity.TOP or Gravity.START
            x = (anchorX - anchorW / 2f).toInt()
            y = (anchorY - anchorH / 2f).toInt().coerceAtLeast(0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        anchorTouchParams = aParams
        val aView = AnchorTouchView(this, this)
        anchorTouchView = aView

        // 3. CHARM TOUCH TARGET
        // Sits right on top of the hanging charm.
        // User can grab and fling the charm directly.
        val charmTouchSize = max(64f * density, charmRadius * density * 2.4f).toInt()
        val cParams = WindowManager.LayoutParams(
            charmTouchSize,
            charmTouchSize,
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
            gravity = Gravity.TOP or Gravity.START
            val initialCharmY = anchorY + (ropeLength * density)
            x = (anchorX - charmTouchSize / 2f).toInt()
            y = (initialCharmY - charmTouchSize / 2f).toInt()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        charmTouchParams = cParams
        val cView = CharmTouchView(this, this)
        charmTouchView = cView

        try {
            windowManager?.addView(dView, dParams)
            windowManager?.addView(aView, aParams)
            windowManager?.addView(cView, cParams)

            dView.visibility = View.VISIBLE
            aView.visibility = View.VISIBLE
            cView.visibility = View.VISIBLE
            dView.wake()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun updateAnchor(newX: Float, newY: Float) {
        anchorX = newX
        anchorY = newY
        displayView?.setAnchor(newX, newY)

        anchorTouchParams?.let { params ->
            params.x = (newX - params.width / 2f).toInt()
            params.y = (newY - params.height / 2f).toInt().coerceAtLeast(0)
            try {
                windowManager?.updateViewLayout(anchorTouchView, params)
            } catch (_: Exception) {}
        }
    }

    fun saveAnchorPosition() {
        val screenW = resources.displayMetrics.widthPixels.toFloat()
        val density = resources.displayMetrics.density
        getSharedPreferences("hangly_overlay_prefs", Context.MODE_PRIVATE)
            .edit()
            .putFloat("anchor_x_ratio", (anchorX / screenW).coerceIn(0.05f, 0.95f))
            .putFloat("anchor_y_dp", anchorY / density)
            .apply()
    }

    fun updateCharmTouchLayout(charmX: Float, charmY: Float) {
        charmTouchParams?.let { params ->
            val targetX = (charmX - params.width / 2f).toInt()
            val targetY = (charmY - params.height / 2f).toInt()
            if (abs(params.x - targetX) > 2 || abs(params.y - targetY) > 2) {
                params.x = targetX
                params.y = targetY
                try {
                    windowManager?.updateViewLayout(charmTouchView, params)
                } catch (_: Exception) {}
            }
        }
    }

    override fun onDestroy() {
        isRunning = false
        screenReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
        }
        displayView?.let {
            it.destroy()
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        anchorTouchView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        charmTouchView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        displayView = null
        anchorTouchView = null
        charmTouchView = null
        super.onDestroy()
    }

    // =========================================================================
    // 1. DISPLAY OVERLAY VIEW (Full Screen, Non-Touchable, Draws All Art)
    // =========================================================================
    class DisplayOverlayView(
        context: Context,
        private val service: HanglyOverlayService
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

        var isAnchorPressed = false
            private set
        var isDraggingCharm = false
            private set

        private val ropePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 4.5f * density
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }

        private val knotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        private val knotCorePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.WHITE
        }

        private val anchorPressedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 3f * density
            color = Color.argb(140, 255, 255, 255)
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

        val anchorX: Float get() = service.anchorX
        val anchorY: Float get() = service.anchorY

        private val frameCallback = object : Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                if (isSuspended) return
                stepSimulation()
                invalidate()
                if (points.isNotEmpty()) {
                    service.updateCharmTouchLayout(points.last().x, points.last().y)
                }
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

            // Pinned anchor at top
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
            if (w > 0 && h > 0 && points.isEmpty()) {
                initPoints()
                wake()
            }
        }

        fun setAnchor(x: Float, y: Float) {
            if (points.isNotEmpty()) {
                val dx = x - points[0].x
                val dy = y - points[0].y
                points[0].x = x
                points[0].y = y
                points[0].oldX = x
                points[0].oldY = y

                // Nudge points with physical inertia so rope responds dynamically to anchor drag
                for (i in 1 until points.size) {
                    val factor = 1f - (i.toFloat() / points.size)
                    points[i].oldX -= dx * factor * 0.45f
                    points[i].oldY -= dy * factor * 0.45f
                }
            }
            wake()
        }

        fun setAnchorPressed(pressed: Boolean) {
            isAnchorPressed = pressed
            invalidate()
        }

        fun onCharmDragStart() {
            isDraggingCharm = true
            wake()
        }

        fun onCharmDrag(rawX: Float, rawY: Float) {
            if (points.isNotEmpty()) {
                val last = points.last()
                last.x = rawX
                last.y = rawY
            }
            wake()
        }

        fun onCharmFling(vx: Float, vy: Float) {
            isDraggingCharm = false
            if (points.isNotEmpty()) {
                val last = points.last()
                val maxV = 1800f * density
                val clampedVx = vx.coerceIn(-maxV, maxV)
                val clampedVy = vy.coerceIn(-maxV, maxV)
                last.oldX = last.x - (clampedVx * 0.016f)
                last.oldY = last.y - (clampedVy * 0.016f)
            }
            wake()
        }

        fun onCharmTap() {
            isDraggingCharm = false
            if (points.isNotEmpty()) {
                val last = points.last()
                last.oldX -= 30f * density
            }
            wake()
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
            if (!isDraggingCharm && !service.isAnchorDragging) {
                var totalMotion = 0f
                for (i in 1 until points.size) {
                    val p = points[i]
                    totalMotion += hypot(p.x - p.oldX, p.y - p.oldY)
                }

                if (totalMotion < (0.35f * density)) {
                    sleepFrames++
                    if (sleepFrames > framesBeforeSleep) {
                        isSleeping = true
                    }
                } else {
                    sleepFrames = 0
                }
            } else {
                sleepFrames = 0
            }
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            if (points.size < 2) return

            val curAnchorX = anchorX
            val curAnchorY = anchorY

            // 1. Draw Rope Path
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

            // 2. Draw Top Anchor Knot & Draggable Grip Indicator
            if (isAnchorPressed) {
                canvas.drawCircle(curAnchorX, curAnchorY, 14f * density, anchorPressedPaint)
            }
            canvas.drawCircle(curAnchorX, curAnchorY, 6.5f * density, knotPaint)
            canvas.drawCircle(curAnchorX, curAnchorY, 2.5f * density, knotCorePaint)

            // Micro-dots grip hint above the anchor knot to indicate movable handle
            val dotSpacing = 4.5f * density
            val dotY = curAnchorY - (9f * density)
            canvas.drawCircle(curAnchorX - dotSpacing, dotY, 1.4f * density, knotPaint)
            canvas.drawCircle(curAnchorX, dotY, 1.4f * density, knotPaint)
            canvas.drawCircle(curAnchorX + dotSpacing, dotY, 1.4f * density, knotPaint)

            // 3. Calculate Charm Angle from last rope segment
            val secondLast = points[points.size - 2]
            val angleRad = atan2(last.y - secondLast.y, last.x - secondLast.x) - (Math.PI / 2.0).toFloat()
            val angleDeg = Math.toDegrees(angleRad.toDouble()).toFloat()

            // 4. Draw Charm Artwork (Bitmap or Fallback)
            // No glow circle smudge: completely crisp and clean rendering
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
    }

    // =========================================================================
    // 2. ANCHOR TOUCH VIEW (Draggable Handle on Top Edge)
    // =========================================================================
    class AnchorTouchView(
        context: Context,
        private val service: HanglyOverlayService
    ) : View(context) {

        private val density = resources.displayMetrics.density
        private var touchStartX = 0f
        private var touchStartY = 0f
        private var initAnchorX = 0f
        private var initAnchorY = 0f

        init {
            setBackgroundColor(Color.TRANSPARENT)
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    service.isAnchorDragging = true
                    touchStartX = event.rawX
                    touchStartY = event.rawY
                    initAnchorX = service.anchorX
                    initAnchorY = service.anchorY
                    service.displayView?.setAnchorPressed(true)
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (service.isAnchorDragging) {
                        val dx = event.rawX - touchStartX
                        val dy = event.rawY - touchStartY
                        val screenW = resources.displayMetrics.widthPixels.toFloat()
                        val newX = (initAnchorX + dx).coerceIn(36f * density, screenW - 36f * density)
                        val newY = (initAnchorY + dy).coerceIn(8f * density, 80f * density)
                        service.updateAnchor(newX, newY)
                        return true
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (service.isAnchorDragging) {
                        service.isAnchorDragging = false
                        service.displayView?.setAnchorPressed(false)
                        service.saveAnchorPosition()
                        return true
                    }
                }
            }
            return super.onTouchEvent(event)
        }
    }

    // =========================================================================
    // 3. CHARM TOUCH VIEW (Interactive Charm Target)
    // =========================================================================
    class CharmTouchView(
        context: Context,
        private val service: HanglyOverlayService
    ) : View(context) {

        private var isDragging = false
        private var lastTouchX = 0f
        private var lastTouchY = 0f
        private var touchVx = 0f
        private var touchVy = 0f
        private var lastTouchTime = 0L

        init {
            setBackgroundColor(Color.TRANSPARENT)
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = true
                    lastTouchX = event.rawX
                    lastTouchY = event.rawY
                    lastTouchTime = System.currentTimeMillis()
                    touchVx = 0f
                    touchVy = 0f
                    service.displayView?.onCharmDragStart()
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (isDragging) {
                        val now = System.currentTimeMillis()
                        val dtSec = max((now - lastTouchTime) / 1000f, 0.001f)
                        touchVx = (event.rawX - lastTouchX) / dtSec
                        touchVy = (event.rawY - lastTouchY) / dtSec
                        lastTouchX = event.rawX
                        lastTouchY = event.rawY
                        lastTouchTime = now

                        service.displayView?.onCharmDrag(event.rawX, event.rawY)
                        service.updateCharmTouchLayout(event.rawX, event.rawY)
                        return true
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (isDragging) {
                        isDragging = false
                        val speed = hypot(touchVx, touchVy)
                        if (speed > 50f) {
                            service.displayView?.onCharmFling(touchVx, touchVy)
                        } else {
                            service.displayView?.onCharmTap()
                        }
                        return true
                    }
                }
            }
            return super.onTouchEvent(event)
        }
    }
}
