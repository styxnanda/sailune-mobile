package org.sailune.sailune_mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import mobile.Client
import mobile.Mobile
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** The worker pool keeps SQLite and HTTP off Android's UI thread. */
class MainActivity : FlutterActivity() {
    private val workers = Executors.newFixedThreadPool(3)
    private val client: Client by lazy { Mobile.newClient(java.io.File(filesDir, "library.sqlite3").absolutePath) }
    private var storyBrowser: SilentStoryBrowser? = null
    private var pendingDocument: MethodChannel.Result? = null
    private var exportData: String? = null
    private val maxBackupBytes = 16 * 1024 * 1024

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        storyBrowser = SilentStoryBrowser(this, { id, url, html, error -> client.browserResult(id, url, html, error) }).also { client.setBrowser(it) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.sailune.mobile/library")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "call" -> {
                        val id = call.argument<String>("id")
                        val payload = call.argument<String>("payload")
                        if (id == null || payload == null) result.error("request", "Missing library request", null)
                        else try {
                            // Register on the platform thread before scheduling, so a
                            // quick Cancel cannot race ahead of Go registration.
                            client.prepare(id)
                            background(result) { client.call(id, payload) }
                        } catch (e: Exception) { result.error("library", e.message, null) }
                    }
                    "cancel" -> { client.cancel(call.arguments as? String ?: ""); result.success(null) }
                    "openLink" -> {
                        val uri = Uri.parse(call.arguments as? String ?: "")
                        val hosts = setOf("archiveofourown.org", "www.archiveofourown.org", "www.fanfiction.net", "fanfiction.net")
                        if (uri.scheme != "https" || uri.host !in hosts || uri.userInfo != null) {
                            result.error("url", "Unsupported story link", null)
                        } else try { startActivity(Intent(Intent.ACTION_VIEW, uri)); result.success(null) }
                        catch (_: Exception) { result.error("browser", "No browser is available to open this story", null) }
                    }
                    "loadTheme" -> result.success(getPreferences(MODE_PRIVATE).getString("theme", "system"))
                    "saveTheme" -> {
                        val value = call.arguments as? String
                        if (value !in setOf("system", "light", "dark")) result.error("theme", "Invalid appearance", null)
                        else background(result) {
                            check(getPreferences(MODE_PRIVATE).edit().putString("theme", value).commit()) { "Could not save appearance" }
                            null
                        }
                    }
                    "saveBackup", "pickBackup" -> {
                        if (pendingDocument != null) { result.error("busy", "A file picker is already open", null) }
                        else {
                            val saving = call.method == "saveBackup"
                            val data = call.arguments as? String
                            if (saving && (data == null || data.toByteArray(Charsets.UTF_8).size > maxBackupBytes)) {
                                result.error("size", "Mobile backups are limited to 16 MiB", null)
                            } else {
                                pendingDocument = result
                                exportData = if (saving) data else null
                                val intent = Intent(if (saving) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "application/json"
                                    if (saving) putExtra(Intent.EXTRA_TITLE, "sailune-${System.currentTimeMillis()}.json")
                                    else putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                                }
                                try { startActivityForResult(intent, if (saving) 710 else 711) }
                                catch (_: Exception) { pendingDocument = null; exportData = null; result.error("files", "No document picker is available", null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        workers.execute {
            try { val value = work(); runOnUiThread { result.success(value) } }
            catch (e: Exception) { runOnUiThread { result.error("library", e.message ?: "Library operation failed", null) } }
        }
    }

    @Deprecated("Android activity result compatibility with FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 710 && requestCode != 711) return
        val result = pendingDocument ?: return
        val snapshot = exportData
        pendingDocument = null; exportData = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == 710) false else null); return
        }
        background(result) {
            if (requestCode == 710) {
                contentResolver.openOutputStream(uri, "wt")?.use { stream ->
                    stream.write(requireNotNull(snapshot).toByteArray(Charsets.UTF_8))
                } ?: error("Could not write this file")
                true
            } else {
                contentResolver.openInputStream(uri)?.use { stream ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = stream.read(buffer)
                        if (count == -1) break
                        if (output.size() + count > maxBackupBytes) error("Mobile backups are limited to 16 MiB")
                        output.write(buffer, 0, count)
                    }
                    output.toString("UTF-8")
                } ?: error("Could not read this file")
            }
        }
    }

    override fun onDestroy() {
        pendingDocument?.error("cancelled", "File picker closed; please try again", null)
        pendingDocument = null; exportData = null
        client.close()
        storyBrowser?.close(); storyBrowser = null
        workers.shutdown()
        super.onDestroy()
    }
}
