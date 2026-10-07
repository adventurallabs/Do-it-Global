package com.nuvara.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * UPI intent payments. Dart calls `pay` with a `upi://pay?...` link; we always show Android's app chooser
 * ("Pay with") so the parent picks their UPI app, and hand back what that app replied. The reply is only a
 * hint: the server checks it against the payment it created before anything counts as paid.
 */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "apps" -> result.success(upiApps())
                "pay" -> pay(call.argument<String>("uri"), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun upiIntent(uri: String) = Intent(Intent.ACTION_VIEW, Uri.parse(uri))

    /** How many installed apps can take a UPI payment. */
    private fun upiApps(): Int = packageManager.queryIntentActivities(upiIntent("upi://pay"), 0).size

    private fun pay(uri: String?, result: MethodChannel.Result) {
        if (uri == null || !uri.startsWith("upi://pay")) {
            result.error("bad_uri", "Not a UPI payment link.", null)
            return
        }
        if (pending != null) {
            result.error("busy", "A payment is already open.", null)
            return
        }
        if (upiApps() == 0) {
            result.success(mapOf("launched" to false))
            return
        }
        pending = result
        try {
            startActivityForResult(Intent.createChooser(upiIntent(uri), "Pay with"), REQUEST)
        } catch (e: Exception) {
            pending = null
            result.success(mapOf("launched" to false))
        }
    }

    @Deprecated("Activity result API is not used by the Flutter embedding here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST) return
        val result = pending ?: return
        pending = null
        result.success(mapOf("launched" to true, "ok" to (resultCode == Activity.RESULT_OK), "response" to responseOf(data)))
    }

    /** Apps reply with a `response` string ("txnId=..&Status=SUCCESS&..."); some send the fields as extras instead. */
    private fun responseOf(data: Intent?): String? {
        if (data == null) return null
        data.getStringExtra("response")?.let { return it }
        val extras = data.extras ?: return null
        val keys = listOf("txnId", "responseCode", "Status", "txnRef", "ApprovalRefNo")
        val parts = keys.mapNotNull { k -> extras.getString(k)?.let { "$k=$it" } }
        return if (parts.isEmpty()) null else parts.joinToString("&")
    }

    companion object {
        private const val CHANNEL = "nuvara/upi"
        private const val REQUEST = 4721
    }
}
