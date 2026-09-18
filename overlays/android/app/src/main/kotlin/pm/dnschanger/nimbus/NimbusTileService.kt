package pm.dnschanger.nimbus

import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

@RequiresApi(24)
class NimbusTileService : TileService() {
    override fun onStartListening() {
        qsTile?.state =
            if (NimbusVpnService.running.get()) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        qsTile?.label = "Nimbus"
        qsTile?.updateTile()
    }

    override fun onClick() {
        val up = NimbusVpnService.running.get()
        val intent = Intent(this, NimbusVpnService::class.java)
            .setAction(if (up) NimbusVpnService.ACTION_STOP else NimbusVpnService.ACTION_START)
        if (!up && Build.VERSION.SDK_INT >= 26) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        qsTile?.state = if (up) Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        qsTile?.updateTile()
    }
}
