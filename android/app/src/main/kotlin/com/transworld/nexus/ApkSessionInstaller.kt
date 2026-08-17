package com.transworld.nexus

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.lang.ref.WeakReference

/// Instala un APK vía [PackageInstaller] (sesión nativa).
///
/// A diferencia de ACTION_VIEW / FileProvider, el sistema lee los bytes que
/// esta app escribe en la sesión: no depende de que el instalador pueda abrir
/// un content:// del cache. El resultado (éxito, firma, downgrade, etc.)
/// vuelve a Dart en vez de un "no se instaló" mudo del OEM.
object ApkSessionInstaller {
    const val CHANNEL = "com.transworld.nexus/apk_installer"
    const val ACTION_INSTALL_STATUS = "com.transworld.nexus.INSTALL_STATUS"

    @Volatile
    private var pendingResult: MethodChannel.Result? = null

    @Volatile
    private var activityRef: WeakReference<Activity>? = null

    fun install(activity: Activity, apkPath: String, result: MethodChannel.Result) {
        pendingResult = result
        activityRef = WeakReference(activity)

        val file = File(apkPath)
        if (!file.exists() || file.length() == 0L) {
            complete(
                ok = false,
                status = -1,
                legacyStatus = 0,
                message = "No se encontró el APK descargado.",
            )
            return
        }

        try {
            val installer = activity.packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL,
            )
            params.setSize(file.length())
            params.setAppPackageName(activity.packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                params.setRequireUserAction(
                    PackageInstaller.SessionParams.USER_ACTION_REQUIRED,
                )
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                params.setPackageSource(PackageInstaller.PACKAGE_SOURCE_DOWNLOADED_FILE)
            }

            val sessionId = installer.createSession(params)
            val session = installer.openSession(sessionId)
            try {
                session.openWrite("regispro.apk", 0, file.length()).use { out ->
                    file.inputStream().use { input -> input.copyTo(out) }
                    session.fsync(out)
                }
                val statusIntent = Intent(activity, ApkInstallResultReceiver::class.java).apply {
                    action = ACTION_INSTALL_STATUS
                }
                var flags = PendingIntent.FLAG_UPDATE_CURRENT
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    flags = flags or PendingIntent.FLAG_MUTABLE
                }
                val pending = PendingIntent.getBroadcast(
                    activity,
                    sessionId,
                    statusIntent,
                    flags,
                )
                session.commit(pending.intentSender)
            } catch (e: Exception) {
                try {
                    session.abandon()
                } catch (_: Exception) {
                }
                throw e
            } finally {
                try {
                    session.close()
                } catch (_: Exception) {
                }
            }
        } catch (e: Exception) {
            complete(
                ok = false,
                status = -1,
                legacyStatus = 0,
                message = e.message ?: "No se pudo iniciar la instalación.",
            )
        }
    }

    fun handleStatus(context: Context, intent: Intent) {
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm = extraIntent(intent) ?: run {
                    complete(
                        ok = false,
                        status = status,
                        legacyStatus = 0,
                        message = "El sistema no entregó la pantalla de instalación.",
                    )
                    return
                }
                confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                Handler(Looper.getMainLooper()).post {
                    try {
                        val activity = activityRef?.get()
                        if (activity != null && !activity.isFinishing) {
                            activity.startActivity(confirm)
                        } else {
                            context.applicationContext.startActivity(confirm)
                        }
                    } catch (e: Exception) {
                        complete(
                            ok = false,
                            status = status,
                            legacyStatus = 0,
                            message = e.message ?: "No se pudo abrir el instalador.",
                        )
                    }
                }
            }
            PackageInstaller.STATUS_SUCCESS -> complete(
                ok = true,
                status = status,
                legacyStatus = 0,
                message = null,
            )
            else -> complete(
                ok = false,
                status = status,
                legacyStatus = intent.getIntExtra(PackageInstaller.EXTRA_LEGACY_STATUS, 0),
                message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE),
            )
        }
    }

    private fun extraIntent(intent: Intent): Intent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_INTENT)
        }
    }

    private fun complete(
        ok: Boolean,
        status: Int,
        legacyStatus: Int,
        message: String?,
    ) {
        val result = pendingResult ?: return
        pendingResult = null
        Handler(Looper.getMainLooper()).post {
            result.success(
                hashMapOf(
                    "ok" to ok,
                    "status" to status,
                    "legacyStatus" to legacyStatus,
                    "message" to (message ?: ""),
                ),
            )
        }
    }
}

class ApkInstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ApkSessionInstaller.handleStatus(context, intent)
    }
}
