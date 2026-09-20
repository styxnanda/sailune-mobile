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
    private var sessions: WebsiteSessions? = null
    private var login: SiteLoginDialog? = null
    private var loginResult: MethodChannel.Result? = null
    private var sessionBusy = false
    private var runningCalls = 0
    private var storyBrowser: SilentStoryBrowser? = null
    private var pendingDocument: MethodChannel.Result? = null
    private var exportData: String? = null
    private val maxBackupBytes = 16 * 1024 * 1024

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sessions = runCatching { WebsiteSessions(this) }.getOrNull()
        sessions?.let { client.setWebsiteSession(it) }
        storyBrowser = SilentStoryBrowser(this, { id, url, html, error -> client.browserResult(id, url, html, error) }).also { client.setBrowser(it) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.sailune.mobile/library")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "call" -> {
                        val id = call.argument<String>("id")
                        val payload = call.argument<String>("payload")
                        if (sessionBusy) { result.error("session", "Finish website sign-in first", null); return@setMethodCallHandler }
                        if (id == null || payload == null) result.error("request", "Missing library request", null)
                        else try {
                            // Register on the platform thread before scheduling, so a
                            // quick Cancel cannot race ahead of Go registration.
                            client.prepare(id)
                            runningCalls++
                            background(result) {
                                try { client.call(id, payload) }
                                finally { runOnUiThread { runningCalls-- } }
                            }
                        } catch (e: Exception) { result.error("library", e.message, null) }
                    }
                    "cancel" -> { client.cancel(call.arguments as? String ?: ""); result.success(null) }
                    "openLink" -> {
                        val uri = Uri.parse(call.arguments as? String ?: "")
                        val hosts = setOf("archiveofourown.org", "www.archiveofourown.org", "www.fanfiction.net", "fanfiction.net")
                        if (uri.scheme != "https" || uri.host !in hosts || uri.userInfo != null) {
                            result.error("url", "Unsupported story link", null)
                        } else try { androidx.browser.customtabs.CustomTabsIntent.Builder()
                            .setShowTitle(true)
                            .setColorScheme(when (getPreferences(MODE_PRIVATE).getString("theme", "system")) {
                                "dark" -> androidx.browser.customtabs.CustomTabsIntent.COLOR_SCHEME_DARK
                                "light" -> androidx.browser.customtabs.CustomTabsIntent.COLOR_SCHEME_LIGHT
                                else -> androidx.browser.customtabs.CustomTabsIntent.COLOR_SCHEME_SYSTEM
                            })
                            .build().launchUrl(this, uri)
                            result.success(null) }
                        catch (_: Exception) { result.error("browser", "No browser is available to open this story", null) }
                    }
                    "websiteSessions" -> result.success(sessions?.status() ?: mapOf("ao3" to false, "ffn" to false))
                    "connectWebsite" -> {
                        val site = call.argument<String>("site")
                        if (call.argument<Boolean>("consent") != true || site !in setOf("ao3", "ffn")) {
                            result.error("session", "Explicit website consent is required", null)
                        } else if (sessions == null) {
                            result.error("session", "Android WebView is unavailable. Enable or update Android System WebView, then restart Sailune", null)
                        } else if (sessionBusy || runningCalls != 0) {
                            result.error("busy", "Wait for the current operation to finish", null)
                        } else try {
                            sessions!!.enable(site!!)
                            sessionBusy = true
                            loginResult = result
                            login = SiteLoginDialog(this, site, { verified ->
                                login = null; sessionBusy = false
                                try {
                                    if (verified) sessions!!.confirm(site)
                                    loginResult?.success(verified)
                                } catch (_: Exception) { loginResult?.error("session", "Could not save sign-in. Please try again.", null) }
                                loginResult = null
                            }, appearance = getPreferences(MODE_PRIVATE).getString("theme", "system") ?: "system").also { it.open() }
                        } catch (_: Exception) {
                            sessionBusy = false; loginResult = null
                            login?.dismiss(); login = null
                            result.error("session", "Could not open website sign-in", null)
                        }
                    }
                    "clearWebsiteSessions" -> {
                        if (call.argument<Boolean>("consent") != true) {
                            result.error("session", "Confirm clearing website sessions", null)
                        } else if (sessions == null) {
                            result.error("session", "Android WebView is unavailable. Enable or update Android System WebView, then restart Sailune", null)
                        } else if (sessionBusy || runningCalls != 0) {
                            result.error("busy", "Wait for the current operation to finish", null)
                        } else {
                            sessionBusy = true
                            try { sessions!!.clear { success ->
                                sessionBusy = false
                                if (success) result.success(null)
                                else result.error("session", "Could not clear website sessions", null)
                            } } catch (_: Exception) {
                                sessionBusy = false
                                result.error("session", "Could not clear website sessions", null)
                            }
                        }
                    }
                    "loadOnboarding" -> result.success(getPreferences(MODE_PRIVATE).getBoolean("onboardingComplete", false))
                    "completeOnboarding" -> background(result) {
                        check(getPreferences(MODE_PRIVATE).edit().putBoolean("onboardingComplete", true).commit()) { "Could not save welcome tour" }
                        null
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
                    "loadArtworkPreferences" -> result.success(mapOf("mode" to getPreferences(MODE_PRIVATE).getString("coverMode", "hidden"), "details" to getPreferences(MODE_PRIVATE).getBoolean("detailArt", true)))
                    "saveArtworkPreferences" -> {
                        val mode = call.argument<String>("mode") ?: "hidden"
                        if (mode !in setOf("hidden", "portrait", "background")) result.error("appearance", "Invalid cover mode", null)
                        else background(result) { check(getPreferences(MODE_PRIVATE).edit().putString("coverMode", mode).putBoolean("detailArt", call.argument<Boolean>("details") ?: true).commit()); null }
                    }
                    "artworkData" -> background(result) { client.artworkData(call.argument<String>("asset") ?: "", call.argument<Boolean>("small") ?: true) }
                    "previewArtwork" -> background(result) { client.previewArtwork(checkedImagePath(call.argument<String>("path") ?: ""), call.argument<String>("role") ?: "cover", call.argument<Double>("x") ?: 0.5, call.argument<Double>("y") ?: 0.5) }
                    "discardImage" -> background(result) { java.io.File(checkedImagePath(call.arguments as? String ?: "")).delete(); null }
                    "pickImage", "exportArchive", "importArchive" -> {
                        if (pendingDocument != null) result.error("busy", "A file picker is already open", null)
                        else {
                            val code = when(call.method) { "pickImage" -> 712; "exportArchive" -> 713; else -> 714 }
                            val intent = Intent(if (code == 713) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = if (code == 712) "image/*" else if (code == 713) "application/zip" else "*/*"
                                if (code == 712) putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/png"))
                                if (code == 713) putExtra(Intent.EXTRA_TITLE, "sailune-${System.currentTimeMillis()}.zip")
                            }
                            pendingDocument = result
                            try { startActivityForResult(intent, code) } catch (_: Exception) { pendingDocument = null; result.error("files", "No document picker is available", null) }
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

    private fun checkedImagePath(path: String): String {
        val file = java.io.File(path).canonicalFile
        check(file.parentFile == cacheDir.canonicalFile && file.name.startsWith("sailune-image-")) { "Invalid artwork selection" }
        return file.absolutePath
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
        if (requestCode !in 710..714) return
        val result = pendingDocument ?: return
        val snapshot = exportData
        pendingDocument = null; exportData = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == 710 || requestCode == 713) false else null); return
        }
        if (requestCode in 712..714) {
            background(result) {
                val temp = java.io.File.createTempFile(if (requestCode == 712) "sailune-image-" else "sailune-backup-", ".tmp", cacheDir)
                var keep = false
                try {
                    if (requestCode == 713) {
                        // Core publishes a completed archive without overwriting an existing file.
                        check(temp.delete())
                        client.exportBackup(temp.absolutePath)
                        contentResolver.openOutputStream(uri, "wt")?.use { out -> temp.inputStream().use { it.copyTo(out) } } ?: error("Could not write backup")
                        true
                    } else {
                        val limit = if (requestCode == 712) 25L * 1024 * 1024 else 512L * 1024 * 1024
                        contentResolver.openInputStream(uri)?.use { input -> temp.outputStream().use { out ->
                            val buffer = ByteArray(65536); var size = 0L
                            while (true) { val n = input.read(buffer); if (n < 0) break; size += n; check(size <= limit) { "Selected file exceeds ${limit / 1024 / 1024} MiB" }; out.write(buffer, 0, n) }
                        } } ?: error("Could not read selected file")
                        if (requestCode == 712) { keep = true; temp.absolutePath } else client.importBackup(temp.absolutePath)
                    }
                } finally { if (!keep) temp.delete() }
            }
            return
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
        loginResult?.error("cancelled", "Sign-in closed; your website session remains on this device", null)
        loginResult = null
        login?.dismiss(); login = null
        client.close()
        storyBrowser?.close(); storyBrowser = null
        workers.shutdown()
        super.onDestroy()
    }
}
