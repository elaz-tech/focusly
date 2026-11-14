package com.eafmicroservice.focusly

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Intent.ACTION_BOOT_COMPLETED == intent.action) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            // SharedPreferences keys from Flutter have "flutter." prefix
            val endTime = prefs.getLong("flutter.lock_end_time", 0)
            val endElapsed = prefs.getLong("flutter.lock_end_elapsed", 0)
            // Locked if EITHER clock says locked (elapsed resets on reboot to a
            // small value, so a pre-reboot deadline stays in the future: safe).
            val locked = endTime > System.currentTimeMillis() ||
                (endElapsed > 0 && endElapsed > SystemClock.elapsedRealtime())

            if (locked) {
                val i = Intent(context, MainActivity::class.java)
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(i)
            }
        }
    }
}
