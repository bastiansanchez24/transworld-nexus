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
        val diag = apkInstallDiagnostics(activity, file)
        // #region agent log
        debugOtaLog(
            hypothesisId = "H-A",
            location = "ApkSessionInstaller.kt:install",
            message = "session install start",
            data = diag,
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

        when (signaturesMatch(activity.packageManager, activity.packageName, apkPath)) {
            false -> {
                // #region agent log
                debugOtaLog(
                    hypothesisId = "H-C",
                    location = "ApkSessionInstaller.kt:install",
                    message = "signature mismatch precheck",
                    data = """{"signMatch":false}""",
                )
                // #endregion
                complete(
                    ok = false,
                    status = 4,
                    legacyStatus = -7,
                    message = "INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match",
                )
                return
            }
            else -> Unit
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
                status == PackageInstaller.STATUS_PENDING_USER_ACTION -> "H-C"
                status == PackageInstaller.STATUS_SUCCESS -> "H-A"
                status == PackageInstaller.STATUS_FAILURE_INCOMPATIBLE ||
                    status == 5 ||
                    legacyStatus == -25 ||
                    legacyStatus == -9 ||
                    legacyStatus == -113 -> "H-A"
                status == 4 || legacyStatus == -7 -> "H-C"
                else -> "H-B"
            },
            location = "ApkSessionInstaller.kt:handleStatus",
            message = "PackageInstaller status",
            data = """{"status":$status,"legacyStatus":$legacyStatus,"systemMessage":${jsonString(statusMessage)},"hasConfirmIntent":${confirmIntent != null},"sdk":${Build.VERSION.SDK_INT},"abis":${jsonString(Build.SUPPORTED_ABIS.joinToString())}}""",
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

    private fun apkInstallDiagnostics(context: Context, file: File): String {
        val pm = context.packageManager
        var apkPkg = ""
        var apkVersionName = ""
        var apkVersionCode = -1L
        var installedVersionName = ""
        var installedVersionCode = -1L
        var minSdk = -1
        var signMatch = "unknown"
        try {
            val apkInfo = pm.getPackageArchiveInfo(file.absolutePath, 0)
            if (apkInfo != null) {
                apkPkg = apkInfo.packageName ?: ""
                apkVersionName = apkInfo.versionName ?: ""
                apkVersionCode = packageVersionCode(apkInfo)
                apkInfo.applicationInfo?.minSdkVersion?.let { minSdk = it }
            }
        } catch (_: Exception) {
        }
        try {
            val installed = pm.getPackageInfo(context.packageName, 0)
            installedVersionName = installed.versionName ?: ""
            installedVersionCode = packageVersionCode(installed)
        } catch (_: Exception) {
        }
        try {
            signMatch = signaturesMatch(pm, context.packageName, file.absolutePath).toString()
        } catch (_: Exception) {
        }
        val header = try {
            file.inputStream().use { ins ->
                val buf = ByteArray(4)
                val n = ins.read(buf)
                if (n < 4) "short" else buf.joinToString("") { b -> "%02x".format(b) }
            }
        } catch (_: Exception) {
            "err"
        }
        return """{"fileLen":${file.length()},"exists":${file.exists()},"magic":"$header","apkPkg":${jsonString(apkPkg)},"apkVersionName":${jsonString(apkVersionName)},"apkVersionCode":$apkVersionCode,"installedVersionName":${jsonString(installedVersionName)},"installedVersionCode":$installedVersionCode,"minSdk":$minSdk,"signMatch":${jsonString(signMatch)},"sdk":${Build.VERSION.SDK_INT},"abis":${jsonString(Build.SUPPORTED_ABIS.joinToString())},"selfPkg":${jsonString(context.packageName)}}"""
    }

    @Suppress("DEPRECATION")
    private fun packageVersionCode(info: android.content.pm.PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
    }

    @Suppress("DEPRECATION")
    private fun signaturesMatch(pm: android.content.pm.PackageManager, packageName: String, apkPath: String): Boolean? {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            android.content.pm.PackageManager.GET_SIGNATURES
        }
        val apkInfo = pm.getPackageArchiveInfo(apkPath, flags) ?: return null
        apkInfo.applicationInfo?.apply {
            sourceDir = apkPath
            publicSourceDir = apkPath
        }
        val installed = try {
            pm.getPackageInfo(packageName, flags)
        } catch (_: Exception) {
            return null
        }
        val apkSigs = signerBytes(apkInfo)
        val instSigs = signerBytes(installed)
        if (apkSigs.isEmpty() || instSigs.isEmpty()) return null
        return apkSigs.any { a -> instSigs.any { b -> a.contentEquals(b) } }
    }

    @Suppress("DEPRECATION")
    private fun signerBytes(info: android.content.pm.PackageInfo): List<ByteArray> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val si = info.signingInfo ?: return emptyList()
            val signers = if (si.hasMultipleSigners()) si.apkContentsSigners else si.signingCertificateHistory
            signers?.map { it.toByteArray() } ?: emptyList()
        } else {
            info.signatures?.map { it.toByteArray() } ?: emptyList()
        }
    }

    private fun debugOtaLog(
        hypothesisId: String,
        location: String,
        message: String,
        data: String,
    ) {
        Thread {
            val payload =
                """{"sessionId":"23a43f","runId":"pre-fix","hypothesisId":"$hypothesisId","location":"$location","message":"$message","data":$data,"timestamp":${System.currentTimeMillis()}}"""
            try {
                Log.i("OTADebug", payload)
            } catch (_: Exception) {
            }
            val hosts = arrayOf(
                "http://127.0.0.1:7917/ingest/9fa0e09b-80df-4c81-86c4-f4966a429947",
                "http://10.0.2.2:7917/ingest/9fa0e09b-80df-4c81-86c4-f4966a429947",
            )
            for (host in hosts) {
                try {
                    val url = java.net.URL(host)
                    val conn = url.openConnection() as java.net.HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.setRequestProperty("X-Debug-Session-Id", "23a43f")
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
            }
            try {
                val dir = activityRef?.get()?.filesDir
                if (dir != null) {
                    java.io.File(dir, "debug-23a43f.log").appendText(payload + "\n")
                }
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
