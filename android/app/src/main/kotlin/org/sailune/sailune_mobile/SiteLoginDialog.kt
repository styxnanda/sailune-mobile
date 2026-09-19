package org.sailune.sailune_mobile

import android.app.Activity
import android.app.Dialog
import android.graphics.Color
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.*
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** Visible official-site login; no script injection, native JS bridge, or password capture. */
internal class SiteLoginDialog(
    activity: Activity,
    private val site: String,
    private val complete: () -> Unit,
    makeWebView: () -> WebView = { WebView(activity) },
) : Dialog(activity) {
    private val web = makeWebView()
    private val address = TextView(activity)
    private var disposed = false
    init {
        val dark = activity.resources.configuration.uiMode and 0x30 == 0x20
        val ink = if (dark) Color.WHITE else Color.BLACK
        val canvas = if (dark) Color.rgb(24,24,24) else Color.rgb(245,245,245)
        val layout = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL; setBackgroundColor(canvas) }
        address.apply { setTextColor(ink); textSize = 15f; setPadding(24,24,24,16); text = WebsiteSessions.loginURL(site) }
        layout.addView(address)
        val note = TextView(activity).apply {
            text = "Sign in on the website below. Sailune keeps this session on your device. Tap Done when finished."
            setTextColor(ink); setPadding(24,0,24,16)
        }
        layout.addView(note)
        layout.addView(web, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,0,1f))
        val done = Button(activity).apply { id = android.R.id.button1; text = "Done"; setOnClickListener { dismiss() } }
        layout.addView(done)
        setContentView(layout)
        setOnDismissListener { dispose(); complete() }
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
            override fun onPermissionRequest(request: PermissionRequest) { request.deny() }
            override fun onGeolocationPermissionsShowPrompt(origin: String, callback: GeolocationPermissions.Callback) { callback.invoke(origin,false,false) }
        }
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(v: WebView, request: WebResourceRequest): Boolean {
                if (request.isForMainFrame && WebsiteSessions.site(request.url.toString()) != site) {
                    address.text = "Only this website can open here. External sign-in providers are not supported."
                    return true
                }
                return false
            }
            override fun onPageStarted(v: WebView, url: String, icon: android.graphics.Bitmap?) {
                if (WebsiteSessions.site(url) != site) { v.stopLoading(); return }
                // Show only origin/path, never query strings containing tokens.
                val u = android.net.Uri.parse(url)
                address.text = "https://${u.host}${u.path ?: ""}"
            }
            override fun onReceivedSslError(v: WebView, h: SslErrorHandler, e: android.net.http.SslError) {
                h.cancel(); address.text = "Could not establish a secure connection. Close and try again."
            }
            override fun onReceivedHttpAuthRequest(v: WebView, h: HttpAuthHandler, host: String, realm: String) { h.cancel() }
            override fun onRenderProcessGone(v: WebView, detail: RenderProcessGoneDetail): Boolean { dismiss(); return true }
        }
    }
    fun open() {
        show()
        window?.apply {
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
        web.stopLoading(); (web.parent as? ViewGroup)?.removeView(web); web.destroy()
        CookieManager.getInstance().flush()
    }
}
