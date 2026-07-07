package com.example.openclaw_remote

import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    /**
     * PARTIAL_WAKE_LOCK keeps the CPU running even if the display turns off
     * (e.g. brief power-button press on LineageOS).
     * FLAG_KEEP_SCREEN_ON ensures the display itself never sleeps while the
     * Activity is in the foreground — this is the most reliable Android
     * mechanism, stronger than the manifest attribute alone.
     */
    private var _wakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ── Display: never let the screen sleep while this Activity is shown ──
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // ── CPU: keep processing even if display accidentally turns off ──
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        _wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "OpenClaw::AlwaysOnWakeLock"
        ).also { wl ->
            wl.setReferenceCounted(false)
            wl.acquire() // Held until release() — never times out
        }
    }

    override fun onResume() {
        super.onResume()
        // Re-assert the display flag in case the system cleared it during pause.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onDestroy() {
        // Release the WakeLock when the app is fully closed (not just backgrounded).
        _wakeLock?.let { if (it.isHeld) it.release() }
        _wakeLock = null
        super.onDestroy()
    }
}
