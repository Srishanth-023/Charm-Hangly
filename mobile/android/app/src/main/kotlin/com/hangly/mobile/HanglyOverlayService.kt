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
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
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
    var charmTouchView: CharmTouchView? = null
        private set
    private var screenReceiver: BroadcastReceiver? = null

    private var displayParams: WindowManager.LayoutParams? = null
    private var charmTouchParams: WindowManager.LayoutParams? = null

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var sensorListener: SensorEventListener? = null

    var gravityX: Float = 0f
        private set
    var gravityY: Float = 1f
        private set

    // Fixed to the top right (between center 0.50 and right edge 1.00 = 0.75)
    var anchorX: Float = 0f
        private set
    var anchorY: Float = 0f
        private set

    var hapticsEnabled: Boolean = true
        private set

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
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        registerScreenReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_OVERLAY -> {
                stopSensorListening()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_HIDE_OVERLAY -> {
                stopSensorListening()
                displayView?.visibility = View.GONE
                charmTouchView?.visibility = View.GONE
                displayView?.pause()
                return START_STICKY
            }
            ACTION_SHOW_OVERLAY, null -> {
                val charmBytes = intent?.getByteArrayExtra("charmBytes")
                val ropeColor = intent?.getStringExtra("ropeColor") ?: "#FFD700"
                val ropeLength = intent?.getFloatExtra("ropeLength", 135f) ?: 135f
                val charmRadius = intent?.getFloatExtra("charmRadius", 25f) ?: 25f
                if (intent?.hasExtra("hapticsEnabled") == true) {
                    hapticsEnabled = intent.getBooleanExtra("hapticsEnabled", true)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !android.provider.Settings.canDrawOverlays(this)) {
                    android.util.Log.w("HanglyOverlay", "Missing Settings.canDrawOverlays permission!")
                    return START_STICKY
                }

                if (displayView == null) {
                    showOverlayWindow(charmBytes, ropeColor, ropeLength, charmRadius)
                } else {
                    displayView?.updateConfig(charmBytes, ropeColor, ropeLength, charmRadius)
                    displayView?.visibility = View.VISIBLE
                    charmTouchView?.visibility = View.VISIBLE

                    val density = resources.displayMetrics.density
                    val newTouchSize = max(64f * density, charmRadius * density * 2.4f).toInt()
                    charmTouchParams?.let { cp ->
                        cp.width = newTouchSize
                        cp.height = newTouchSize
                        cp.x = (anchorX - newTouchSize / 2f).toInt()
                        cp.y = (anchorY + ropeLength * density - newTouchSize / 2f).toInt()
                        try {
                            windowManager?.updateViewLayout(charmTouchView, cp)
                        } catch (_: Exception) {}
                    }

                    displayView?.requestLayout()
                    displayView?.resume()
                    displayView?.wake()
                }
                startSensorListening()
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
                    Intent.ACTION_SCREEN_OFF -> {
                        displayView?.pause()
                        stopSensorListening()
                    }
                    Intent.ACTION_SCREEN_ON -> {
                        displayView?.resume()
                        startSensorListening()
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        registerReceiver(screenReceiver, filter)
    }

    private fun startSensorListening() {
        if (sensorListener != null || accelerometer == null) return
        sensorListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (event == null) return
                // Android accelerometer measures proper acceleration (reaction force: -Gx).
                // When tilted right, event.values[0] is negative.
                // Negating it gives positive gravity pointing towards the right in screen coordinates (+X = right).
                var rawX = -event.values[0] / 9.81f
                val rawY = event.values[1] / 9.81f

                // Deadzone to prevent small hand vibrations from shaking the charm
                if (abs(rawX) < 0.06f) {
                    rawX = 0f
                } else {
                    rawX = if (rawX > 0f) (rawX - 0.06f) else (rawX + 0.06f)
                }

                // Reduced sensitivity factor (0.35) for calm, gentle, organic tilt sway
                val targetGx = rawX * 0.35f
                val targetGy = if (rawY > 0f) max(0.5f, rawY) else kotlin.math.min(-0.5f, rawY)

                val oldGx = gravityX
                val oldGy = gravityY

                // Smooth low-pass filter (0.10 for fluid, dampened tilt response)
                gravityX += (targetGx - gravityX) * 0.10f
                gravityY += (targetGy - gravityY) * 0.10f

                if (abs(gravityX - oldGx) > 0.015f || abs(gravityY - oldGy) > 0.015f) {
                    displayView?.wake()
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        sensorManager?.registerListener(
            sensorListener,
            accelerometer,
            SensorManager.SENSOR_DELAY_GAME
        )
    }

    private fun stopSensorListening() {
        sensorListener?.let {
            sensorManager?.unregisterListener(it)
            sensorListener = null
        }
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

        // Fixed to the top right (between center 0.50 and right edge 1.00 = 0.75 * screenWidth)
        anchorX = screenWidth * 0.75f
        anchorY = 16f * density

        // 1. FULL-SCREEN DISPLAY OVERLAY VIEW
        // Spans the full screen so rope and charm swing with zero clipping.
        // FLAG_NOT_TOUCHABLE guarantees 100% touch pass-through to all underlying apps.
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

        // 2. CHARM TOUCH TARGET
        // Sits right on top of the hanging charm at top right.
        // Allows the user to grab and fling the charm directly.
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
            windowManager?.addView(cView, cParams)

            dView.visibility = View.VISIBLE
            cView.visibility = View.VISIBLE
            dView.wake()
        } catch (e: Exception) {
            e.printStackTrace()
        }
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
        stopSensorListening()
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
        charmTouchView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        displayView = null
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

        // Fixed to top right (0.75 * width)
        val anchorX: Float get() = width.takeIf { it > 0 }?.times(0.75f) ?: service.anchorX
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

            // Pinned anchor at top right
            points.add(Point(curAnchorX, curAnchorY, curAnchorX, curAnchorY, isPinned = true))

            for (i in 1..segmentCount) {
                val py = curAnchorY + (i * segLen)
                // Gentle initial sway offset
                val swayOffset = (i.toFloat() / segmentCount) * (10f * density)
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
                last.oldX -= 25f * density
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

            val gx = service.gravityX
            val gy = service.gravityY

            val gravityStepX = gx * gravity * dt * dt
            val gravityStepY = gy * gravity * dt * dt

            // 1. Verlet Integration
            for (i in 1 until points.size) {
                val p = points[i]
                if (i == points.size - 1 && isDraggingCharm) continue

                val vx = (p.x - p.oldX) * damping
                val vy = (p.y - p.oldY) * damping

                p.oldX = p.x
                p.oldY = p.y
                p.x += vx + gravityStepX
                p.y += vy + gravityStepY
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
            if (!isDraggingCharm) {
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

            // 2. Draw Fixed Top Anchor Knot / Ring
            canvas.drawCircle(curAnchorX, curAnchorY, 6.5f * density, knotPaint)
            canvas.drawCircle(curAnchorX, curAnchorY, 2.5f * density, knotCorePaint)

            // 3. Calculate Charm Angle from last rope segment
            val secondLast = points[points.size - 2]
            val angleRad = atan2(last.y - secondLast.y, last.x - secondLast.x) - (Math.PI / 2.0).toFloat()
            val angleDeg = Math.toDegrees(angleRad.toDouble()).toFloat()

            // 4. Draw Charm Artwork (Bitmap or Fallback)
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
    // 2. CHARM TOUCH VIEW (Interactive Charm Target at Top Right)
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
                    if (service.hapticsEnabled) {
                        performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
                    }
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
                        if (service.hapticsEnabled) {
                            performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
                        }
                        return true
                    }
                }
            }
            return super.onTouchEvent(event)
        }
    }
}
