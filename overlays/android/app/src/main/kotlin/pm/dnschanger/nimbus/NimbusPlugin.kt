package pm.dnschanger.nimbus

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CopyOnWriteArrayList

object NimbusPlugin {
    private const val METHODS = "nimbus.vpn/engine"
    private const val EVENTS = "nimbus.vpn/events"
    private val sinks = CopyOnWriteArrayList<EventChannel.EventSink>()
    private var activity: Activity? = null
    private var vpnResult: MethodChannel.Result? = null

    fun attach(activity: Activity, engine: FlutterEngine) {
        this.activity = activity
        MethodChannel(engine.dartExecutor.binaryMessenger, METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareVpn" -> prepare(activity, result)
                "start" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    val intent = Intent(activity, NimbusVpnService::class.java)
                        .setAction(NimbusVpnService.ACTION_START)
                    intent.putStringArrayListExtra(
                        NimbusVpnService.EXTRA_ARGS,
                        ArrayList((args["args"] as? List<*>)?.map { "$it" } ?: emptyList())
                    )
                    intent.putExtra(NimbusVpnService.EXTRA_PROTOCOL, "${args["protocol"] ?: "masque"}")
                    intent.putExtra(NimbusVpnService.EXTRA_MODE, "${args["mode"] ?: "vpn"}")
                    intent.putExtra(NimbusVpnService.EXTRA_DNS, args["privateDns"] != false)
                    intent.putExtra(NimbusVpnService.EXTRA_SPLIT_MODE, "${args["splitMode"] ?: "off"}")
                    intent.putStringArrayListExtra(
                        NimbusVpnService.EXTRA_SPLIT_APPS,
                        ArrayList((args["splitApps"] as? List<*>)?.map { "$it" } ?: emptyList())
                    )
                    if (Build.VERSION.SDK_INT >= 26) {
                        activity.startForegroundService(intent)
                    } else {
                        activity.startService(intent)
                    }
                    result.success(null)
                }
                "stop" -> {
                    activity.startService(
                        Intent(activity, NimbusVpnService::class.java)
                            .setAction(NimbusVpnService.ACTION_STOP)
                    )
                    result.success(null)
                }
                "status" -> result.success(mapOf("phase" to "unknown"))
                "listApps" -> result.success(listApps(activity))
                "recover" -> result.success(null)
                else -> result.notImplemented()
            }
        }
        EventChannel(engine.dartExecutor.binaryMessenger, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sinks.add(events)
                }

                override fun onCancel(arguments: Any?) {
                    sinks.clear()
                }
            }
        )
    }

    fun onActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode != 24) return
        vpnResult?.success(resultCode == Activity.RESULT_OK)
        vpnResult = null
    }

    fun emit(payload: Map<String, Any?>) {
        val act = activity ?: return
        act.runOnUiThread {
            sinks.forEach { it.success(payload) }
        }
    }

    private fun prepare(activity: Activity, result: MethodChannel.Result) {
        val intent = VpnService.prepare(activity)
        if (intent == null) {
            result.success(true)
            return
        }
        vpnResult = result
        activity.startActivityForResult(intent, 24)
    }

    private fun listApps(activity: Activity): List<Map<String, String>> {
        val pm = activity.packageManager
        return pm.getInstalledApplications(0)
            .filter { it.flags and ApplicationInfo.FLAG_SYSTEM == 0 }
            .map {
                mapOf(
                    "package" to it.packageName,
                    "label" to (it.loadLabel(pm)?.toString() ?: it.packageName),
                )
            }
            .sortedBy { it["label"] }
    }
}
