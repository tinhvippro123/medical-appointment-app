package com.medicalapp.medical_appointment_app

import android.content.Intent
import com.zing.zalo.zalosdk.oauth.LoginVia
import com.zing.zalo.zalosdk.oauth.OAuthCompleteListener
import com.zing.zalo.zalosdk.oauth.OauthResponse
import com.zing.zalo.zalosdk.oauth.ZaloSDK
import com.zing.zalo.zalosdk.oauth.model.ErrorResponse
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingZaloResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.medicalapp/zalo_auth"
        ).setMethodCallHandler { call, result ->
            if (call.method == "login") {
                val codeChallenge = call.argument<String>("codeChallenge") ?: ""
                pendingZaloResult = result

                ZaloSDK.Instance.authenticateZaloWithAuthenType(
                    this,
                    LoginVia.APP_OR_WEB,
                    codeChallenge,
                    object : OAuthCompleteListener() {
                        override fun onGetOAuthComplete(response: OauthResponse) {
                            val callback = pendingZaloResult
                            pendingZaloResult = null
                            callback?.success(
                                mapOf("oauthCode" to (response.oauthCode ?: ""))
                            )
                        }

                        override fun onAuthenError(errorResponse: ErrorResponse) {
                            val callback = pendingZaloResult
                            pendingZaloResult = null
                            callback?.error(
                                "ZALO_AUTH_ERROR",
                                errorResponse.errorMsg ?: "Đăng nhập Zalo bị hủy hoặc không thành công.",
                                errorResponse.errorCode
                            )
                        }
                    }
                )
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        ZaloSDK.Instance.onActivityResult(this, requestCode, resultCode, data)
    }
}
