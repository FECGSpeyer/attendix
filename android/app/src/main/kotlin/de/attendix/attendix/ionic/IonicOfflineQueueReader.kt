package de.attendix.attendix.ionic

import android.annotation.SuppressLint
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream

// IONIC_QUEUE: the Ionic app's unsent offline writes (OfflineQueueService,
// @ionic/storage-angular via localforage: IndexedDB `_ionicstorage`, object
// store `_ionickv`, key `offline_writes_v1`). Read once in a hidden WebView of
// its own on https://localhost (answered locally like the session read), after
// and independent of IonicSessionPlugin's session read: own WebView, own
// handler, own timeout. IndexedDB is asynchronous, so the script reports back
// through a JavaScript interface. Method "readOfflineQueue" on
// de.attendix/ionic_session -> JSON string `{"value": <stored value or null>}`;
// a missing database or key is `null`, not an error. The Ionic data is only
// read, never changed. Dart side:
// lib/core/services/native/ionic_offline_queue_takeover.dart.
class IonicOfflineQueueReader(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private var webView: WebView? = null
    private var pending: MethodChannel.Result? = null

    fun read(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "read already running", null)
            return
        }
        pending = result
        try {
            start()
        } catch (e: Exception) {
            fail(e.toString())
        }
    }

    fun dispose() = fail("disposed")

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    private fun start() {
        val view = WebView(context)
        webView = view
        view.settings.javaScriptEnabled = true
        view.settings.domStorageEnabled = true
        view.settings.allowFileAccess = false
        view.settings.allowContentAccess = false
        view.addJavascriptInterface(Bridge(view), BRIDGE)
        view.webViewClient = object : WebViewClient() {
            // Only https://localhost is answered (locally, empty page); every
            // other request gets an empty 403 and never reaches the network.
            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest,
            ): WebResourceResponse {
                if (!isLocalOrigin(request.url)) {
                    return WebResourceResponse(
                        "text/plain",
                        "utf-8",
                        403,
                        "Forbidden",
                        emptyMap(),
                        ByteArrayInputStream(ByteArray(0)),
                    )
                }
                return WebResourceResponse(
                    "text/html",
                    "utf-8",
                    ByteArrayInputStream("<!doctype html><html><body></body></html>".toByteArray()),
                )
            }

            // No navigation away from https://localhost/ (the bridge must
            // never be reachable from another page).
            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest,
            ): Boolean = request.url.toString() != URL

            @Deprecated("Deprecated in Java")
            override fun shouldOverrideUrlLoading(view: WebView, url: String?): Boolean =
                url != URL

            override fun onPageFinished(view: WebView, url: String?) {
                if (webView !== view) return
                view.evaluateJavascript(SCRIPT, null)
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
        view.loadUrl(URL)
    }

    // Called by the script on a WebView background thread.
    private inner class Bridge(private val view: WebView) {
        @JavascriptInterface
        fun deliver(value: String?, error: String?) {
            handler.post {
                if (webView !== view) return@post
                // Only the script on https://localhost/ may answer.
                if (view.url?.startsWith(URL) != true) return@post
                if (value != null) finish(value) else fail(error ?: "script")
            }
        }
    }

    // Read errors are retried by Dart on the next start.
    private fun fail(reason: String) = finish(null, reason)

    private fun finish(value: String?, error: String? = null) {
        val result = pending ?: return
        pending = null
        handler.removeCallbacksAndMessages(null)
        webView?.let {
            it.stopLoading()
            it.removeJavascriptInterface(BRIDGE)
            it.destroy()
        }
        webView = null
        if (error != null) result.error("unavailable", error, null) else result.success(value)
    }

    private companion object {
        const val BRIDGE = "AttendixIonicQueue"
        const val URL = "https://localhost/"

        // https://localhost with the default port only.
        fun isLocalOrigin(url: Uri): Boolean =
            url.scheme == "https" && url.host == "localhost" &&
                (url.port == -1 || url.port == 443)

        // Same function as ios/Runner/AppDelegate.swift
        // (ionicOfflineQueueReadFunction): opening a database that does not
        // exist would create it, so the upgrade is aborted instead (nothing is
        // created, the result is null). Falls back to localforage's
        // localStorage driver key.
        const val SCRIPT = """
            (function () {
              var KEY = 'offline_writes_v1';
              function local() {
                try { return localStorage.getItem('_ionicstorage/_ionickv/' + KEY); } catch (e) { return null; }
              }
              function idb() {
                return new Promise(function (resolve, reject) {
                  if (!window.indexedDB) { resolve(null); return; }
                  var created = false;
                  var req = indexedDB.open('_ionicstorage');
                  req.onupgradeneeded = function () { created = true; req.transaction.abort(); };
                  req.onerror = function (event) {
                    if (event && event.preventDefault) event.preventDefault();
                    if (created) resolve(null); else reject(new Error('open: ' + req.error));
                  };
                  req.onsuccess = function () {
                    var db = req.result;
                    try {
                      if (!db.objectStoreNames.contains('_ionickv')) { db.close(); resolve(null); return; }
                      var get = db.transaction('_ionickv', 'readonly').objectStore('_ionickv').get(KEY);
                      get.onsuccess = function () { db.close(); resolve(get.result === undefined ? null : get.result); };
                      get.onerror = function () { db.close(); reject(new Error('get: ' + get.error)); };
                    } catch (e) { db.close(); reject(e); }
                  };
                });
              }
              idb().then(function (value) {
                if (value === null || value === undefined) value = local();
                return JSON.stringify({ value: value === undefined ? null : value });
              }).then(function (json) {
                window.AttendixIonicQueue.deliver(json, null);
              }, function (e) {
                window.AttendixIonicQueue.deliver(null, String((e && e.message) || e));
              });
            })();
        """
    }
}
// IONIC_QUEUE end
