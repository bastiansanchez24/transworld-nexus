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
import android.util.Log
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

    // PackageInstaller.EXTRA_LEGACY_STATUS is @hide/@SystemApi and is stripped
    // from android.jar, so the public SDK cannot resolve the constant.
    private const val EXTRA_LEGACY_STATUS = "android.content.pm.extra.LEGACY_STATUS"

    @Volatile
    private var pendingResult: MethodChannel.Result? = null

    @Volatile
    private var activityRef: WeakReference<Activity>? = null

    fun install(activity: Activity, apkPath: String, result: MethodChannel.Result) {
        pendingResult = result
        activityRef = WeakReference(activity)

        val file = File(apkPath)
        // #region agent log
        debugOtaLog(
            hypothesisId = "H-B",
            location = "ApkSessionInstaller.kt:install",
            message = "session install start",
            data = """{"pathLen":${apkPath.length},"fileLen":${file.length()},"exists":${file.exists()},"packageName":${jsonString(activity.packageName)}}""",
        )
        // #endregion
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
        val legacyStatus = intent.getIntExtra(EXTRA_LEGACY_STATUS, 0)
        val statusMessage = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        val confirmIntent = extraIntent(intent)
        // #region agent log
        debugOtaLog(
            hypothesisId = when {
                status == PackageInstaller.STATUS_PENDING_USER_ACTION -> "H-A"
                status == PackageInstaller.STATUS_SUCCESS -> "H-A"
                status == 4 || legacyStatus == -7 -> "H-A"
                legacyStatus == -25 -> "H-C"
                else -> "H-B"
            },
            location = "ApkSessionInstaller.kt:handleStatus",
            message = "PackageInstaller status",
            data = """{"status":$status,"legacyStatus":$legacyStatus,"systemMessage":${jsonString(statusMessage)},"hasConfirmIntent":${confirmIntent != null}}""",
        )
        // #endregion
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm = confirmIntent ?: run {
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
                legacyStatus = legacyStatus,
                message = statusMessage,
            )
        }
    }

    // #region agent log
    private fun jsonString(value: String?): String {
        if (value == null) return "null"
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
    }

    private fun debugOtaLog(
        hypothesisId: String,
        location: String,
        message: String,
        data: String,
    ) {
        Thread {
            try {
                val payload =
                    """{"sessionId":"0b9d45","runId":"pre-fix","hypothesisId":"$hypothesisId","location":"$location","message":"$message","data":$data,"timestamp":${System.currentTimeMillis()}}"""
                Log.i("OTADebug", payload)
                val url = java.net.URL(
                    "http://127.0.0.1:7305/ingest/02f03f94-db5d-49ad-bd74-d663fc657326",
                )
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("X-Debug-Session-Id", "0b9d45")
                conn.connectTimeout = 800
                conn.readTimeout = 800
                conn.doOutput = true
                conn.outputStream.use { it.write(payload.toByteArray()) }
                try {
                    conn.inputStream.close()
                } catch (_: Exception) {
                }
                conn.disconnect()
            } catch (_: Exception) {
            }
        }.start()
    }
    // #endregion

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
