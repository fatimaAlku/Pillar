package com.example.pillar_study_coach

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var googleOauthChannel: MethodChannel? = null
  private var pendingGoogleRedirectUrl: String? = null

  private fun prefs() =
    applicationContext.getSharedPreferences("pillar_google_oauth", Context.MODE_PRIVATE)

  private fun prefsKey() = "pillar_pending_google_oauth_url"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    googleOauthChannel =
      MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "pillar.google_oauth",
      )
    googleOauthChannel?.setMethodCallHandler { call, result ->
      val key = prefsKey()
      val p = prefs()
      when (call.method) {
        "consumePendingOAuthUrl" -> {
          val url = p.getString(key, null)
          p.edit().remove(key).apply()
          result.success(url)
        }
        "clearPendingOAuthUrl" -> {
          p.edit().remove(key).apply()
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
    deliverPendingRedirectIfAny()
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    captureGoogleRedirect(intent)
  }

  override fun onResume() {
    super.onResume()
    captureGoogleRedirect(intent)
  }

  private fun captureGoogleRedirect(intent: Intent?) {
    val url = intent?.dataString ?: return
    val u = url.lowercase()
    val isLegacy = u.startsWith("pillarstudycoach://oauth")
    val isGoogleNative =
      u.startsWith("com.example.pillarstudycoach:/oauth2redirect") ||
        u.startsWith("com.example.pillar_study_coach:/oauth2redirect")
    if (!isLegacy && !isGoogleNative) {
      return
    }
    pendingGoogleRedirectUrl = url
    prefs().edit().putString(prefsKey(), url).apply()
    deliverPendingRedirectIfAny()
  }

  private fun deliverPendingRedirectIfAny() {
    val fromMemory = pendingGoogleRedirectUrl
    val fromPrefs = prefs().getString(prefsKey(), null)
    val url = fromMemory ?: fromPrefs ?: return
    val channel = googleOauthChannel ?: return
    pendingGoogleRedirectUrl = null
    channel.invokeMethod(
      "onGoogleAuthRedirect",
      mapOf("url" to url),
    )
  }
}
