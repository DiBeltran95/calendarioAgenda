package com.agendaservi.agendaservi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widgets de la pantalla de inicio. Los datos los guarda la app al sincronizar
 * (lib/features/widgets_inicio/publicador.dart); aquí solo se pintan.
 */
private fun abrir(context: Context, ruta: String, codigo: Int): PendingIntent {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("agendaservi://app/$ruta")).setPackage(context.packageName)
    return PendingIntent.getActivity(context, codigo, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
}

private fun RemoteViews.pintarProximo(context: Context, datos: SharedPreferences) {
    val titulo = datos.getString("proximo_titulo", "").orEmpty()
    val cuando = datos.getString("proximo_cuando", "").orEmpty()
    setTextViewText(R.id.proximo_titulo, titulo.ifEmpty { context.getString(R.string.widget_sin_compromisos) })
    setTextViewText(R.id.proximo_cuando, cuando.ifEmpty { context.getString(R.string.widget_toca_para_abrir) })
}

/** Pequeño: el próximo compromiso. */
class WidgetProximo : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val vista = RemoteViews(context.packageName, R.layout.widget_proximo)
            vista.pintarProximo(context, widgetData)
            vista.setOnClickPendingIntent(R.id.widget_raiz, abrir(context, "hoy", 7401))
            appWidgetManager.updateAppWidget(id, vista)
        }
    }
}

/** Mediano: el día de un vistazo y el botón para registrar algo rápido. */
class WidgetHoy : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val vista = RemoteViews(context.packageName, R.layout.widget_hoy)
            vista.pintarProximo(context, widgetData)

            val citas = widgetData.getInt("citas_hoy", 0)
            val gasto = widgetData.getString("gasto_mes", "").orEmpty()
            val pagos = widgetData.getInt("por_clasificar", 0)
            val datos = listOfNotNull(
                if (citas > 0) context.resources.getQuantityString(R.plurals.widget_citas, citas, citas) else null,
                if (gasto.isNotEmpty()) context.getString(R.string.widget_gasto_mes, gasto) else null,
                if (pagos > 0) context.resources.getQuantityString(R.plurals.widget_pagos, pagos, pagos) else null,
            ).joinToString(" · ")
            vista.setTextViewText(R.id.resumen_dia, datos)
            vista.setViewVisibility(R.id.resumen_dia, if (datos.isEmpty()) View.GONE else View.VISIBLE)

            vista.setOnClickPendingIntent(R.id.widget_raiz, abrir(context, "hoy", 7402))
            vista.setOnClickPendingIntent(R.id.boton_capturar, abrir(context, "capturar", 7403))
            appWidgetManager.updateAppWidget(id, vista)
        }
    }
}
