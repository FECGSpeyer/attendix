package de.attendix.attendix.ionic

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONTokener
import java.io.ByteArrayInputStream

// IONIC_SESSION: one-time takeover of the Ionic login after the store update
// to the Flutter app (same applicationId io.stephanus.attendix, same app data).
// The Ionic app (Capacitor) kept the Supabase session in the WebView
// localStorage of https://localhost. A hidden WebView opens that origin – the
// request is answered locally like Capacitor's WebViewLocalServer does – and
// reads the keys `sb-<ref>-auth-token` and `currentTenantId`.
// Channel de.attendix/ionic_session, method "read" -> JSON string or null.
// Dart side: lib/core/services/native/ionic_session_takeover.dart.
class IonicSessionPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "de.attendix/ionic_session")
    private val handler = Handler(Looper.getMainLooper())
    private var webView: WebView? = null
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        fail("disposed")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "read") {
            result.notImplemented()
            return
        }
        // A second read while one is running: an error, not "empty" (Dart
        // would end the takeover for good on null).
        if (pending != null) {
            result.error("busy", "read already running", null)
            return
        }
        pending = result
        try {
            read()
        } catch (e: Exception) {
            fail(e.toString())
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun read() {
        val view = WebView(context)
        webView = view
        view.settings.javaScriptEnabled = true
        view.settings.domStorageEnabled = true
        view.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest,
            ): WebResourceResponse? {
                if (request.url.host != "localhost") return null
                return WebResourceResponse(
                    "text/html",
                    "utf-8",
                    ByteArrayInputStream("<!doctype html><html><body></body></html>".toByteArray()),
                )
            }

            override fun onPageFinished(view: WebView, url: String?) {
                if (webView !== view) return
                view.evaluateJavascript(SCRIPT) { value ->
                    // evaluateJavascript returns the JS string JSON-encoded.
                    val decoded = try {
                        JSONTokener(value).nextValue() as? String
                    } catch (e: Exception) {
                        null
                    }
                    if (decoded != null) finish(decoded) else fail("script")
                }
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError,
            ) {
                if (request.isForMainFrame) fail("load")
            }
        }
        handler.postDelayed({ fail("timeout") }, 5000)
        view.loadUrl("https://localhost/")
    }

    // Read errors are not "no Ionic session": Dart retries them on the next start.
    private fun fail(reason: String) = finish(null, reason)

    private fun finish(value: String?, error: String? = null) {
        val result = pending ?: return
        pending = null
        handler.removeCallbacksAndMessages(null)
        webView?.let {
            it.stopLoading()
            it.destroy()
        }
        webView = null
        if (error != null) result.error("unavailable", error, null) else result.success(value)
    }

    private companion object {
        const val SCRIPT = """
            (function () {
              var out = {};
              for (var i = 0; i < localStorage.length; i++) {
                var k = localStorage.key(i);
                if ((k.indexOf('sb-') === 0 && k.slice(-11) === '-auth-token') || k === 'currentTenantId') {
                  out[k] = localStorage.getItem(k);
                }
              }
              return JSON.stringify(out);
            })();
        """
    }
}
// IONIC_SESSION end
