package com.agendaservi.agendaservi

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Pagos leídos de las notificaciones (ver PagosListener y
        // lib/features/finance/pagos/lector_pagos.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "agendaservi/pagos").setMethodCallHandler { call, result ->
            when (call.method) {
                "acceso" -> result.success(PagosListener.accesoConcedido(this))
                "abrirAjustes" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                "leer" -> result.success(PagosListener.leer(this))
                "quitar" -> {
                    PagosListener.quitar(this, call.argument<List<String>>("ids") ?: emptyList())
                    result.success(null)
                }
                "avisar" -> {
                    PagosListener.setAvisar(this, call.argument<Boolean>("valor") ?: true)
                    result.success(null)
                }
                "apps" -> result.success(PagosListener.APPS.values.toList())
                else -> result.notImplemented()
            }
        }
    }
}
