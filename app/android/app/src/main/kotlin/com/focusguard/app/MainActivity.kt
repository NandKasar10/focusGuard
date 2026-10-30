package com.focusguard.app

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val USAGE_CHANNEL = "com.focusguard/usage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getForegroundApp" -> {
                    result.success(getForegroundApp())
                }
                "hasUsagePermission" -> {
                    result.success(hasUsagePermission())
                }
                "openUsageSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "hasOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }
                "openOverlaySettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            ).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                        } else {
                            Intent(Settings.ACTION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "getDailyUsageStats" -> {
                    result.success(getDailyUsageStats())
                }
                "bringToFront" -> {
                    bringToFront()
                    result.success(true)
                }
                "startForegroundService" -> {
                    FocusGuardService.start(this)
                    result.success(true)
                }
                "stopForegroundService" -> {
                    FocusGuardService.stop(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == android.app.AppOpsManager.MODE_ALLOWED
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun getForegroundApp(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()

        // 1. Inspect recent events over the past 30 minutes to find the latest active activity
        try {
            val events = usm.queryEvents(now - 1000 * 60 * 30, now)
            var lastApp: String? = null
            var lastResumeTime: Long = 0
            val event = UsageEvents.Event()

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                // ACTIVITY_RESUMED is event type 1
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED || event.eventType == 1) {
                    if (event.timeStamp >= lastResumeTime) {
                        lastResumeTime = event.timeStamp
                        lastApp = event.packageName
                    }
                }
            }
            if (lastApp != null) {
                return lastApp
            }
        } catch (_: Exception) {}

        // 2. Fallback: query usage stats for the last hour and get the one with latest lastTimeUsed
        try {
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, now - 1000 * 60 * 60, now)
            val mostRecent = stats?.filter { it.lastTimeUsed > 0 && it.packageName != packageName }
                ?.maxByOrNull { it.lastTimeUsed }
            if (mostRecent != null) {
                return mostRecent.packageName
            }
        } catch (_: Exception) {}

        return null
    }

    private fun getDailyUsageStats(): Map<String, Long> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startOfDay = cal.timeInMillis
        val now = System.currentTimeMillis()

        val result = mutableMapOf<String, Long>()
        try {
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startOfDay, now) ?: emptyList()
            for (stat in stats) {
                if (stat.totalTimeInForeground > 0) {
                    val minutes = stat.totalTimeInForeground / (1000 * 60)
                    val existing = result[stat.packageName] ?: 0L
                    result[stat.packageName] = Math.max(existing, minutes)
                }
            }
        } catch (_: Exception) {}

        return result
    }

    private fun bringToFront() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(intent)
        } catch (_: Exception) {}
    }
}
