package com.BharatFlow

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.os.Build
import android.provider.Settings

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.bharatflow.app/adblock_dns"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPrivateDnsInfo" -> {
                    val dnsInfo = getPrivateDnsInfo()
                    result.success(dnsInfo)
                }
                "openPrivateDnsSettings" -> {
                    openPrivateDnsSettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getPrivateDnsInfo(): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>()
        var isPrivateDnsActive = false
        var privateDnsServerName: String? = null
        var privateDnsMode: String? = null
        var privateDnsSpecifier: String? = null

        try {
            val contentResolver = context.contentResolver
            
            // Check private DNS mode and specifier from Settings.Global
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                privateDnsMode = Settings.Global.getString(contentResolver, "private_dns_mode")
                privateDnsSpecifier = Settings.Global.getString(contentResolver, "private_dns_specifier")
            }

            // Check using ConnectivityManager and LinkProperties for active network (Android 9+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val activeNetwork = connectivityManager.activeNetwork
                if (activeNetwork != null) {
                    val linkProperties = connectivityManager.getLinkProperties(activeNetwork)
                    if (linkProperties != null) {
                        isPrivateDnsActive = linkProperties.isPrivateDnsActive
                        privateDnsServerName = linkProperties.privateDnsServerName
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        result["isPrivateDnsActive"] = isPrivateDnsActive
        result["privateDnsServerName"] = privateDnsServerName
        result["privateDnsMode"] = privateDnsMode
        result["privateDnsSpecifier"] = privateDnsSpecifier
        
        return result
    }

    private fun openPrivateDnsSettings() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                Intent("android.settings.PRIVATE_DNS_SETTINGS")
            } else {
                Intent(Settings.ACTION_WIRELESS_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            try {
                // Fallback to general settings
                val intent = Intent(Settings.ACTION_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            } catch (ex: Exception) {
                ex.printStackTrace()
            }
        }
    }
}
