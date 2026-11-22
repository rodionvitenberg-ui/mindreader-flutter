package quest.mindreader.mindreader

import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewTreeObserver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var flutterUiReady = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private val splashReleaseFallback = Runnable { releaseSplash() }
    private var preDrawListener: ViewTreeObserver.OnPreDrawListener? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Hold the native launch splash until Flutter paints its very first
        // frame (TaroPreloader on #0C101B) so there is zero black-screen gap
        // between the OS splash and Flutter's UI.
        val content: View? = findViewById(android.R.id.content)
        if (content != null) {
            val listener = object : ViewTreeObserver.OnPreDrawListener {
                override fun onPreDraw(): Boolean {
                    if (flutterUiReady) {
                        content.viewTreeObserver.removeOnPreDrawListener(this)
                        preDrawListener = null
                        return true
                    }
                    return false
                }
            }
            preDrawListener = listener
            content.viewTreeObserver.addOnPreDrawListener(listener)
            mainHandler.postDelayed(splashReleaseFallback, 2500L)
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        releaseSplash()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(splashReleaseFallback)
        val content: View? = findViewById(android.R.id.content)
        preDrawListener?.let { listener ->
            content?.viewTreeObserver?.removeOnPreDrawListener(listener)
            preDrawListener = null
        }
        super.onDestroy()
    }

    private fun releaseSplash() {
        if (flutterUiReady) return
        flutterUiReady = true
        mainHandler.removeCallbacks(splashReleaseFallback)
        findViewById<View>(android.R.id.content)?.invalidate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Tarot Tree G1: репортим поддержку Vulkan, чтобы дизайн-система
        // выбирала настоящий liquid glass на устройствах с Flutter GPU (Vulkan),
        // и FakeGlass — на остальных (Impeller OpenGLES).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "taro/glass_capability",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasVulkan" -> {
                    val pm = applicationContext.packageManager
                    val hasVulkan = pm.hasSystemFeature(
                        PackageManager.FEATURE_VULKAN_HARDWARE_LEVEL,
                    )
                    result.success(hasVulkan)
                }

                else -> result.notImplemented()
            }
        }
    }
}
