package com.reload.prestreloajuda.data

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.reload.prestreloajuda.MainActivity

/**
 * Agendamento de notificações do sistema de Cooldown/Alarme (#33) — equivalente Android do
 * NotificationScheduler.swift do Mac. Diferença de plataforma: no Android o dono do agendamento é
 * o `AlarmManager` (dispara MESMO com o app fechado). Usamos `setAndAllowWhileIdle` (INEXATO, sem
 * permissão especial — um atraso de minutos é irrelevante em cooldowns de horas). Quando o alarme
 * dispara, o [CooldownAlarmReceiver] posta a notificação de verdade.
 *
 * Reusar o mesmo `id` sobrescreve o agendamento (idempotente). Se o `fireAtMs` já passou, não agenda.
 * Guardamos o conjunto de ids agendados em SharedPreferences pra conseguir cancelar por PREFIXO.
 */
object CooldownNotifications {
    private const val CHANNEL_ID = "cooldowns"
    private const val ACTION = "com.reload.prestreloajuda.COOLDOWN_ALARM"
    private const val ALARMS_PREFS = "cooldowns.alarms"
    private const val ALARMS_KEY = "ids"

    const val EXTRA_TITLE = "cd.title"
    const val EXTRA_BODY = "cd.body"
    const val EXTRA_ID = "cd.id"

    /** Cria o canal "cooldowns" uma vez (idempotente). */
    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID, "Cooldowns", NotificationManager.IMPORTANCE_HIGH
                ).apply { description = "Cooldowns & alarms" }
                mgr.createNotificationChannel(ch)
            }
        }
    }

    /** Agenda (ou reagenda) o alarme `id` pra `fireAtMs`. Ignora se já passou. */
    fun schedule(ctx: Context, id: String, fireAtMs: Long, title: String, body: String) {
        if (fireAtMs - System.currentTimeMillis() <= 0) return
        ensureChannel(ctx)
        val pi = buildPendingIntent(ctx, id, title, body, create = true) ?: return
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAtMs, pi)
        } catch (_: Exception) {
        }
        remember(ctx, setOf(id))
    }

    /** Cancela um alarme pelo `id`. */
    fun cancel(ctx: Context, id: String) {
        cancelOne(ctx, id)
        forget(ctx, setOf(id))
    }

    /** Cancela todos os alarmes cujo id comece com `prefix` (ex.: todos de um boneco/berry). */
    fun cancelPrefix(ctx: Context, prefix: String) {
        val ids = scheduledIds(ctx).filter { it.startsWith(prefix) }.toSet()
        for (id in ids) cancelOne(ctx, id)
        forget(ctx, ids)
    }

    /** Posta a notificação AGORA (chamado pelo receiver quando o alarme dispara). */
    fun post(ctx: Context, id: String, title: String, body: String) {
        ensureChannel(ctx)
        val open = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tapPi = PendingIntent.getActivity(
            ctx, id.hashCode(), open,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notif = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(tapPi)
            .build()
        try {
            NotificationManagerCompat.from(ctx).notify(id.hashCode(), notif)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS não concedida — o contador in-app continua funcionando.
        }
        forget(ctx, setOf(id))   // já disparou: não é mais um alarme pendente
    }

    // --- PendingIntent / AlarmManager helpers ---

    private fun buildPendingIntent(
        ctx: Context, id: String, title: String, body: String, create: Boolean
    ): PendingIntent? {
        val intent = Intent(ctx, CooldownAlarmReceiver::class.java).apply {
            action = ACTION
            // `data` único por id: garante que dois ids diferentes gerem PendingIntents distintos
            // (extras NÃO entram no filterEquals) e que o cancel encontre o alvo certo.
            data = Uri.parse("cooldown://$id")
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_ID, id)
        }
        var flags = PendingIntent.FLAG_IMMUTABLE
        flags = flags or if (create) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE
        return PendingIntent.getBroadcast(ctx, id.hashCode(), intent, flags)
    }

    private fun cancelOne(ctx: Context, id: String) {
        val pi = buildPendingIntent(ctx, id, "", "", create = false) ?: return
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pi)
        pi.cancel()
    }

    // --- Conjunto de ids agendados (SharedPreferences) p/ cancelar por prefixo ---

    private fun alarmsPrefs(ctx: Context) =
        ctx.getSharedPreferences(ALARMS_PREFS, Context.MODE_PRIVATE)

    private fun scheduledIds(ctx: Context): Set<String> =
        alarmsPrefs(ctx).getStringSet(ALARMS_KEY, emptySet()) ?: emptySet()

    private fun remember(ctx: Context, ids: Set<String>) {
        val next = scheduledIds(ctx).toMutableSet().apply { addAll(ids) }
        alarmsPrefs(ctx).edit().putStringSet(ALARMS_KEY, next).apply()
    }

    private fun forget(ctx: Context, ids: Set<String>) {
        if (ids.isEmpty()) return
        val next = scheduledIds(ctx).toMutableSet().apply { removeAll(ids) }
        alarmsPrefs(ctx).edit().putStringSet(ALARMS_KEY, next).apply()
    }
}

/**
 * Recebe o alarme do [CooldownNotifications] e posta a notificação. Registrado no
 * AndroidManifest.xml com `exported=false` (só o próprio app dispara).
 */
class CooldownAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra(CooldownNotifications.EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(CooldownNotifications.EXTRA_BODY) ?: ""
        val id = intent.getStringExtra(CooldownNotifications.EXTRA_ID) ?: title
        CooldownNotifications.post(context, id, title, body)
    }
}
