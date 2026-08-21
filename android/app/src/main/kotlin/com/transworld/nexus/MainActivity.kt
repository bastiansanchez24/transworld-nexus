package com.transworld.nexus

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CANAL_PUSH_ID = "nexus_registros"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ApkSessionInstaller.CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "installApk") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) {
                result.error("missing_path", "Ruta del APK vacía.", null)
                return@setMethodCallHandler
            }
            ApkSessionInstaller.install(this, path, result)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        crearCanalNotificacionesPush()
        skipSystemSplashExitAnimation()
        preferHighestRefreshRate()
    }

    /// El canal tiene que existir en el NotificationManager nativo: FCM pinta
    /// el aviso en segundo plano sin pasar por Dart. Si el payload trae
    /// `nexus_registros` y el canal no está creado, Android 8+ lo tira.
    private fun crearCanalNotificacionesPush() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val canal = NotificationChannel(
            CANAL_PUSH_ID,
            "Registros de eventos",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Avisos cuando alguien se registra a un evento."
            enableVibration(true)
            setShowBadge(true)
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(canal)
    }

    /// Android 12+ anima el icono al salir del splash nativo. Esa animacion
    /// se suma al Lottie de Flutter y deja el logo congelado encima de la
    /// UI hasta que termina. Al primer frame, quitar el splash de golpe.
    private fun skipSystemSplashExitAnimation() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        splashScreen.setOnExitAnimationListener { splashView ->
            splashView.remove()
        }
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
