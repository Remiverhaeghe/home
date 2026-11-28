package fr.remiverhaeghe.home

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File
import java.util.Locale

/**
 * Widget d'écran d'accueil : la température et l'humidité de quelques pièces.
 *
 * Il ne lit que `widget.json`, écrit par le relevé en arrière-plan dans le dossier des documents
 * de l'appli. Aucun réseau, aucune autre donnée.
 */
class HomeWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val lines = readLines(context)
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
            PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.home_widget)
            val slots = intArrayOf(R.id.widget_line1, R.id.widget_line2, R.id.widget_line3, R.id.widget_line4)
            for ((index, slot) in slots.withIndex()) {
                views.setTextViewText(slot, lines.getOrElse(index) { "" })
            }
            if (open != null) {
                views.setOnClickPendingIntent(R.id.widget_root, open)
            }
            manager.updateAppWidget(id, views)
        }
    }

    private fun readLines(context: Context): List<String> {
        val file = File(context.dataDir, "app_flutter/widget.json")
        if (!file.exists()) {
            return listOf("Active le suivi des capteurs dans Home")
        }
        return try {
            val rooms = JSONObject(file.readText()).getJSONArray("pieces")
            (0 until rooms.length()).map {
                val room = rooms.getJSONObject(it)
                String.format(
                    Locale.FRANCE,
                    "%s  %.1f °C  %d %%",
                    room.getString("nom"),
                    room.getDouble("temp"),
                    Math.round(room.getDouble("hum")),
                )
            }
        } catch (e: Exception) {
            listOf("Relevés illisibles")
        }
    }
}
