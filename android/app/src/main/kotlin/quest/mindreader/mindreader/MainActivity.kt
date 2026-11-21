package quest.mindreader.mindreader

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
