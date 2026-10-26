package com.decodewest.plaid_omni_connect

import android.app.Activity
import android.app.Dialog
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.view.Window
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

internal fun isTerminalLinkMessage(json: String): Boolean {
  return json.contains("\"type\":\"success\"") ||
      json.contains("\"type\":\"exit\"") ||
      json.contains("\"type\":\"error\"")
}

class PlaidOmniConnectPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel : MethodChannel
  private var activity: Activity? = null
  private var dialog: Dialog? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "plaid_omni_connect")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "open") {
      val pageHtml = call.argument<String>("pageHtml")
      if (pageHtml.isNullOrEmpty() || activity == null) {
        result.error("INVALID_STATE", "Activity or pageHtml missing", null)
        return
      }
      showPlaidDialog(pageHtml)
      result.success(null)
    } else if (call.method == "close") {
      dialog?.dismiss()
      result.success(null)
    } else {
      result.notImplemented()
    }
  }

  private fun showPlaidDialog(pageHtml: String) {
    val act = activity ?: return

    dialog = object : Dialog(act, android.R.style.Theme_Translucent_NoTitleBar) {
      override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))

        val webView = WebView(context)
        webView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.webViewClient = WebViewClient()
        webView.addJavascriptInterface(PlaidWebInterface(channel, this), "Android")

        webView.loadDataWithBaseURL(
            "https://cdn.plaid.com",
            pageHtml,
            "text/html",
            "UTF-8",
            null
        )

        setContentView(webView)
      }
    }
    dialog?.show()
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }
}

class PlaidWebInterface(private val channel: MethodChannel, private val dialog: Dialog) {
  private val handler = Handler(Looper.getMainLooper())

  @JavascriptInterface
  fun postMessage(json: String) {
    handler.post {
      channel.invokeMethod("onLinkMessage", json)
      if (isTerminalLinkMessage(json)) {
        dialog.dismiss()
      }
    }
  }
}
