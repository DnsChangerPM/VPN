package pm.dnschanger.nimbus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import hev.htproxy.TProxyService
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class NimbusVpnService : VpnService() {
    private val io = Executors.newCachedThreadPool()
    private val running = AtomicBoolean(false)
    private var tun: ParcelFileDescriptor? = null
    private var core: Process? = null
    private var download: Long = 0
    private var upload: Long = 0
    private var endpoint: String = ""
    private var protocol: String = ""

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopTunnel()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                val extras = intent?.extras
                io.execute { startTunnel(extras) }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopTunnel()
        io.shutdownNow()
        super.onDestroy()
    }

    private fun startTunnel(extras: android.os.Bundle?) {
        if (!running.compareAndSet(false, true)) return
        emit("status", "preparing", "Starting Aether")
        startForegroundCompat()
        try {
            val args = extras?.getStringArrayList(EXTRA_ARGS) ?: arrayListOf("--masque", "-4")
            protocol = extras?.getString(EXTRA_PROTOCOL) ?: "masque"
            val mode = extras?.getString(EXTRA_MODE) ?: "vpn"
            val dns = extras?.getBoolean(EXTRA_DNS, true) ?: true
            val splitMode = extras?.getString(EXTRA_SPLIT_MODE) ?: "off"
            val splitApps = extras?.getStringArrayList(EXTRA_SPLIT_APPS) ?: arrayListOf()

            val bin = File(applicationInfo.nativeLibraryDir, "libaether.so")
            if (!bin.exists()) throw IllegalStateException("libaether.so missing")

            killStale()
            core = ProcessBuilder(listOf(bin.absolutePath) + args)
                .directory(filesDir)
                .redirectErrorStream(true)
                .start()
            io.execute { pumpLogs(core!!) }

            if (!waitSocks()) throw IllegalStateException("SOCKS5 did not come up")
            emit("status", "connecting", "SOCKS5 ready")

            if (mode == "vpn") {
                val builder = Builder()
                    .setSession("Nimbus")
                    .setMtu(8500)
                    .addAddress("198.18.0.1", 32)
                    .addRoute("0.0.0.0", 0)
                    .setBlocking(true)
                if (dns) builder.addDnsServer("1.1.1.1")
                try {
                    builder.addDisallowedApplication(packageName)
                } catch (_: Exception) {
                }
                when (splitMode) {
                    "include" -> splitApps.forEach {
                        try {
                            builder.addAllowedApplication(it)
                        } catch (_: Exception) {
                        }
                    }
                    "exclude" -> splitApps.forEach {
                        try {
                            builder.addDisallowedApplication(it)
                        } catch (_: Exception) {
                        }
                    }
                }
                tun = builder.establish() ?: throw IllegalStateException("VPN establish failed")
                writeHevConfig()
                val started = TProxyService.TProxyStartService(
                    File(filesDir, "hev.yml").absolutePath,
                    tun!!.fd,
                )
                if (!started) throw IllegalStateException("HEV tunnel failed to start")
            }
            emit("status", "connected", if (mode == "vpn") "Device VPN active" else "SOCKS5 127.0.0.1:1819")
            monitor()
        } catch (e: Exception) {
            Log.e(TAG, "start failed", e)
            emit("status", "error", e.message ?: "start failed")
            stopTunnel()
        }
    }

    private fun monitor() {
        io.execute {
            while (running.get()) {
                try {
                    val stats = TProxyService.TProxyGetStats()
                    if (stats != null && stats.size >= 4) {
                        upload = stats[1]
                        download = stats[3]
                    }
                } catch (_: Throwable) {
                }
                val alive = try {
                    core?.exitValue()
                    false
                } catch (_: IllegalThreadStateException) {
                    true
                }
                if (!alive && running.get()) {
                    emit("status", "error", "Aether core exited")
                    stopTunnel()
                    return@execute
                }
                emit("status", if (running.get()) "connected" else "disconnected", null)
                Thread.sleep(2000)
            }
        }
    }

    private fun stopTunnel() {
        running.set(false)
        try {
            TProxyService.TProxyStopService()
        } catch (_: Throwable) {
        }
        try {
            tun?.close()
        } catch (_: Exception) {
        }
        tun = null
        try {
            core?.destroy()
        } catch (_: Exception) {
        }
        core = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        emit("status", "disconnected", "")
        stopSelf()
    }

    private fun waitSocks(): Boolean {
        repeat(80) {
            try {
                Socket().use { s ->
                    s.connect(InetSocketAddress("127.0.0.1", 1819), 400)
                    return true
                }
            } catch (_: Exception) {
                Thread.sleep(500)
            }
        }
        return false
    }

    private fun pumpLogs(proc: Process) {
        BufferedReader(InputStreamReader(proc.inputStream)).use { reader ->
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                val text = line ?: continue
                emit("log", null, text)
                Regex("""(\d{1,3}(?:\.\d{1,3}){3})(?::\d+)?""").find(text)?.let {
                    if (!it.value.startsWith("127.")) endpoint = it.groupValues[1]
                }
            }
        }
    }

    private fun writeHevConfig() {
        File(filesDir, "hev.yml").writeText(
            """
            tunnel:
              mtu: 8500
              ipv4: 198.18.0.1
            socks5:
              port: 1819
              address: 127.0.0.1
              udp: 'udp'
            misc:
              log-level: warn
            """.trimIndent()
        )
    }

    private fun killStale() {
        try {
            core?.destroy()
        } catch (_: Exception) {
        }
    }

    private fun startForegroundCompat() {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Nimbus VPN", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, launch, PendingIntent.FLAG_IMMUTABLE
        )
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL)
            .setContentTitle("Nimbus VPN")
            .setContentText("Protected")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF, notification)
        }
    }

    private fun emit(type: String, phase: String?, message: String?) {
        val i = Intent(ACTION_EVENT).setPackage(packageName)
        i.putExtra("type", type)
        i.putExtra("phase", phase)
        i.putExtra("message", message)
        i.putExtra("endpoint", endpoint)
        i.putExtra("protocol", protocol)
        i.putExtra("download", download)
        i.putExtra("upload", upload)
        sendBroadcast(i)
        NimbusPlugin.emit(
            mapOf(
                "type" to type,
                "phase" to (phase ?: ""),
                "message" to (message ?: ""),
                "endpoint" to endpoint,
                "protocol" to protocol,
                "download" to download,
                "upload" to upload,
            )
        )
    }

    companion object {
        const val TAG = "NimbusVpn"
        const val CHANNEL = "nimbus_vpn"
        const val NOTIF = 1819
        const val ACTION_START = "pm.dnschanger.nimbus.START"
        const val ACTION_STOP = "pm.dnschanger.nimbus.STOP"
        const val ACTION_EVENT = "pm.dnschanger.nimbus.EVENT"
        const val EXTRA_ARGS = "args"
        const val EXTRA_PROTOCOL = "protocol"
        const val EXTRA_MODE = "mode"
        const val EXTRA_DNS = "dns"
        const val EXTRA_SPLIT_MODE = "splitMode"
        const val EXTRA_SPLIT_APPS = "splitApps"
    }
}
