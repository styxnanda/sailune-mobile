package org.sailune.sailune_mobile

import android.webkit.WebView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class SilentStoryBrowserTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val url = "https://www.fanfiction.net/s/123/1"
    private val fixture = """<html><body><script>setTimeout(()=>{document.body.innerHTML='<div id="profile_top"><b class="xcontrast_txt">Fixture</b><a href="/u/1/Author">Author</a></div><div id="storytext">DO NOT EXTRACT</div>'},100)</script></body></html>"""

    @Test fun liveFFNSample() {
        org.junit.Assume.assumeTrue(InstrumentationRegistry.getArguments().getString("liveFFN") == "true")
        var successes = 0
        for (id in listOf("14223631", "14581050", "14583474", "14518651", "14469181", "14589120", "14581945", "14578582")) {
            val done = CountDownLatch(1)
            var success = false
            var reason = ""
            lateinit var browser: SilentStoryBrowser
            val start = android.os.SystemClock.elapsedRealtime()
            instrumentation.runOnMainSync {
                browser = SilentStoryBrowser(instrumentation.targetContext, { _, finalUrl, html, error ->
                    success = error.isEmpty() && html.contains("profile_top") && finalUrl.contains("/s/$id/")
                    reason = error
                    done.countDown()
                })
                browser.begin(id, "https://www.fanfiction.net/s/$id/1", 15000)
            }
            assertTrue("Browser leaked past deadline", done.await(18, TimeUnit.SECONDS))
            instrumentation.runOnMainSync { browser.close() }
            if (success) successes++
            android.util.Log.i("SailuneBrowserTest", "work=$id success=$success ms=${android.os.SystemClock.elapsedRealtime()-start} error=$reason")
            Thread.sleep(1000)
        }
        android.util.Log.i("SailuneBrowserTest", "FFN success=$successes/8")
    }

    @Test fun extractsJavaScriptHeaderWithoutWindowAndDestroysView() {
        val done = CountDownLatch(1)
        var destroyed = false
        var result = ""
        var error = ""
        lateinit var browser: SilentStoryBrowser
        instrumentation.runOnMainSync {
            browser = SilentStoryBrowser(instrumentation.targetContext, { _, finalUrl, html, failure ->
                assertEquals(url, finalUrl); result = html; error = failure; done.countDown()
            }, {
                object : WebView(instrumentation.targetContext) {
                    override fun loadUrl(u: String) { assertNull(windowToken); loadDataWithBaseURL(u, fixture, "text/html", "UTF-8", null) }
                    override fun destroy() { destroyed = true; super.destroy() }
                }
            })
            browser.begin("fixture", url, 5000)
        }
        assertTrue("WebView did not return metadata", done.await(8, TimeUnit.SECONDS))
        assertEquals("", error)
        assertTrue(result.contains("Fixture"))
        assertFalse(result.contains("DO NOT EXTRACT"))
        assertTrue(destroyed)
        instrumentation.runOnMainSync { browser.close() }
    }

    @Test fun blockedPageTimesOutWithoutPrompt() {
        val done = CountDownLatch(1)
        var failure = ""
        lateinit var browser: SilentStoryBrowser
        instrumentation.runOnMainSync {
            browser = SilentStoryBrowser(instrumentation.targetContext, { _, _, html, error ->
                assertEquals("", html); failure = error; done.countDown()
            }, { object : WebView(instrumentation.targetContext) {
                override fun loadUrl(u: String) { loadDataWithBaseURL(u, "<title>Just a moment...</title><script>alert('blocked')</script>", "text/html", "UTF-8", null) }
            } })
            browser.begin("blocked", url, 800)
        }
        assertTrue(done.await(4, TimeUnit.SECONDS)); assertTrue(failure.contains("deadline"))
        instrumentation.runOnMainSync { browser.close() }
    }

    @Test fun cancellationDestroysViewWithoutDeliveringLateResult() {
        var destroyed = false
        var callbacks = 0
        lateinit var browser: SilentStoryBrowser
        instrumentation.runOnMainSync {
            browser = SilentStoryBrowser(instrumentation.targetContext, { _, _, _, _ -> callbacks++ }, {
                object : WebView(instrumentation.targetContext) {
                    override fun loadUrl(u: String) { loadDataWithBaseURL(u, "<title>Waiting</title>", "text/html", "UTF-8", null) }
                    override fun destroy() { destroyed = true; super.destroy() }
                }
            })
            browser.begin("cancel", url, 3000)
            browser.cancel("cancel")
        }
        instrumentation.waitForIdleSync()
        instrumentation.runOnMainSync { assertTrue(destroyed); assertEquals(0, callbacks); browser.close() }
    }
}
