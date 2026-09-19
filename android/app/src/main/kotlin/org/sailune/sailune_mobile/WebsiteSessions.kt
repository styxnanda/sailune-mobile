package org.sailune.sailune_mobile

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import android.webkit.WebStorage
import mobile.WebsiteSession
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** CookieManager owns all cookie persistence; preferences contain consent only. */
internal class WebsiteSessions(context: Context) : WebsiteSession {
    private val appContext = context.applicationContext
    private val preferences = context.getSharedPreferences("website-sessions", Context.MODE_PRIVATE)
    private val handler = Handler(Looper.getMainLooper())
    private val cookies = CookieManager.getInstance()
    init { cookies.setAcceptCookie(true) }
    fun status() = mapOf("ao3" to enabled("ao3"), "ffn" to enabled("ffn"))
    fun enabled(site: String) = preferences.getBoolean(site, false)
    fun enable(site: String) {
        require(site in setOf("ao3", "ffn"))
        check(preferences.edit().putBoolean(site, true).commit()) { "Could not save website consent" }
    }
    override fun cookies(url: String): String {
        val site = site(url) ?: return ""
        return if (enabled(site)) cookies.getCookie(url) ?: "" else ""
    }
    override fun storeCookie(url: String, cookie: String) {
        val site = site(url) ?: return
        if (!enabled(site)) return
        // Go calls on a worker. Await WebView's async write so redirects use
        // rotated cookies; never block Android's UI thread waiting for itself.
        val done = CountDownLatch(1)
        val write = Runnable {
            if (!enabled(site)) { done.countDown(); return@Runnable }
            cookies.setCookie(url, cookie) { done.countDown() }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) { write.run(); return }
        handler.post(write)
        done.await(1, TimeUnit.SECONDS)
    }
    fun clear(done: (Boolean) -> Unit) {
        check(Looper.myLooper() == Looper.getMainLooper())
        // Revoke access first, even if removing stored website data fails.
        if (!preferences.edit().clear().commit()) { done(false); return }
        cookies.removeAllCookies {
            try {
                cookies.flush()
                WebStorage.getInstance().deleteAllData()
                android.webkit.WebView(appContext).let { it.clearCache(true); it.destroy() }
                done(true)
            } catch (_: Exception) { done(false) }
        }
    }
    companion object {
        fun site(raw: String): String? {
            val u = Uri.parse(raw)
            if (u.scheme != "https" || u.userInfo != null || u.port != -1) return null
            return when (u.host) {
                "archiveofourown.org", "www.archiveofourown.org" -> "ao3"
                "fanfiction.net", "www.fanfiction.net", "m.fanfiction.net" -> "ffn"
                else -> null
            }
        }
        fun loginURL(site: String) = when (site) {
            "ao3" -> "https://archiveofourown.org/users/login"
            "ffn" -> "https://www.fanfiction.net/login.php"
            else -> throw IllegalArgumentException("Unsupported website")
        }
    }
}
