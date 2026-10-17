package com.nubify.app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val cellularCallChannel = "com.nubify.app/cellular_call"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            cellularCallChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != "placeCall") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val phone = call.argument<String>("phone")?.trim().orEmpty()
            val direct = call.argument<Boolean>("direct") == true

            if (!phone.matches(Regex("^\\+201[0125]\\d{8}$"))) {
                result.error("invalid_phone", "Invalid Egyptian mobile number.", null)
                return@setMethodCallHandler
            }

            try {
                val action = if (direct) Intent.ACTION_CALL else Intent.ACTION_DIAL
                val intent = Intent(action, Uri.parse("tel:$phone"))
                startActivity(intent)
                result.success(null)
            } catch (error: SecurityException) {
                try {
                    startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone")))
                    result.success(null)
                } catch (fallbackError: Exception) {
                    result.error("call_unavailable", fallbackError.message, null)
                }
            } catch (error: Exception) {
                result.error("call_unavailable", error.message, null)
            }
        }
    }
}
