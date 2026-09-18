package pm.dnschanger.nimbus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.Bundle
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
    private var tun: ParcelFileDescriptor? = null
    private var core: Process? = null
    private var download: Long = 0
    private var upload: Long = 0
    private var endpoint: String = ""
    private var protocol: String = ""
    private var socksPort: Int = 1819
    private var tunMtu: Int = 1400
    private val lanProxy = LanProxyServer()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopTunnel()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                val extras = intent?.extras ?: lastExtras ?: extrasFromPrefs()
                if (intent?.extras != null) lastExtras = Bundle(intent.extras!!)
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
            socksPort = extras?.getInt(EXTRA_SOCKS_PORT, 1819) ?: 1819
            tunMtu = extras?.getInt(EXTRA_MTU, 1400) ?: 1400
            val kill = extras?.getBoolean(EXTRA_KILL, true) ?: true
            val bypassLan = extras?.getBoolean(EXTRA_BYPASS_LAN, true) ?: true
            val ipv6 = extras?.getBoolean(EXTRA_IPV6, false) ?: false
            val lanShare = extras?.getBoolean(EXTRA_LAN_SHARE, false) ?: false

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

            persistLast(extras)
            if (lanShare) {
                val lanPort = if (socksPort in 1..65534) socksPort + 1 else 1820
                if (lanProxy.start(lanPort, "127.0.0.1", socksPort)) {
                    emit(
                        "lan",
                        "connected",
                        "${lanProxy.address}:${lanProxy.port}|${lanProxy.username}|${lanProxy.password}",
                    )
                }
            }
            if (mode == "vpn") {
                val builder = Builder()
                    .setSession("Nimbus")
                    .setMtu(tunMtu)
                    .addAddress("198.18.0.1", 32)
                    .setBlocking(kill)
                if (ipv6) {
                    builder.addAddress("fc00::1", 128)
                    builder.addRoute("::", 0)
                }
                if (bypassLan) {
                    for (cidr in LAN_BYPASS) {
                        val parts = cidr.split("/")
                        builder.addRoute(parts[0], parts[1].toInt())
                    }
                } else {
                    builder.addRoute("0.0.0.0", 0)
                }
                if (dns) {
                    builder.addDnsServer("1.1.1.1")
                    builder.addDnsServer("1.0.0.1")
                }
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
            emit(
                "status",
                "connected",
                if (mode == "vpn") "Device VPN active" else "SOCKS5 127.0.0.1:$socksPort",
            )
            publishChrome()
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
            lanProxy.stop()
        } catch (_: Throwable) {
        }
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
        publishChrome()
        stopSelf()
    }

    private fun waitSocks(): Boolean {
        repeat(80) {
            try {
                Socket().use { s ->
                    s.connect(InetSocketAddress("127.0.0.1", socksPort), 400)
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
              mtu: $tunMtu
              ipv4: 198.18.0.1
            socks5:
              port: $socksPort
              address: 127.0.0.1
              udp: 'udp'
            misc:
              log-level: warn
            """.trimIndent()
        )
    }

    private fun persistLast(extras: android.os.Bundle?) {
        extras ?: return
        lastExtras = Bundle(extras)
        val args = extras.getStringArrayList(EXTRA_ARGS) ?: arrayListOf()
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
            .putString(EXTRA_PROTOCOL, extras.getString(EXTRA_PROTOCOL, "masque"))
            .putString(EXTRA_MODE, extras.getString(EXTRA_MODE, "vpn"))
            .putBoolean(EXTRA_DNS, extras.getBoolean(EXTRA_DNS, true))
            .putString(EXTRA_SPLIT_MODE, extras.getString(EXTRA_SPLIT_MODE, "off"))
            .putString(EXTRA_SPLIT_APPS, extras.getStringArrayList(EXTRA_SPLIT_APPS)?.joinToString(","))
            .putInt(EXTRA_SOCKS_PORT, extras.getInt(EXTRA_SOCKS_PORT, 1819))
            .putInt(EXTRA_MTU, extras.getInt(EXTRA_MTU, 1400))
            .putBoolean(EXTRA_KILL, extras.getBoolean(EXTRA_KILL, true))
            .putBoolean(EXTRA_BYPASS_LAN, extras.getBoolean(EXTRA_BYPASS_LAN, true))
            .putBoolean(EXTRA_IPV6, extras.getBoolean(EXTRA_IPV6, false))
            .putBoolean(EXTRA_LAN_SHARE, extras.getBoolean(EXTRA_LAN_SHARE, false))
            .putBoolean("autoConnect", extras.getBoolean("autoConnect", false))
            .putString(EXTRA_ARGS, args.joinToString("\u0001"))
            .apply()
    }

    private fun extrasFromPrefs(): android.os.Bundle {
        val p = getSharedPreferences(PREFS, MODE_PRIVATE)
        val b = android.os.Bundle()
        b.putString(EXTRA_PROTOCOL, p.getString(EXTRA_PROTOCOL, "masque"))
        b.putString(EXTRA_MODE, p.getString(EXTRA_MODE, "vpn"))
        b.putBoolean(EXTRA_DNS, p.getBoolean(EXTRA_DNS, true))
        b.putString(EXTRA_SPLIT_MODE, p.getString(EXTRA_SPLIT_MODE, "off"))
        val apps = p.getString(EXTRA_SPLIT_APPS, "") ?: ""
        b.putStringArrayList(
            EXTRA_SPLIT_APPS,
            ArrayList(apps.split(",").filter { it.isNotEmpty() }),
        )
        b.putInt(EXTRA_SOCKS_PORT, p.getInt(EXTRA_SOCKS_PORT, 1819))
        b.putInt(EXTRA_MTU, p.getInt(EXTRA_MTU, 1400))
        b.putBoolean(EXTRA_KILL, p.getBoolean(EXTRA_KILL, true))
        b.putBoolean(EXTRA_BYPASS_LAN, p.getBoolean(EXTRA_BYPASS_LAN, true))
        b.putBoolean(EXTRA_IPV6, p.getBoolean(EXTRA_IPV6, false))
        b.putBoolean(EXTRA_LAN_SHARE, p.getBoolean(EXTRA_LAN_SHARE, false))
        val args = (p.getString(EXTRA_ARGS, "") ?: "").split("\u0001").filter { it.isNotEmpty() }
        b.putStringArrayList(EXTRA_ARGS, ArrayList(if (args.isEmpty()) listOf("--masque", "-4") else args))
        return b
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
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, NimbusVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL)
            .setContentTitle("Nimbus VPN")
            .setContentText("Protected")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pi)
            .addAction(0, "Disconnect", stop)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF, notification)
        }
    }

    private fun publishChrome() {
        try {
            val mgr = AppWidgetManager.getInstance(this)
            val ids = mgr.getAppWidgetIds(ComponentName(this, NimbusWidgetProvider::class.java))
            val upd = Intent(this, NimbusWidgetProvider::class.java)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            upd.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            sendBroadcast(upd)
        } catch (_: Exception) {
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
        const val EXTRA_SOCKS_PORT = "socksPort"
        const val EXTRA_MTU = "tunMtu"
        const val EXTRA_KILL = "killSwitch"
        const val EXTRA_BYPASS_LAN = "bypassLan"
        const val EXTRA_IPV6 = "ipv6Tunnel"
        const val PREFS = "nimbus_vpn"
        val running = AtomicBoolean(false)
        @Volatile var lastExtras: Bundle? = null

        // 0.0.0.0/0 minus RFC1918 so LAN stays local (Aethon bypass-local).
        val LAN_BYPASS = arrayOf(
            "0.0.0.0/5", "8.0.0.0/7", "11.0.0.0/8", "12.0.0.0/6", "16.0.0.0/4",
            "32.0.0.0/3", "64.0.0.0/3", "96.0.0.0/4", "112.0.0.0/5", "120.0.0.0/6",
            "124.0.0.0/7", "126.0.0.0/8", "128.0.0.0/3", "160.0.0.0/5", "168.0.0.0/6",
            "172.0.0.0/12", "172.32.0.0/11", "172.64.0.0/10", "173.0.0.0/8",
            "174.0.0.0/7", "176.0.0.0/4", "192.0.0.0/9", "192.128.0.0/11",
            "192.160.0.0/13", "192.169.0.0/16", "192.170.0.0/15", "192.172.0.0/14",
            "192.176.0.0/12", "192.192.0.0/10", "193.0.0.0/8", "194.0.0.0/7",
            "196.0.0.0/6", "200.0.0.0/5", "208.0.0.0/4",
        )
    }
}
