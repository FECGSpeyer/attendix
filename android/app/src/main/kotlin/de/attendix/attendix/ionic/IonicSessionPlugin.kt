package de.attendix.attendix.ionic

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.json.JSONTokener
import java.io.ByteArrayInputStream

// IONIC_SESSION: one-time takeover of the Ionic login after the store update
// to the Flutter app (same applicationId io.stephanus.attendix, same app data).
// The Ionic app (Capacitor) kept the Supabase session in the WebView
// localStorage of https://localhost. A hidden WebView opens that origin – the
// request is answered locally like Capacitor's WebViewLocalServer does – and
// reads the keys `sb-<ref>-auth-token` and `currentTenantId`.
// Channel de.attendix/ionic_session, method "read" -> JSON string or null.
// IONIC_QUEUE: plus the Ionic offline queue `offline_writes_v1` (IndexedDB of
// @ionic/storage) as a JSON string when present; reading it never fails the read.
// Dart side: lib/core/services/native/ionic_session_takeover.dart.
class IonicSessionPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "de.attendix/ionic_session")
    private val handler = Handler(Looper.getMainLooper())
    private var webView: WebView? = null
    private var pending: MethodChannel.Result? = null

    // IONIC_QUEUE: the session keys, once read (then the queue is read).
    private var sessionJson: String? = null

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
                if (sessionJson != null) return
                view.evaluateJavascript(SCRIPT) { value ->
                    if (webView !== view) return@evaluateJavascript
                    // evaluateJavascript returns the JS string JSON-encoded.
                    val decoded = try {
                        JSONTokener(value).nextValue() as? String
                    } catch (e: Exception) {
                        null
                    }
                    if (decoded == null) {
                        fail("script")
                        return@evaluateJavascript
                    }
                    // IONIC_QUEUE: then the (asynchronous) IndexedDB queue;
                    // it answers through the bridge. Any error returns the
                    // session keys alone, exactly as before.
                    sessionJson = decoded
                    try {
                        view.evaluateJavascript(QUEUE_SCRIPT, null)
                    } catch (e: Exception) {
                        finish(decoded)
                    }
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
        // IONIC_QUEUE: answer of QUEUE_SCRIPT (JavaBridge thread).
        view.addJavascriptInterface(QueueBridge(view), BRIDGE)
        // After the session keys were read, the timeout returns them without
        // the queue: a slow queue read never costs the takeover.
        handler.postDelayed({ sessionJson?.let { finish(it) } ?: fail("timeout") }, 5000)
        view.loadUrl("https://localhost/")
    }

    private inner class QueueBridge(private val view: WebView) {
        @JavascriptInterface
        fun done(queue: String?) {
            handler.post {
                if (webView !== view) return@post
                val session = sessionJson ?: return@post
                finish(merge(session, queue))
            }
        }
    }

    // Read errors are not "no Ionic session": Dart retries them on the next
    // start. Once the session keys were read, they are returned instead.
    private fun fail(reason: String) {
        val session = sessionJson
        if (session != null) finish(session) else finish(null, reason)
    }

    private fun finish(value: String?, error: String? = null) {
        val result = pending ?: return
        pending = null
        sessionJson = null
        handler.removeCallbacksAndMessages(null)
        webView?.let {
            it.stopLoading()
            it.destroy()
        }
        webView = null
        if (error != null) result.error("unavailable", error, null) else result.success(value)
    }

    private companion object {
        const val BRIDGE = "AttendixIonicQueue"
        const val QUEUE_KEY = "offline_writes_v1"

        // IONIC_QUEUE: the session keys plus `offline_writes_v1` (when present).
        fun merge(sessionJson: String, queue: String?): String {
            if (queue.isNullOrEmpty()) return sessionJson
            return try {
                JSONObject(sessionJson).put(QUEUE_KEY, queue).toString()
            } catch (e: Exception) {
                sessionJson
            }
        }

        // IONIC_QUEUE: the Ionic offline queue (@ionic/storage = localforage:
        // IndexedDB `_ionicstorage`/`_ionickv`, else localStorage
        // `_ionicstorage/_ionickv/<key>`) key `offline_writes_v1` as JSON
        // string, or null, sent to the bridge. Never creates the database
        // (the upgrade is aborted).
        const val QUEUE_SCRIPT = """
            (function () {
              var key = 'offline_writes_v1';
              function send(v) {
                try { AttendixIonicQueue.done(v); } catch (e) {}
              }
              function fromLocalStorage() {
                try {
                  var v = localStorage.getItem('_ionicstorage/_ionickv/' + key);
                  return typeof v === 'string' && v.length ? v : null;
                } catch (e) { return null; }
              }
              function fromIndexedDb() {
                return new Promise(function (resolve) {
                  try {
                    var req = indexedDB.open('_ionicstorage');
                    req.onupgradeneeded = function (e) { e.target.transaction.abort(); };
                    req.onerror = function () { resolve(null); };
                    req.onblocked = function () { resolve(null); };
                    req.onsuccess = function () {
                      var db = req.result;
                      try {
                        if (!db.objectStoreNames.contains('_ionickv')) { db.close(); resolve(null); return; }
                        var get = db.transaction('_ionickv', 'readonly').objectStore('_ionickv').get(key);
                        get.onsuccess = function () {
                          var v = get.result;
                          db.close();
                          if (v === undefined || v === null) resolve(null);
                          else resolve(typeof v === 'string' ? v : JSON.stringify(v));
                        };
                        get.onerror = function () { db.close(); resolve(null); };
                      } catch (e) { db.close(); resolve(null); }
                    };
                  } catch (e) { resolve(null); }
                });
              }
              fromIndexedDb().then(function (v) {
                send(v !== null ? v : fromLocalStorage());
              }, function () {
                send(fromLocalStorage());
              });
            })();
        """

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
