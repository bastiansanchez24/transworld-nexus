package com.transworld.nexus

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferHighestRefreshRate()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        preferHighestRefreshRate()
    }

    /// Pide el modo de pantalla con mayor Hz (90/120/144) para que
    /// Choreographer/Flutter vsync corran por encima de 60 fps.
    private fun preferHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val display: Display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display ?: return
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }

        val best = display.supportedModes.maxByOrNull { it.refreshRate } ?: return
        val attrs = window.attributes
        if (attrs.preferredDisplayModeId != best.modeId) {
            attrs.preferredDisplayModeId = best.modeId
            window.attributes = attrs
        }
    }
}
