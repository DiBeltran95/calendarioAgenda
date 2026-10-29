package com.agendaservi.agendaservi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Lee (solo con permiso explícito del usuario en Ajustes → Acceso a
 * notificaciones) los avisos de compra de Google Wallet, de las apps de los
 * bancos y los SMS de los bancos. Guarda el texto en una cola local; la app
 * lo interpreta y lo sube a "Pagos por clasificar" la próxima vez que se abre.
 * Nada sale del teléfono desde aquí y se ignoran las demás notificaciones.
 */
class PagosListener : NotificationListenerService() {

    companion object {
        private const val PREFS = "agendaservi_pagos"
        private const val COLA = "cola"
        private const val AVISAR = "avisar"
        private const val MAX = 200
        private const val CANAL = "pagos"

        /** Apps cuyos avisos de compra se leen (paquete → nombre visible). */
        val APPS = mapOf(
            "com.google.android.apps.walletnfcrel" to "Google Wallet",
            "com.todo1.mobile" to "Bancolombia",
            "com.nequi.MobileApp" to "Nequi",
            "com.davivienda.daviviendaapp" to "Davivienda",
            "com.davivienda.daviplataapp" to "DaviPlata",
            "co.com.bbva.mb" to "BBVA",
            "com.bancodebogota.bancamovil" to "Banco de Bogotá",
            "com.nu.production" to "Nu",
        )

        /** Mensajería: los bancos avisan cada compra por SMS. */
        val MENSAJERIA = setOf(
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
            "com.android.mms",
            "com.android.messaging",
        )

        private val MONTO = Regex("""(\$|COP|USD)\s?\d[\d.,]*""", RegexOption.IGNORE_CASE)
        private val PISTA = Regex(
            "compra|pago|pagaste|pagó|transacci|retiro|d[eé]bito|cargo|recibiste|te envi|transferencia|consignaci|abono",
            RegexOption.IGNORE_CASE,
        )

        private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        fun leer(ctx: Context): String = prefs(ctx).getString(COLA, "[]") ?: "[]"

        @Synchronized
        fun quitar(ctx: Context, claves: List<String>) {
            val cola = JSONArray(leer(ctx))
            val queda = JSONArray()
            for (i in 0 until cola.length()) {
                val o = cola.getJSONObject(i)
                if (o.optString("id") !in claves) queda.put(o)
            }
            prefs(ctx).edit().putString(COLA, queda.toString()).apply()
        }

        fun setAvisar(ctx: Context, v: Boolean) = prefs(ctx).edit().putBoolean(AVISAR, v).apply()

        fun accesoConcedido(ctx: Context): Boolean {
            val activos = Settings.Secure.getString(ctx.contentResolver, "enabled_notification_listeners") ?: return false
            return activos.split(':').any { it.startsWith(ctx.packageName + "/") }
        }

        @Synchronized
        private fun encolar(ctx: Context, item: JSONObject): Boolean {
            val cola = JSONArray(leer(ctx))
            // La misma notificación se vuelve a publicar al actualizarse: no se repite.
            for (i in 0 until cola.length()) {
                val o = cola.getJSONObject(i)
                if (o.optString("texto") == item.optString("texto") && o.optString("titulo") == item.optString("titulo")) return false
            }
            cola.put(item)
            val recortada = JSONArray()
            for (i in maxOf(0, cola.length() - MAX) until cola.length()) recortada.put(cola.get(i))
            prefs(ctx).edit().putString(COLA, recortada.toString()).apply()
            return true
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            procesar(sbn)
        } catch (_: Exception) {
            // Nunca interrumpir el servicio por una notificación rara.
        }
    }

    private fun procesar(sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: return
        if (pkg == packageName) return
        val app = APPS[pkg] ?: if (pkg in MENSAJERIA) "SMS" else return
        val n = sbn.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val extras = n.extras ?: return
        val titulo = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val texto = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        val todo = "$titulo $texto"
        val monto = MONTO.find(todo) ?: return
        // Google Wallet no siempre dice "compra"; los demás sí deben parecer un pago.
        if (pkg != "com.google.android.apps.walletnfcrel" && !PISTA.containsMatchIn(todo)) return

        val item = JSONObject()
            .put("id", "${sbn.key}|${sbn.postTime}")
            .put("paquete", pkg)
            .put("app", app)
            .put("titulo", titulo.take(200))
            .put("texto", texto.take(500))
            .put("fecha", sbn.postTime)
        if (encolar(this, item) && prefs(this).getBoolean(AVISAR, true)) avisar(monto.value)
    }

    /** Recordatorio discreto: tocarlo abre "Pagos por clasificar". */
    private fun avisar(monto: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm.getNotificationChannel(CANAL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CANAL, "Pagos detectados", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Te recuerda clasificar los pagos que se leen de tus bancos"
                },
            )
        }
        val abrir = Intent(Intent.ACTION_VIEW, Uri.parse("agendaservi://app/finanzas/pagos")).setPackage(packageName)
        val pi = PendingIntent.getActivity(this, 7301, abrir, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CANAL) else Notification.Builder(this)
        val aviso = b.setSmallIcon(R.drawable.ic_stat_agenda)
            .setContentTitle("Pago detectado: $monto")
            .setContentText("Toca para asignarle categoría en Finanzas")
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setColor(0xFF25D366.toInt())
            .build()
        nm.notify(7301, aviso)
    }
}
