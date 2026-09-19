package org.sailune.sailune_mobile

import android.webkit.CookieManager
import android.webkit.WebView
import android.view.View
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class WebsiteSessionsTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val url = "https://archiveofourown.org/works/123"
    private fun clear(s: WebsiteSessions) {
        val done=CountDownLatch(1)
        instrumentation.runOnMainSync { s.clear { assertTrue(it); done.countDown() } }
        assertTrue(done.await(5,TimeUnit.SECONDS))
    }
    @Test fun cookieStoreRequiresConsentHonorsScopeRotatesAndClears() {
        lateinit var sessions: WebsiteSessions
        instrumentation.runOnMainSync { sessions=WebsiteSessions(instrumentation.targetContext) }
        clear(sessions)
        val written=CountDownLatch(1)
        instrumentation.runOnMainSync { CookieManager.getInstance().setCookie(url,"sailune_test=FIRST; Path=/works; Secure; HttpOnly") { written.countDown() } }
        assertTrue(written.await(5,TimeUnit.SECONDS))
        assertEquals("",sessions.cookies(url))
        sessions.enable("ao3")
        assertTrue(sessions.cookies(url).contains("sailune_test=FIRST"))
        assertEquals("",sessions.cookies("https://archiveofourown.org/users/login"))
        assertEquals("",sessions.cookies("https://www.fanfiction.net/s/123/1"))
        assertEquals("",sessions.cookies("https://archiveofourown.org.evil.test/works/123"))
        assertEquals("",sessions.cookies("http://archiveofourown.org/works/123"))
        sessions.storeCookie(url,"sailune_test=SECOND; Path=/works; Secure; HttpOnly")
        assertTrue(sessions.cookies(url).contains("sailune_test=SECOND"))
        val reopened=WebsiteSessions(instrumentation.targetContext)
        assertTrue(reopened.enabled("ao3"))
        assertTrue(reopened.cookies(url).contains("sailune_test=SECOND"))
        clear(sessions)
        assertFalse(sessions.enabled("ao3"))
        assertTrue(CookieManager.getInstance().getCookie(url).isNullOrEmpty())
    }

    @Test fun visibleLoginKeepsConsentedCookieAndDestroysViewOnDone() {
        var destroyed=false
        val closed=CountDownLatch(1)
        lateinit var dialog: SiteLoginDialog
        lateinit var sessions: WebsiteSessions
        val scenario=ActivityScenario.launch(MainActivity::class.java)
        try {
            scenario.onActivity { sessions=WebsiteSessions(it) }
            clear(sessions)
            scenario.onActivity { activity ->
                sessions.enable("ao3")
                dialog=SiteLoginDialog(activity,"ao3",{closed.countDown()}, {
                    object:WebView(activity) {
                        override fun loadUrl(u:String) {
                            loadDataWithBaseURL(u,"<h1>Official-site fixture</h1><script>document.cookie='sailune_login=SYNTHETIC; Path=/; Secure';</script>","text/html","UTF-8",null)
                        }
                        override fun destroy() {destroyed=true;super.destroy()}
                    }
                })
                dialog.open()
                assertTrue(dialog.isShowing)
            }
            val end=System.nanoTime()+TimeUnit.SECONDS.toNanos(5)
            while(!sessions.cookies(url).contains("sailune_login=") && System.nanoTime()<end) Thread.sleep(50)
            assertTrue(sessions.cookies(url).contains("sailune_login=SYNTHETIC"))
            scenario.onActivity { dialog.findViewById<View>(android.R.id.button1).performClick() }
            assertTrue(closed.await(3,TimeUnit.SECONDS));assertTrue(destroyed)
            assertTrue(sessions.cookies(url).contains("sailune_login=SYNTHETIC"))
            clear(sessions)
        } finally { scenario.close() }
    }
    @Test fun confirmedAccountClosesAutomaticallyAndPersistsVerifiedStatus() {
        val closed = CountDownLatch(1)
        var confirmed = false
        var destroyed = false
        lateinit var sessions: WebsiteSessions
        val scenario = ActivityScenario.launch(MainActivity::class.java)
        try {
            scenario.onActivity { sessions = WebsiteSessions(it) }
            clear(sessions)
            scenario.onActivity { activity ->
                sessions.enable("ao3")
                assertEquals(false, sessions.status()["ao3"])
                SiteLoginDialog(activity, "ao3", { success ->
                    confirmed = success
                    if (success) sessions.confirm("ao3")
                    closed.countDown()
                }, {
                    object: WebView(activity) {
                        override fun loadUrl(u: String) {
                            loadDataWithBaseURL(u,
                                "<header id='header'><nav id='greeting'><a href='/users/fixture'>Profile</a><a href='/users/logout'>Log out</a></nav></header><script>document.cookie='sailune_login=SYNTHETIC; Path=/; Secure';</script>",
                                "text/html", "UTF-8", u)
                        }
                        override fun destroy() { destroyed = true; super.destroy() }
                    }
                }).open()
            }
            assertTrue(closed.await(8,TimeUnit.SECONDS))
            assertTrue(confirmed)
            assertTrue(destroyed)
            assertEquals(true, WebsiteSessions(instrumentation.targetContext).status()["ao3"])
            clear(sessions)
            assertEquals(false, sessions.status()["ao3"])
        } finally { scenario.close() }
    }

    @Test fun ffnAccountNavigationClosesAutomatically() {
        val closed = CountDownLatch(1)
        var confirmed = false
        var destroyed = false
        lateinit var sessions: WebsiteSessions
        val scenario = ActivityScenario.launch(MainActivity::class.java)
        try {
            scenario.onActivity { sessions = WebsiteSessions(it) }
            clear(sessions)
            scenario.onActivity { activity ->
                sessions.enable("ffn")
                assertEquals(false, sessions.status()["ffn"])
                SiteLoginDialog(activity, "ffn", { success ->
                    confirmed = success
                    if (success) sessions.confirm("ffn")
                    closed.countDown()
                }, {
                    object: WebView(activity) {
                        override fun loadUrl(u: String) {
                            loadDataWithBaseURL(u,
                                "<nav><a href='/account/profile.php'>Account</a><a href='/logout.php'>Log out</a></nav><script>document.cookie='sailune_login=SYNTHETIC; Path=/; Secure';</script>",
                                "text/html", "UTF-8", u)
                        }
                        override fun destroy() { destroyed = true; super.destroy() }
                    }
                }).open()
            }
            assertTrue(closed.await(8,TimeUnit.SECONDS))
            assertTrue(confirmed)
            assertTrue(destroyed)
            assertEquals(true, WebsiteSessions(instrumentation.targetContext).status()["ffn"])
            clear(sessions)
            assertEquals(false, sessions.status()["ffn"])
        } finally { scenario.close() }
    }

    @Test fun cookieAndStoryContentCannotMasqueradeAsSignedInNavigation() {
        val closed = CountDownLatch(1)
        var confirmed = true
        lateinit var dialog: SiteLoginDialog
        lateinit var sessions: WebsiteSessions
        val scenario = ActivityScenario.launch(MainActivity::class.java)
        try {
            scenario.onActivity { sessions = WebsiteSessions(it) }
            clear(sessions)
            scenario.onActivity { activity ->
                sessions.enable("ao3")
                dialog = SiteLoginDialog(activity, "ao3", { success ->
                    confirmed = success; closed.countDown()
                }, {
                    object: WebView(activity) {
                        override fun loadUrl(u: String) {
                            loadDataWithBaseURL(u,
                                "<input type='password'><article><nav id='greeting'><a href='/users/fixture'>Profile</a><a href='/users/logout'>Log out</a></nav></article><script>document.cookie='sailune_guest=GUEST; Path=/; Secure';</script>",
                                "text/html", "UTF-8", u)
                        }
                    }
                })
                dialog.open()
            }
            assertFalse(closed.await(2,TimeUnit.SECONDS))
            scenario.onActivity { assertTrue(dialog.isShowing); dialog.dismiss() }
            assertTrue(closed.await(3,TimeUnit.SECONDS))
            assertFalse(confirmed)
            assertEquals(false,sessions.status()["ao3"])
            clear(sessions)
        } finally { scenario.close() }
    }

}
