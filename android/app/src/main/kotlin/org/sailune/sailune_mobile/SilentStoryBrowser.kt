package org.sailune.sailune_mobile

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.*
import mobile.Browser
import org.json.JSONObject

/** On-demand, unattached WebView: no windows, prompts, JS bridge or user browser access. */
internal class SilentStoryBrowser(private val context: Context, private val deliver: (String, String, String, String) -> Unit,
    private val makeWebView: () -> WebView = { WebView(context) }) : Browser {
    private val handler = Handler(Looper.getMainLooper())
    private var web: WebView? = null
    private var active: String? = null
    private var closed = false
    private var poll: Runnable? = null
    private var deadline: Runnable? = null

    override fun begin(id: String, url: String, timeoutMillis: Long) {
        handler.post {
            if (closed || active != null || !allowed(url)) {
                deliver(id, "", "", "Browser unavailable")
                return@post
            }
            active = id
            try {
                val view = makeWebView()
                web = view
                view.settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    allowFileAccess = false
                    allowContentAccess = false
                    mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                    mediaPlaybackRequiresUserGesture = true
                    javaScriptCanOpenWindowsAutomatically = false
                    setSupportMultipleWindows(true)
                    // No images/media are needed to extract story headers.
                    loadsImagesAutomatically = false
                }
                CookieManager.getInstance().setAcceptCookie(true)
                CookieManager.getInstance().setAcceptThirdPartyCookies(view, false)
                view.webChromeClient = object : WebChromeClient() {
                    override fun onJsAlert(v: WebView?, u: String?, message: String?, result: JsResult): Boolean { result.cancel(); return true }
                    override fun onJsConfirm(v: WebView?, u: String?, message: String?, result: JsResult): Boolean { result.cancel(); return true }
                    override fun onJsBeforeUnload(v: WebView?, u: String?, message: String?, result: JsResult): Boolean { result.cancel(); return true }
                    override fun onJsPrompt(v: WebView?, u: String?, message: String?, defaultValue: String?, result: JsPromptResult): Boolean { result.cancel(); return true }
                    override fun onPermissionRequest(request: PermissionRequest) { request.deny() }
                    override fun onGeolocationPermissionsShowPrompt(origin: String, callback: GeolocationPermissions.Callback) { callback.invoke(origin, false, false) }
                }
                view.webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(v: WebView, request: WebResourceRequest): Boolean {
                        if (request.isForMainFrame && !allowed(request.url.toString())) {
                            finish(id, "", "", "Unsupported navigation"); return true
                        }
                        return false
                    }
                    override fun onReceivedSslError(v: WebView, h: SslErrorHandler, e: android.net.http.SslError) {
                        h.cancel(); finish(id, "", "", "TLS failure")
                    }
                    override fun onReceivedHttpAuthRequest(v: WebView, h: HttpAuthHandler, host: String, realm: String) { h.cancel() }
                    override fun onReceivedError(v: WebView, r: WebResourceRequest, e: WebResourceError) {
                        if (r.isForMainFrame) finish(id, "", "", "Page unavailable")
                    }
                    override fun onRenderProcessGone(v: WebView, detail: RenderProcessGoneDetail): Boolean {
                        finish(id, "", "", "Renderer stopped"); return true
                    }
                }
                deadline = Runnable { finish(id, "", "", "Browser deadline exceeded") }.also {
                    handler.postDelayed(it, timeoutMillis.coerceIn(1, 15000))
                }
                poll = object : Runnable {
                    override fun run() {
                        if (active != id || web !== view) return
                        view.evaluateJavascript(EXTRACT) { raw ->
                            if (active != id || web !== view) return@evaluateJavascript
                            try {
                                val page = JSONObject(raw)
                                val html = page.optString("html")
                                val finalUrl = page.optString("url")
                                if (html.isNotEmpty() && html.toByteArray(Charsets.UTF_8).size <= 1048576 && allowed(finalUrl)) {
                                    finish(id, finalUrl, html, ""); return@evaluateJavascript
                                }
                            } catch (_: Exception) { /* Page still loading or challenged. */ }
                            handler.postDelayed(this, 400)
                        }
                    }
                }
                view.loadUrl(url)
                handler.postDelayed(poll!!, 400)
            } catch (_: Exception) { finish(id, "", "", "WebView unavailable") }
        }
    }

    override fun cancel(id: String) { handler.post { if (active == id) release() } }
    fun close() { closed = true; active?.let { finish(it, "", "", "Activity closed") }; release() }

    private fun finish(id: String, url: String, html: String, error: String) {
        if (active != id) return
        release()
        deliver(id, url, html, error)
    }
    private fun release() {
        active = null
        poll?.let(handler::removeCallbacks); poll = null
        deadline?.let(handler::removeCallbacks); deadline = null
        web?.let { view ->
            web = null
            view.stopLoading()
            view.destroy()
            CookieManager.getInstance().flush()
        }
    }
    private fun allowed(url: String): Boolean {
        val u = Uri.parse(url)
        return u.scheme == "https" && u.userInfo == null && u.port == -1 &&
            u.host in setOf("www.fanfiction.net", "fanfiction.net", "m.fanfiction.net")
    }
    companion object {
        private const val EXTRACT = """(()=>{const p=document.querySelector('#profile_top');if(!p||!p.querySelector('a[href^="/u/"]'))return {url:location.href,html:''};const h=p.outerHTML+(document.querySelector('#pre_story_links')?.outerHTML||'');return {url:location.href,html:h.length<=524288?h:''}})()"""
    }
}
