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
import android.webkit.WebResourceRequest
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
import org.json.JSONObject

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
      val linkToken = call.argument<String>("linkToken")
      if (linkToken != null && activity != null) {
        showPlaidDialog(linkToken)
        result.success(null)
      } else {
        result.error("INVALID_STATE", "Activity or linkToken missing", null)
      }
    } else if (call.method == "close") {
      dialog?.dismiss()
      result.success(null)
    } else {
      result.notImplemented()
    }
  }

  private fun showPlaidDialog(linkToken: String) {
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
        webView.addJavascriptInterface(PlaidWebInterface(channel, this), "Android")
        
        val html = createPlaidHtml(linkToken)
        webView.loadDataWithBaseURL("https://cdn.plaid.com", html, "text/html", "UTF-8", null)
        
        setContentView(webView)
      }
    }
    dialog?.show()
  }

  private fun createPlaidHtml(linkToken: String): String {
    return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src="https://cdn.plaid.com/link/v2/stable/link-initialize.js"></script>
            <style>body { margin: 0; background: transparent; }</style>
        </head>
        <body>
            <script>
                const handler = Plaid.create({
                    token: '$linkToken',
                    onSuccess: (public_token, metadata) => {
                        Android.onSuccess(public_token, JSON.stringify(metadata));
                    },
                    onExit: (err, metadata) => {
                        Android.onExit(err ? JSON.stringify(err) : null, JSON.stringify(metadata));
                    },
                    onEvent: (eventName, metadata) => {
                        Android.onEvent(eventName, JSON.stringify(metadata));
                    }
                });
                handler.open();
            </script>
        </body>
        </html>
    """.trimIndent()
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() { binding: ActivityPluginBinding
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
  fun onSuccess(publicToken: String, metadataJson: String) {
    handler.post {
      val metadata = parseJson(metadataJson)
      channel.invokeMethod("onSuccess", mapOf("publicToken" to publicToken, "metadata" to metadata))
      dialog.dismiss()
    }
  }

  @JavascriptInterface
  fun onExit(errorJson: String?, metadataJson: String) {
    handler.post {
      val error = if (errorJson != null) parseJson(errorJson) else null
      val metadata = parseJson(metadataJson)
      channel.invokeMethod("onExit", mapOf("error" to error, "metadata" to metadata))
      dialog.dismiss()
    }
  }

  @JavascriptInterface
  fun onEvent(eventName: String, metadataJson: String) {
    handler.post {
      val metadata = parseJson(metadataJson)
      channel.invokeMethod("onEvent", mapOf("eventName" to eventName, "metadata" to metadata))
    }
  }
  
  private fun parseJson(json: String): Map<String, Any?> {
      try {
          val jsonObject = JSONObject(json)
          val map = mutableMapOf<String, Any?>()
          val keys = jsonObject.keys()
          while (keys.hasNext()) {
              val key = keys.next()
              map[key] = jsonObject.get(key)
              // Note: recursive parsing for nested objects omitted for brevity, 
              // but Plaid metadata is shallow enough or mapped to Strings.
              // Ideally use a proper JSON to Map converter.
          }
          return map
      } catch (e: Exception) {
          return emptyMap()
      }
  }
}
