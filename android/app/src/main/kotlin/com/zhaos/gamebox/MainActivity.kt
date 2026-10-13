package com.zhaos.gamebox

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "canRequestInstall" -> result.success(canRequestInstall())
                        "openInstallPermission" -> {
                            openInstallPermission()
                            result.success(null)
                        }
                        "install" -> install(call.argument<String>("path"), result)
                        else -> result.notImplemented()
                    }
                }
    }

    /** Android 8 之前没有「安装未知应用」这套授权，装了就能装。 */
    private fun canRequestInstall(): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                    packageManager.canRequestPackageInstalls()

    private fun openInstallPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        // 少数定制 ROM 砍掉了这页；跳不过去就让系统在安装那一步自己拦。
        try {
            startActivity(intent)
        } catch (ignored: Exception) {
        }
    }

    /** 私有目录里的 APK 不能用 file:// 直接给安装器（Android 7+ 会抛 FileUriExposedException），
     *  必须经 FileProvider 换成带临时读授权的 content://。 */
    private fun install(path: String?, result: MethodChannel.Result) {
        val file = path?.let { File(it) }
        if (file == null || !file.exists()) {
            result.error("no_file", "安装包不存在：$path", null)
            return
        }
        try {
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, "application/vnd.android.package-archive")
                    .addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_ACTIVITY_NEW_TASK
                    )
            startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("install_failed", e.message, null)
        }
    }

    companion object {
        private const val CHANNEL = "com.zhaos.gamebox/install"
    }
}
