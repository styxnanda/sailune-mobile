package org.sailune.sailune_mobile

import android.app.Activity
import android.app.Dialog
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.webkit.*
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView

/** App-owned browser frame. Inspects only signed-in navigation, never form values. */
internal class SiteLoginDialog(
    activity: Activity,
    private val site: String,
    private val complete: (Boolean) -> Unit,
    makeWebView: () -> WebView = { WebView(activity) },
    appearance: String = "system",
) : Dialog(activity) {
    private val web = makeWebView()
    private val address = TextView(activity)
    private val handler = Handler(Looper.getMainLooper())
    private var disposed = false
    private var verified = false
    private var generation = 0
    private var checks = 0
    private fun dp(value: Int) = (value * context.resources.displayMetrics.density).toInt()
    init {
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        val dark = when (appearance) {
            "dark" -> true
            "light" -> false
            else -> activity.resources.configuration.uiMode and 0x30 == 0x20
        }
        val ink = Color.parseColor(if (dark) "#EDEDED" else "#202020")
        val canvas = Color.parseColor(if (dark) "#181818" else "#F5F5F5")
        val muted = Color.parseColor(if (dark) "#AAAAAA" else "#666666")
        val layout = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(canvas)
                cornerRadii = floatArrayOf(dp(28).toFloat(),dp(28).toFloat(),dp(28).toFloat(),dp(28).toFloat(),0f,0f,0f,0f)
            }
            clipToOutline = true
        }
        val bar = LinearLayout(activity).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(20),dp(12),dp(12),dp(8))
        }
        address.apply {
            setTextColor(ink); textSize = 14f; typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            text = android.net.Uri.parse(WebsiteSessions.loginURL(site)).host
            contentDescription = "Secure website: $text"
        }
        bar.addView(address, LinearLayout.LayoutParams(0,dp(48),1f))
        address.gravity = Gravity.CENTER_VERTICAL
        val close = TextView(activity).apply {
            id = android.R.id.button1; text = "Close"; textSize = 14f
            setTextColor(ink); gravity = Gravity.CENTER
            isFocusable = true; contentDescription = "Close sign-in"
            setOnClickListener { dismiss() }
            background = GradientDrawable().apply {
                setColor(Color.parseColor(if (dark) "#303030" else "#E8E8E8"))
                cornerRadius = dp(24).toFloat()
            }
        }
        bar.addView(close, LinearLayout.LayoutParams(dp(72),dp(48)))
        layout.addView(bar)
        val note = TextView(activity).apply {
            text = "Closes automatically when you’re signed in."
            setTextColor(muted); textSize = 12f; setPadding(dp(20),0,dp(20),dp(16))
        }
        layout.addView(note)
        val progress = ProgressBar(activity,null,android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progressTintList = android.content.res.ColorStateList.valueOf(ink)
        }
        layout.addView(progress,LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,dp(2)))
        layout.addView(web, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,0,1f))
        setContentView(layout)
        setOnDismissListener { dispose(); complete(verified) }
        web.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = false
            allowContentAccess = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(true)
        }
        CookieManager.getInstance().setAcceptThirdPartyCookies(web,false)
        web.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView, value: Int) {
                progress.progress = value
                progress.visibility = if (value == 100) View.INVISIBLE else View.VISIBLE
            }
            override fun onPermissionRequest(request: PermissionRequest) { request.deny() }
            override fun onGeolocationPermissionsShowPrompt(origin: String, callback: GeolocationPermissions.Callback) { callback.invoke(origin,false,false) }
        }
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(v: WebView, request: WebResourceRequest): Boolean {
                if (request.isForMainFrame && WebsiteSessions.site(request.url.toString()) != site) {
                    note.text = "External sign-in providers cannot share a session here. Use this site’s own sign-in."
                    return true
                }
                return false
            }
            override fun onPageStarted(v: WebView, url: String, icon: android.graphics.Bitmap?) {
                generation++; handler.removeCallbacksAndMessages(null)
                if (WebsiteSessions.site(url) != site) { v.stopLoading(); return }
                address.text = android.net.Uri.parse(url).host
            }
            override fun onPageFinished(v: WebView, url: String) {
                if (WebsiteSessions.site(url) != site || disposed) return
                checks = 0
                checkSignIn(generation)
            }
            override fun onReceivedSslError(v: WebView, h: SslErrorHandler, e: android.net.http.SslError) {
                h.cancel(); generation++; handler.removeCallbacksAndMessages(null)
                note.text = "Could not establish a secure connection. Close and try again."
            }
            override fun onReceivedHttpAuthRequest(v: WebView, h: HttpAuthHandler, host: String, realm: String) { h.cancel() }
            override fun onRenderProcessGone(v: WebView, detail: RenderProcessGoneDetail): Boolean { dismiss(); return true }
        }
    }

    private fun checkSignIn(page: Int) {
        if (disposed || page != generation || checks++ >= 120) return
        val url = web.url ?: return
        if (WebsiteSessions.site(url) != site) return
        web.evaluateJavascript(LoginEvidence.script(site)) { value ->
            if (disposed || page != generation || web.url != url) return@evaluateJavascript
            if (value == "true" && !CookieManager.getInstance().getCookie(url).isNullOrBlank()) {
                verified = true
                CookieManager.getInstance().flush()
                dismiss()
            } else handler.postDelayed({ checkSignIn(page) }, 1000)
        }
    }

    fun open() {
        show()
        window?.apply {
            setBackgroundDrawableResource(android.R.color.transparent)
            setLayout(ViewGroup.LayoutParams.MATCH_PARENT,(context.resources.displayMetrics.heightPixels*.94).toInt())
            setGravity(Gravity.BOTTOM)
            addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        }
        web.loadUrl(WebsiteSessions.loginURL(site))
    }
    private fun dispose() {
        if (disposed) return
        disposed = true
        handler.removeCallbacksAndMessages(null)
        web.stopLoading(); (web.parent as? ViewGroup)?.removeView(web); web.destroy()
        CookieManager.getInstance().flush()
    }
}

/** Conservative positive evidence; a cookie or redirect alone is never a login. */
internal object LoginEvidence {
    fun script(site: String): String = if (site == "ao3") """
        (() => {
          if (location.protocol !== 'https:' || !['archiveofourown.org','www.archiveofourown.org'].includes(location.hostname)) return false;
          const nav = document.querySelector('header#header')?.querySelector('nav#greeting');
          if (!nav) return false;
          const links = Array.from(nav.querySelectorAll('a[href]')).map(a => new URL(a.href,location.href));
          return links.some(u => u.origin === location.origin && u.pathname === '/users/logout') &&
            links.some(u => u.origin === location.origin && /^\/users\/[^/]+$/.test(u.pathname) && !['/users/login','/users/logout','/users/new'].includes(u.pathname));
        })()
    """.trimIndent() else """
        (() => {
          if (location.protocol !== 'https:' || !['fanfiction.net','www.fanfiction.net','m.fanfiction.net'].includes(location.hostname)) return false;
          if (!/^\/(login.php|account(?:\/|$))/.test(location.pathname)) return false;
          if (document.querySelector('input[type="password"]')) return false;
          const links = Array.from(document.querySelectorAll('a[href]')).map(a => new URL(a.href,location.href));
          return links.some(u => u.origin === location.origin && ['/logout.php','/logout/'].includes(u.pathname)) &&
            links.some(u => u.origin === location.origin && u.pathname.startsWith('/account/'));
        })()
    """.trimIndent()
}
